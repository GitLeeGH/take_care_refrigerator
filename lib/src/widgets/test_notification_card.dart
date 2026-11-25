import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../services/one_shot_expiry_reminder.dart';

/// Explicit generic test only. Separate ID/payload; never reads inventory.
class TestNotificationPlatform implements ExpiryReminderPlatform {
  static const id = 730042,
      marker = 'tcf.explicit-test.v1',
      channel = 'explicit_test_v1';
  final plugin = FlutterLocalNotificationsPlugin();
  bool get supported => !kIsWeb && Platform.isAndroid;
  Future<void> init() async {
    if (!supported) throw StateError('Unsupported');
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  Future<void> ownership() async {
    if ((await plugin.pendingNotificationRequests()).any(
      (n) => n.id == id && n.payload != marker,
    )) {
      throw StateError('ID occupied');
    }
  }

  Future<bool> allowed(AndroidFlutterLocalNotificationsPlugin a) async {
    final channels = await a.getNotificationChannels();
    return channels != null &&
        !channels.any(
          (c) => c.id == channel && c.importance == Importance.none,
        );
  }

  @override
  Future<bool> permission() async {
    if (!supported) return false;
    await init();
    final a = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (a == null || !await allowed(a)) return false;
    return (await a.areNotificationsEnabled() == true ||
            await a.requestNotificationsPermission() == true) &&
        await allowed(a);
  }

  @override
  Future<void> cancelOwned() async {
    if (!supported) return;
    await init();
    await ownership();
    await plugin.cancel(id, tag: marker);
  }

  @override
  Future<void> schedule(DateTime at) async {
    await init();
    await ownership();
    final a = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (a == null ||
        await a.areNotificationsEnabled() != true ||
        !await allowed(a) ||
        !at.isAfter(DateTime.now())) {
      throw StateError('Unavailable');
    }
    await plugin.zonedSchedule(
      id,
      '테스트 알림',
      '사용자가 요청한 1회 수신 확인입니다. 실제 재료 기한이나 반복 알림이 아닙니다.',
      tz.TZDateTime.from(at.toUtc(), tz.UTC),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          '테스트 알림',
          channelDescription: '사용자가 버튼으로 요청한 1회 수신 확인',
          tag: marker,
          visibility: NotificationVisibility.private,
          playSound: false,
          enableVibration: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: marker,
    );
  }
}

final explicitTestReminder = OneShotExpiryReminder(TestNotificationPlatform());

class TestNotificationCard extends StatelessWidget {
  const TestNotificationCard({super.key, this.reminder});
  final OneShotExpiryReminder? reminder;
  @override
  Widget build(BuildContext context) {
    final service = reminder ?? explicitTestReminder;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder(
          valueListenable: service.status,
          builder: (context, status, _) {
            final busy =
                status == OneShotStatus.busy ||
                status == OneShotStatus.cancelling;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('테스트 알림', style: Theme.of(context).textTheme.titleLarge),
                const Text(
                  '버튼을 누르면 약 1분 뒤 1회 알림을 요청해요. 절전·OS 상태에 따라 늦거나 표시되지 않을 수 있어요. 소리 없이 알림창에서 확인해 주세요.',
                ),
                const Text(
                  '실제 재료나 반복 알림이 아니며 기존 기한 예약과 별개예요. 앱 재시작·로그아웃·알림 설정 변경 시 취소될 수 있어요.',
                ),
                if (status == OneShotStatus.scheduled)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      '테스트 예약 요청 완료 · 실제 수신은 아직 확인되지 않았어요. 다시 요청하려면 먼저 취소해 주세요.',
                    ),
                  ),
                if (status == OneShotStatus.denied)
                  const Text('알림 권한 또는 테스트 채널이 꺼져 있어요. 휴대폰 알림 설정을 직접 확인해 주세요.'),
                if (status == OneShotStatus.failed)
                  const Text('예약 또는 취소를 확인하지 못했어요. 테스트 취소 후 다시 시도해 주세요.'),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: busy || status == OneShotStatus.scheduled
                          ? null
                          : () => service.request(
                              at: DateTime.now().add(
                                const Duration(minutes: 1),
                              ),
                              stillValid: () => true,
                            ),
                      child: Text(busy ? '처리 중…' : '약 1분 뒤 테스트 알림'),
                    ),
                    TextButton(
                      onPressed: status == OneShotStatus.cancelling
                          ? null
                          : () => service.cancel(),
                      child: const Text('테스트만 취소'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
