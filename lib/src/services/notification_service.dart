import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  static const String _notificationPermissionKey =
      'notification_permissions_requested';
  static const String _exactAlarmPermissionKey =
      'exact_alarm_permission_requested';

  bool _initialized = false;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  bool get isInitialized => _initialized;

  Future<void> init() async {
    // 이미 초기화되었으면 스킵
    if (_initialized) {
      print('✅ NotificationService는 이미 초기화됨 (스킵)');
      return;
    }

    print('📱 NotificationService 초기화 시작...');
    try {
      // Timezone 초기화 (한 번만 필요하지만, 여러 번 호출해도 안전)
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
      print('✅ Timezone 초기화 완료 - Asia/Seoul');

      // Android 초기화 설정
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS 초기화 설정
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      final InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      await flutterLocalNotificationsPlugin.initialize(initializationSettings);
      print('✅ FlutterLocalNotificationsPlugin 초기화 완료');

      // 권한 요청 (한 번만)
      await _requestPermissionsOnce();

      _initialized = true;
      print('📱 NotificationService 초기화 완료!');
    } catch (e) {
      print('❌ NotificationService 초기화 실패: $e');
    }
  }

  Future<void> _requestPermissionsOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Android 알림 권한 요청
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidImplementation != null) {
        // 정확한 알람 권한 요청 (Android 12+에서 필요, 한 번만)
        if (!prefs.containsKey(_exactAlarmPermissionKey)) {
          print('🔐 SCHEDULE_EXACT_ALARM 권한 요청 중...');
          await androidImplementation.requestExactAlarmsPermission();
          await prefs.setBool(_exactAlarmPermissionKey, true);
          print('✅ SCHEDULE_EXACT_ALARM 권한 요청 완료 (저장됨)');
        } else {
          print('✅ SCHEDULE_EXACT_ALARM 권한 이미 요청됨 (스킵)');
        }

        // 알림 권한 요청 (한 번만)
        if (!prefs.containsKey(_notificationPermissionKey)) {
          print('🔐 POST_NOTIFICATIONS 권한 요청 중...');
          await androidImplementation.requestNotificationsPermission();
          await prefs.setBool(_notificationPermissionKey, true);
          print('✅ POST_NOTIFICATIONS 권한 요청 완료 (저장됨)');
        } else {
          print('✅ POST_NOTIFICATIONS 권한 이미 요청됨 (스킵)');
        }
      } else {
        print('⚠️ Android 구현을 찾을 수 없습니다');
      }
    } catch (e) {
      print('⚠️ 권한 요청 중 오류: $e');
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      // scheduledDate를 그대로 사용 (시간이 이미 설정되어 있음)
      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
      final now = tz.TZDateTime.now(tz.local);

      print(
        '⏰ 알림 예약: ID=$id, 제목="$title", 예약시간="${tzScheduledDate.toString()}", 현재시간="${now.toString()}"',
      );

      // 예약 시간까지의 지연 시간 계산
      final delayDuration = tzScheduledDate.difference(now);

      if (delayDuration.isNegative) {
        // 과거 시간: 즉시 표시
        print('⚠️ 과거 시간으로 스케줄됨 - 즉시 표시합니다');
        await flutterLocalNotificationsPlugin.show(
          id,
          title,
          body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'refrigerator_channel_id',
              '유통기한 알림',
              channelDescription: '냉장고 유통기한 알림 채널',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
              enableVibration: true,
              playSound: true,
            ),
            iOS: DarwinNotificationDetails(
              badgeNumber: 1,
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
      } else if (delayDuration.inSeconds <= 5) {
        // 5초 이하: Timer + show() 사용 (정확성 향상)
        print('🕐 단기 알림: Timer를 사용하여 ${delayDuration.inSeconds}초 후 표시합니다');
        Timer(delayDuration, () async {
          await flutterLocalNotificationsPlugin.show(
            id,
            title,
            body,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'refrigerator_channel_id',
                '유통기한 알림',
                channelDescription: '냉장고 유통기한 알림 채널',
                importance: Importance.max,
                priority: Priority.high,
                showWhen: true,
                enableVibration: true,
                playSound: true,
              ),
              iOS: DarwinNotificationDetails(
                badgeNumber: 1,
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
          );
          print('✅ Timer로 즉시 표시: $title');
        });
      } else {
        // 5초 초과: Timer 사용 (zonedSchedule 대신)
        print('� 장기 알림: Timer를 사용하여 ${delayDuration.inSeconds}초 후 표시합니다');
        Timer(delayDuration, () async {
          await flutterLocalNotificationsPlugin.show(
            id,
            title,
            body,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'refrigerator_channel_id',
                '유통기한 알림',
                channelDescription: '냉장고 유통기한 알림 채널',
                importance: Importance.max,
                priority: Priority.high,
                showWhen: true,
                enableVibration: true,
                playSound: true,
              ),
              iOS: DarwinNotificationDetails(
                badgeNumber: 1,
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
          );
          print('✅ Timer로 표시: $title');
        });
      }

      print('✅ 알림 예약 성공: $title');
    } catch (e) {
      print('❌ 알림 예약 실패: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> showImmediateExpiryAlert(
    String ingredientName,
    int daysLeft,
  ) async {
    final String title;
    final String body;

    if (daysLeft <= 0) {
      title = '🚨 유통기한 초과!';
      body = daysLeft == 0
          ? '$ingredientName의 유통기한이 오늘까지입니다!'
          : '$ingredientName의 유통기한이 ${-daysLeft}일 지났습니다!';
    } else {
      title = '⚠️ 유통기한 임박!';
      body = '$ingredientName의 유통기한이 ${daysLeft}일 남았습니다!';
    }

    await flutterLocalNotificationsPlugin.show(
      ingredientName.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'refrigerator_channel_id',
          '유통기한 알림',
          channelDescription: '냉장고 유통기한 알림 채널',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        ),
      ),
    );
  }
}
