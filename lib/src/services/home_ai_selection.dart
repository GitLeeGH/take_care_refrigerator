import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'curation_preferences.dart';
import 'meal_assistant.dart';

class HomeAiSelection {
  const HomeAiSelection(
    this.owner,
    this.revision,
    this.result,
    this.createdAt, {
    this.mealPeriod,
  });
  final String? mealPeriod;
  final String owner, revision;
  final MealAssistantResult result;
  final DateTime createdAt;
  bool matches(
    String owner,
    String revision,
    DateTime now, {
    String? mealPeriod,
  }) =>
      this.mealPeriod == mealPeriod &&
      this.owner == owner &&
      this.revision == revision &&
      now.year == createdAt.year &&
      now.month == createdAt.month &&
      now.day == createdAt.day &&
      !now.isBefore(createdAt) &&
      now.difference(createdAt) < const Duration(hours: 6);
}

/// Device-local bounded result cache. No photo, raw pantry or grant is stored.
class HomeAiSelectionCache {
  String key(String owner) =>
      'home_ai_result_v1_${sha256.convert(utf8.encode(owner))}';
  Future<void> write(HomeAiSelection value, {String session = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key(value.owner),
      jsonEncode({
        'version': 1,
        'session': session,
        'revision': value.revision,
        'meal_period': value.mealPeriod,
        'at': value.createdAt.toIso8601String(),
        'result': {
          'menus': [
            for (final m in value.result.menus)
              {'id': m.id, 'reason': m.reason},
          ],
          'answer': value.result.answer,
          'steps': value.result.steps,
          'warnings': value.result.warnings,
        },
      }),
    );
  }

  Future<void> remove(String owner) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key(owner));
  }

  Future<HomeAiSelection?> read(
    String owner,
    MealAssistantDraft draft,
    DateTime now, {
    String session = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(key(owner));
    if (raw == null) return null;
    try {
      if (raw.length > 16000) throw const FormatException();
      final data = jsonDecode(raw) as Map;
      if (data['version'] != 1 ||
          data['revision'] != draft.revision ||
          data['session'] != session) {
        throw const FormatException();
      }
      final value = HomeAiSelection(
        owner,
        draft.revision,
        MealAssistantResult.parse(data['result'], draft),
        DateTime.parse(data['at'] as String),
        mealPeriod: data['meal_period'] as String?,
      );
      if (!value.matches(
        owner,
        draft.revision,
        now,
        mealPeriod: value.mealPeriod,
      )) {
        throw const FormatException();
      }
      return value;
    } catch (_) {
      await prefs.remove(key(owner));
      return null;
    }
  }
}

final homeAiSelectionProvider =
    NotifierProvider<HomeAiSelectionNotifier, HomeAiSelection?>(
      HomeAiSelectionNotifier.new,
    );

class HomeAiSelectionNotifier extends Notifier<HomeAiSelection?> {
  final _cache = HomeAiSelectionCache();
  StreamSubscription<void>? _subscription;
  String? _owner;
  int _epoch = 0;
  Future<void> _writes = Future.value();
  @override
  HomeAiSelection? build() {
    ref.onDispose(() => _subscription?.cancel());
    return null;
  }

  String get _session {
    final identity = ref.read(curationIdentityProvider);
    return identity is AuthCurationIdentity
        ? identity.client.auth.currentUser?.lastSignInAt ?? ''
        : '';
  }

  void _observe() {
    _subscription ??= ref
        .read(curationIdentityProvider)
        .changes
        .listen((_) => clear());
  }

  void clear() {
    _epoch++;
    final owner = _owner ?? state?.owner;
    _owner = null;
    state = null;
    if (owner != null) {
      _writes = _writes
          .then((_) => _cache.remove(owner))
          .catchError((Object _) {});
    }
  }

  Future<void> restore(String owner, MealAssistantDraft draft) async {
    _observe();
    final epoch = _epoch;
    final session = _session;
    _owner = owner;
    try {
      await _writes;
      final value = await _cache.read(
        owner,
        draft,
        DateTime.now(),
        session: session,
      );
      if (!ref.mounted ||
          epoch != _epoch ||
          ref.read(curationIdentityProvider).account != owner ||
          session != _session) {
        return;
      }
      state = value;
    } catch (_) {
      // Storage failure never authorizes a request or resets attempt limits.
    }
  }

  void save(MealAssistantConsent consent, MealAssistantResult result) {
    if (consent.draft.data['task'] != 'menus') return;
    if (ref.read(curationIdentityProvider).account != consent.owner) return;
    _observe();
    final epoch = _epoch;
    final session = _session;
    _owner = consent.owner;
    final value = HomeAiSelection(
      consent.owner,
      consent.draft.revision,
      result,
      DateTime.now(),
      mealPeriod: consent.mealPeriod,
    );
    state = value;
    _writes = _writes
        .then((_) async {
          // Normal widget disposal must not erase a completed approved result.
          // Revocation/account changes increment epoch and still invalidate it.
          if (epoch != _epoch) return;
          await _cache.write(value, session: session);
          if (epoch != _epoch) await _cache.remove(value.owner);
        })
        .catchError((Object _) {});
  }
}
