import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    print('📱 NotificationService 초기화 시작...');
    try {
      // Timezone 초기화
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

      // Android 알림 권한 요청
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidImplementation != null) {
        // 정확한 알람 권한 요청 (Android 12+에서 필요)
        print('🔐 Android 권한 요청 중...');
        await androidImplementation.requestExactAlarmsPermission();
        print('✅ SCHEDULE_EXACT_ALARM 권한 요청 완료');

        // 알림 권한 요청
        await androidImplementation.requestNotificationsPermission();
        print('✅ POST_NOTIFICATIONS 권한 요청 완료');
      } else {
        print('⚠️ Android 구현을 찾을 수 없습니다');
      }
      
      print('📱 NotificationService 초기화 완료!');
    } catch (e) {
      print('❌ NotificationService 초기화 실패: $e');
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      // 시간을 오전 9시로 설정
      final scheduledDateTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        9, // 오전 9시
      );

      final tzScheduledDate = tz.TZDateTime.from(scheduledDateTime, tz.local);
      
      print('⏰ 알림 예약: ID=$id, 제목="$title", 예약시간="${tzScheduledDate.toString()}"');

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      
      print('✅ 알림 예약 성공: $title');
    } catch (e) {
      print('❌ 알림 예약 실패: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> showTestNotification() async {
    try {
      print('🧪 테스트 알림 표시 중...');
      await flutterLocalNotificationsPlugin.show(
        999,
        '✅ 테스트 알림',
        '알림 시스템이 정상적으로 작동합니다!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'refrigerator_channel_id',
            '유통기한 알림',
            channelDescription: '냉장고 유통기한 알림 채널',
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
          ),
        ),
      );
      print('✅ 테스트 알림 표시 완료');
    } catch (e) {
      print('❌ 테스트 알림 표시 실패: $e');
    }
  }

  Future<void> scheduleTestNotification() async {
    try {
      print('🧪 5초 후 테스트 알림 예약 중...');
      final now = DateTime.now();
      final testTime = now.add(const Duration(seconds: 5));
      final tzTestTime = tz.TZDateTime.from(testTime, tz.local);

      await flutterLocalNotificationsPlugin.zonedSchedule(
        888,
        '⏱️ 테스트 예약 알림',
        '5초 후에 표시되는 알림입니다!',
        tzTestTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'refrigerator_channel_id',
            '유통기한 알림',
            channelDescription: '냉장고 유통기한 알림 채널',
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      print('✅ 테스트 예약 알림 설정 완료 (5초 후 표시 예정)');
    } catch (e) {
      print('❌ 테스트 예약 알림 설정 실패: $e');
    }
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
