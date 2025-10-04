import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final settingsNotifier = ref.read(notificationSettingsProvider.notifier);
    const accentColor = Color(0xFF20C997);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('알림 설정', style: TextStyle(color: darkGray, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              title: const Text('유통기한 알림 받기', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('설정한 기간에 따라 유통기한 임박 알림을 보냅니다.', style: TextStyle(color: mediumGray)),
              value: settings.notificationsEnabled,
              onChanged: (bool value) => settingsNotifier.toggleNotifications(value),
              activeColor: accentColor,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              title: const Text('알림 시기 설정', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: Text('${settings.daysBefore}일 전', style: const TextStyle(color: mediumGray, fontSize: 16)),
              enabled: settings.notificationsEnabled,
              onTap: () {
                if (settings.notificationsEnabled) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('알림 시기 선택'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [1, 3, 7].map((days) {
                          return RadioListTile<int>(
                            title: Text('$days일 전'),
                            value: days,
                            groupValue: settings.daysBefore,
                            activeColor: accentColor,
                            onChanged: (value) {
                              if (value != null) {
                                settingsNotifier.setDaysBefore(value);
                                Navigator.of(context).pop();
                              }
                            },
                          );
                        }).toList(),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 30),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              '참고: 실제 푸시 알림은 별도의 서버 및 플랫폼별 설정이 필요합니다. 이 화면은 UI 구현 예시입니다.',
              style: TextStyle(color: mediumGray, fontStyle: FontStyle.italic, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}