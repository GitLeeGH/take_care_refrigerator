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
    final notifications = ref.watch(notificationListProvider);
    final notificationsNotifier = ref.read(notificationListProvider.notifier);
    const accentColor = Color(0xFF20C997);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          children: [
            const Text('알림', style: TextStyle(color: darkGray, fontWeight: FontWeight.bold)),
            if (notifications.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${notifications.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('모든 알림 삭제'),
                    content: const Text('모든 알림을 삭제하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () {
                          notificationsNotifier.clearAllNotifications();
                          Navigator.of(context).pop();
                        },
                        child: const Text('삭제', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('모두 삭제', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 알림 목록 섹션
          if (notifications.isNotEmpty) ...[
            const Text(
              '알림 목록',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkGray),
            ),
            const SizedBox(height: 12),
            ...notifications.map((notification) => _buildNotificationItem(
              context, 
              notification, 
              () => notificationsNotifier.removeNotification(notification.id)
            )),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.notifications_off_outlined, size: 48, color: mediumGray),
                  SizedBox(height: 12),
                  Text(
                    '알림이 없습니다',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: mediumGray),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '유통기한이 임박한 재료가 있으면 알림이 표시됩니다',
                    style: TextStyle(color: mediumGray, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // 설정 섹션
          const Text(
            '알림 설정',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkGray),
          ),
          const SizedBox(height: 12),
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
              activeThumbColor: accentColor,
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
          const SizedBox(height: 20),
          // 테스트 알림 버튼 추가
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              title: const Text('알림 테스트', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('알림이 정상적으로 작동하는지 테스트합니다.', style: TextStyle(color: mediumGray)),
              trailing: ElevatedButton(
                onPressed: () async {
                  final notificationService = await ref.read(notificationServiceProvider.future);
                  await notificationService.showTestNotification();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('테스트 알림을 전송했습니다!')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('테스트'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 임박 재료 즉시 알림 버튼
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              title: const Text('임박 재료 즉시 알림', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('유통기한이 임박한 재료들을 바로 확인합니다.', style: TextStyle(color: mediumGray)),
              trailing: ElevatedButton(
                onPressed: () async {
                  final notificationService = await ref.read(notificationServiceProvider.future);
                  final ingredientsValue = ref.read(ingredientsProvider);
                  
                  if (ingredientsValue.hasValue) {
                    final ingredients = ingredientsValue.value!;
                    final now = DateTime.now();
                    int alertCount = 0;
                    
                    for (final ingredient in ingredients) {
                      final daysLeft = ingredient.expiryDate.difference(now).inDays;
                      if (daysLeft <= 3) { // 3일 이내
                        await notificationService.showImmediateExpiryAlert(
                          ingredient.name, 
                          daysLeft
                        );
                        alertCount++;
                        await Future.delayed(const Duration(milliseconds: 500)); // 알림 간격
                      }
                    }
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(alertCount > 0 
                            ? '$alertCount개의 임박 재료 알림을 전송했습니다!' 
                            : '임박한 재료가 없습니다.')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB74D), // Orange
                  foregroundColor: Colors.white,
                ),
                child: const Text('확인'),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              '알림은 설정된 시간(오전 9시)에 전송됩니다. 테스트 알림으로 먼저 확인해보세요.',
              style: TextStyle(color: mediumGray, fontStyle: FontStyle.italic, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, NotificationItem notification, VoidCallback onRemove) {
    Color priorityColor;
    IconData priorityIcon;
    
    switch (notification.priority) {
      case NotificationPriority.urgent:
        priorityColor = Colors.red;
        priorityIcon = Icons.error_outline;
        break;
      case NotificationPriority.warning:
        priorityColor = const Color(0xFFFFB74D);
        priorityIcon = Icons.warning_amber_outlined;
        break;
      case NotificationPriority.info:
        priorityColor = const Color(0xFF20C997);
        priorityIcon = Icons.info_outline;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: priorityColor.withOpacity(0.1),
            child: Icon(priorityIcon, color: priorityColor, size: 20),
          ),
          title: Text(
            notification.title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notification.message,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                _formatNotificationTime(notification.createdAt),
                style: const TextStyle(fontSize: 11, color: mediumGray),
              ),
            ],
          ),
          trailing: IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, color: mediumGray, size: 20),
            tooltip: '알림 삭제',
          ),
          onTap: () {
            // 알림 탭 시 상세 정보 표시 (선택사항)
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(notification.title),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.message),
                    const SizedBox(height: 8),
                    Text(
                      '알림 시간: ${_formatNotificationTime(notification.createdAt)}',
                      style: const TextStyle(fontSize: 12, color: mediumGray),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('확인'),
                  ),
                  TextButton(
                    onPressed: () {
                      onRemove();
                      Navigator.of(context).pop();
                    },
                    child: const Text('삭제', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatNotificationTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}