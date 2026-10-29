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

  Future<void> init({bool requestPermissions = true}) async {
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

      // Android 알림 채널 생성 (zonedSchedule 사용 시 필수)
      await _createNotificationChannels();
      print('✅ Android 알림 채널 생성 완료');

      // 권한 요청 (한 번만)
      if (requestPermissions) await _requestPermissionsOnce();

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

  // Android 알림 채널 생성 (zonedSchedule 사용 시 필수)
  Future<void> _createNotificationChannels() async {
    try {
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        // 기본 알림 채널 생성
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'refrigerator_channel_id',
          '유통기한 알림',
          description: '냉장고 유통기한 알림 채널',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );

        await androidImplementation.createNotificationChannel(channel);
        print('✅ Android 알림 채널 "refrigerator_channel_id" 생성 완료');
      }
    } catch (e) {
      print('⚠️ 알림 채널 생성 중 오류: $e');
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final lastNotificationDate = prefs.getString('last_notification_$id');

      print(
        '⏰ 알림 예약: ID=$id, 제목="$title", 예약시간="${scheduledDate.toString()}", 현재시간="${now.toString()}"',
      );

      // 오늘 날짜 문자열 (yyyy-MM-dd)
      final todayString =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // 이미 오늘 알림을 보냈는지 확인
      if (lastNotificationDate == todayString) {
        print('✅ 오늘 이미 알림 전송됨: $title (마지막 전송: $lastNotificationDate)');
        return;
      }

      // 예약 시간이 과거면 즉시 알림 표시
      if (now.isAfter(scheduledDate)) {
        print('📨 즉시 알림 표시 (과거 시간): $title');
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

        // 알림 전송 완료 기록
        await prefs.setString('last_notification_$id', todayString);
        print('✅ 알림 전송 완료: $title');
      } else {
        // 아직 예약 시간이 안 됨 - Timer 사용
        final durationUntilScheduled = scheduledDate.difference(now);
        print('⏳ 남은 시간: ${durationUntilScheduled.inSeconds}초 후 알림 예약');

        Timer(durationUntilScheduled, () async {
          print('🔔 Timer 실행됨: $title');
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

          // 알림 전송 완료 기록
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_notification_$id', todayString);
          print('✅ 알림 전송 완료: $title');
        });

        print('✅ 알림 예약 성공: $title (${scheduledDate.toString()})');
      }
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
