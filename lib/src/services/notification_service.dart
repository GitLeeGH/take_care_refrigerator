
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Timezone 초기화
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

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

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Android 알림 권한 요청
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    // 정확한 알람 권한 요청 (Android 12+에서 필요)
    await androidImplementation?.requestExactAlarmsPermission();
    
    // 알림 권한 요청
    await androidImplementation?.requestNotificationsPermission();
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // 시간을 오전 9시로 설정
    final scheduledDateTime = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      9, // 오전 9시
    );
    
    final tzScheduledDate = tz.TZDateTime.from(scheduledDateTime, tz.local);
    
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
        ),
        iOS: DarwinNotificationDetails(
          badgeNumber: 1,
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> showTestNotification() async {
    await flutterLocalNotificationsPlugin.show(
      999,
      '테스트 알림',
      '알림 시스템이 정상적으로 작동합니다!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'refrigerator_channel_id',
          '유통기한 알림',
          channelDescription: '냉장고 유통기한 알림 채널',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> showImmediateExpiryAlert(String ingredientName, int daysLeft) async {
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
