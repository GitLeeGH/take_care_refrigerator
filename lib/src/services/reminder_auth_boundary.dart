import 'local_expiry_reminders.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'reminder_ledger.dart';

/// Finish durable invalidation before explicit login/logout/deletion mutations.
/// Failure propagates: caller must not report a completed session transition.
Future<T> withReminderSessionBoundary<T>({
  required Future<void> Function() invalidate,
  required Future<T> Function() transition,
}) async {
  await invalidate();
  return transition();
}

Future<void> invalidateReminderSession({bool includeLocal = true}) async {
  if (includeLocal) await invalidateLocalExpiryReminders();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await const ReminderLedger().invalidate().timeout(
      const Duration(seconds: 5),
    );
  }
}

/// Reads the existing Supabase Flutter 2.10.3 default session key after reload.
/// No getSession/setSession/refresh or writes. NOT wired to a background worker:
/// native final dispatch + foreground invalidation still require integration.
class ExistingSupabaseCredentialReader implements BackgroundCredentialReader {
  ExistingSupabaseCredentialReader(this.readPersisted);
  final Future<String?> Function() readPersisted;
  factory ExistingSupabaseCredentialReader.forProject(Uri project) {
    if (project.scheme != 'https' ||
        project.host.isEmpty ||
        project.userInfo.isNotEmpty) {
      throw ArgumentError('Configured HTTPS project required');
    }
    final key = 'sb-${project.host.split('.').first}-auth-token';
    return ExistingSupabaseCredentialReader(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      return prefs.getString(key);
    });
  }
  @override
  Future<BackgroundCredential?> readFresh() async {
    try {
      final raw = await readPersisted();
      if (raw == null || raw.length > 32768) return null;
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;
      final token = data['access_token'],
          expiry = data['expires_at'],
          user = data['user'];
      if (token is! String ||
          token.isEmpty ||
          token.length > 16384 ||
          expiry is! int ||
          expiry <= 0 ||
          expiry > 4102444800 ||
          user is! Map<String, dynamic> ||
          user['id'] is! String ||
          (user['id'] as String).isEmpty ||
          (user['id'] as String).length > 256) {
        return null;
      }
      return BackgroundCredential(
        user['id'] as String,
        token,
        DateTime.fromMillisecondsSinceEpoch(expiry * 1000, isUtc: true),
      );
    } catch (_) {
      // Includes malformed JSON and unavailable storage. Never log raw input.
      return null;
    }
  }
}
