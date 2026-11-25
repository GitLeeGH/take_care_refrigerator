import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local display preferences only. Never schedules system notifications.
class InAppNotificationPreferences {
  InAppNotificationPreferences({
    required this.enabled,
    required this.daysBefore,
  }) {
    if (!const {1, 3, 7}.contains(daysBefore)) {
      throw ArgumentError.value(daysBefore, 'daysBefore');
    }
  }
  final bool enabled;
  final int daysBefore;
  String encode() =>
      jsonEncode({'version': 1, 'enabled': enabled, 'daysBefore': daysBefore});
  static InAppNotificationPreferences decode(String raw) {
    final value = jsonDecode(raw);
    if (value is! Map ||
        value['version'] != 1 ||
        value['enabled'] is! bool ||
        value['daysBefore'] is! int ||
        !const {1, 3, 7}.contains(value['daysBefore'])) {
      throw const FormatException('Invalid in-app notification preferences');
    }
    return InAppNotificationPreferences(
      enabled: value['enabled'],
      daysBefore: value['daysBefore'],
    );
  }
}

abstract interface class NotificationPreferencesStorage {
  String? read(String key);
  Future<bool> write(String key, String value);
}

class SharedNotificationPreferencesStorage
    implements NotificationPreferencesStorage {
  SharedNotificationPreferencesStorage(this.preferences);
  final SharedPreferences preferences;
  @override
  String? read(String key) => preferences.getString(key);
  @override
  Future<bool> write(String key, String value) =>
      preferences.setString(key, value);
}

/// One initialized instance is shared across account containers. Writes to each
/// account are serialized, including a logout/login while an old write is pending.
class NotificationPreferencesStore {
  NotificationPreferencesStore(this.storage);
  final NotificationPreferencesStorage storage;
  final _confirmed = <String, String?>{};
  final _tails = <String, Future<void>>{};
  String _key(String owner) {
    if (owner.trim().isEmpty) throw ArgumentError('Account is required');
    return 'in_app_notification_preferences.v1.${Uri.encodeComponent(owner)}';
  }

  InAppNotificationPreferences load(String owner) {
    final key = _key(owner);
    final raw = _confirmed.containsKey(key)
        ? _confirmed[key]
        : storage.read(key);
    // Retain confirmed values even if SharedPreferences optimistically changes
    // its cache before a rejected platform write.
    _confirmed[key] = raw;
    return raw == null
        ? InAppNotificationPreferences(enabled: true, daysBefore: 3)
        : InAppNotificationPreferences.decode(raw);
  }

  void forgetFailedLoad(String owner) => _confirmed.remove(_key(owner));
  Future<void> save(String owner, InAppNotificationPreferences value) {
    final key = _key(owner);
    if (!_confirmed.containsKey(key)) _confirmed[key] = storage.read(key);
    final previous = _tails[key] ?? Future<void>.value();
    final result = previous.then((_) async {
      final raw = value.encode();
      if (!await storage.write(key, raw)) {
        throw StateError('Preferences write failed');
      }
      _confirmed[key] = raw;
    });
    // A rejected write must not poison later retries or other queued writes.
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tails[key] = tail;
    tail.then((_) {
      if (identical(_tails[key], tail)) _tails.remove(key);
    });
    return result;
  }
}
