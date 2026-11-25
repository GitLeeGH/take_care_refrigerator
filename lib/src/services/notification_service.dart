import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum NotificationCleanupStatus { pending, complete, failed }

/// System delivery is disabled until inventory/account-aware delivery is verified.
/// Cancels alarm ID 0 and only positively identified legacy test notifications.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  @visibleForTesting
  NotificationService.forTesting({
    required Future<void> Function() cancelAlarm,
    required Future<List<ActiveNotification>> Function() activeNotifications,
    required Future<void> Function(int) cancelNotification,
  }) : _cancelAlarm = cancelAlarm,
       _activeNotifications = activeNotifications,
       _cancelNotification = cancelNotification;
  Future<void> Function()? _cancelAlarm;
  Future<List<ActiveNotification>> Function()? _activeNotifications;
  Future<void> Function(int)? _cancelNotification;

  // Historical showImmediateExpiryAlert used ingredientName.hashCode as its ID.
  // Never assume a hash is stable across runtimes; also require exact content.
  static Map<int, ({String title, String body})> get legacyTestAlerts => {
    '테스트 재료'.hashCode: (title: '⚠️ 유통기한 임박!', body: '테스트 재료의 유통기한이 1일 남았습니다!'),
    '유통기한 확인'.hashCode: (title: '🚨 유통기한 초과!', body: '유통기한 확인의 유통기한이 오늘까지입니다!'),
  };

  Future<bool> _cancelIdentifiedTestAlerts() async {
    final active =
        await (_activeNotifications?.call() ??
            _plugin.getActiveNotifications());
    var success = true;
    final known = legacyTestAlerts;
    for (final alert in active) {
      final expected = known[alert.id];
      final exactContent =
          expected != null &&
          alert.title == expected.title &&
          alert.body == expected.body;
      final testContent = known.values.any(
        (value) => alert.title == value.title && alert.body == value.body,
      );
      if (!exactContent ||
          alert.channelId != 'refrigerator_channel_id' ||
          alert.tag != null) {
        // A recognizable test message with an unknown hash/channel cannot safely
        // be attributed to the old producer. Leave it intact and report partial cleanup.
        if (testContent) success = false;
        continue;
      }
      try {
        if (_cancelNotification != null) {
          await _cancelNotification!(alert.id!);
        } else {
          await _plugin.cancel(alert.id!);
        }
      } catch (_) {
        success = false;
      }
    }
    return success;
  }

  final status = ValueNotifier(NotificationCleanupStatus.pending);
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<bool>? _cleanup;
  bool get isInitialized => _initialized;

  // Kept compatible with old callers. Even true never requests permissions.
  Future<void> init({bool requestPermissions = false}) async {
    if (_initialized || kIsWeb || !(Platform.isAndroid || Platform.isIOS))
      return;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  Future<bool> cancelLegacyNotifications() {
    return _cleanup ??= _runCleanup().whenComplete(() => _cleanup = null);
  }

  Future<bool> _runCleanup() async {
    status.value = NotificationCleanupStatus.pending;
    var success = true;
    // Attempt both independently: an alarm failure must not leave visible alerts.
    try {
      if (_cancelAlarm != null) {
        await _cancelAlarm!();
      } else if (!kIsWeb && Platform.isAndroid) {
        if (!await AndroidAlarmManager.initialize() ||
            !await AndroidAlarmManager.cancel(0))
          throw StateError('alarm cleanup');
      }
    } catch (_) {
      success = false;
    }
    try {
      if (_activeNotifications != null) {
        if (!await _cancelIdentifiedTestAlerts()) success = false;
      } else if (!kIsWeb && Platform.isAndroid) {
        await init();
        if (!await _cancelIdentifiedTestAlerts()) success = false;
      }
    } catch (_) {
      success = false;
    }
    status.value = success
        ? NotificationCleanupStatus.complete
        : NotificationCleanupStatus.failed;
    return success;
  }

  // Fail closed even if an old caller or persisted callback invokes these APIs.
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {}
  Future<void> showImmediateExpiryAlert(
    String ingredientName,
    int daysLeft,
  ) async {}
}
