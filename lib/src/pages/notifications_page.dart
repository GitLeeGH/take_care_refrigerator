import '../widgets/app_presentation.dart';
import '../widgets/local_expiry_card.dart';
import '../widgets/test_notification_card.dart';
import '../widgets/one_shot_expiry_card.dart';
import '../services/notification_service.dart';
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
    final dismissedNotifier = ref.read(dismissedNotificationsProvider.notifier);

    // 동적으로 생성된 알림 사용 (중복 방지, 삭제된 항목 제외)
    final notifications = ref.watch(generatedNotificationsProvider);

    const accentColor = primaryGreen;

    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        toolbarHeight: pageToolbarHeight(context),
        title: Row(
          children: [
            const Text(
              '알림',
              style: TextStyle(color: darkGray, fontWeight: FontWeight.bold),
            ),
            if (notifications.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: dangerInk,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${notifications.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: lightGray,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                dismissedNotifier.dismissAll(
                  notifications.map((n) => n.id).toList(),
                );
              },
              child: const Text(
                '모두 지우기',
                style: TextStyle(color: dangerInk, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 28),
        children: [
          const LocalExpiryCard(),
          const SizedBox(height: 16),
          // 알림 목록 섹션
          if (notifications.isNotEmpty) ...[
            const Text(
              '알림 목록',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkGray,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '지운 알림은 다음 날이나 소비기한 변경 시 다시 표시됩니다. 앱을 다시 시작하면 표시될 수 있습니다.',
              ),
            ),
            const SizedBox(height: 12),
            ...notifications.map(
              (notification) =>
                  _buildNotificationItem(context, notification, () {
                    dismissedNotifier.dismiss(notification.id);
                  }),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 48,
                    color: mediumGray,
                  ),
                  SizedBox(height: 12),
                  Text(
                    '알림이 없습니다',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: mediumGray,
                    ),
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkGray,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              title: const Text(
                '앱 안에서 기한 안내 보기',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                '현재 계정의 재료를 앱 화면에서 확인합니다. 시스템 알림은 발송하지 않습니다.',
                style: TextStyle(color: mediumGray),
              ),
              value: settings.notificationsEnabled,
              onChanged: (bool value) =>
                  settingsNotifier.toggleNotifications(value),
              activeThumbColor: accentColor,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              title: const Text(
                '화면 안내 기간 설정',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: Text(
                '${settings.daysBefore}일 전',
                style: const TextStyle(color: mediumGray, fontSize: 16),
              ),
              enabled: settings.notificationsEnabled,
              onTap: () {
                if (settings.notificationsEnabled) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('화면 안내 기간 선택'),
                      content: RadioGroup<int>(
                        groupValue: settings.daysBefore,
                        onChanged: (value) {
                          if (value != null) {
                            settingsNotifier.setDaysBefore(value);
                            Navigator.of(context).pop();
                          }
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final days in [1, 3, 7])
                              RadioListTile<int>(
                                title: Text('$days일 전'),
                                value: days,
                                activeColor: accentColor,
                              ),
                          ],
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          NotificationSettingsStatus(
            status: settings.persistenceStatus,
            onRetry: settingsNotifier.retryPersistence,
          ),
          const SizedBox(height: 16),
          const OneShotExpiryCard(),
          const TestNotificationCard(),
          ValueListenableBuilder<NotificationCleanupStatus>(
            valueListenable: NotificationService().status,
            builder: (context, status, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(switch (status) {
                    NotificationCleanupStatus.pending =>
                      '기존 테스트 알림을 확인하고 있습니다. 응답이 늦으면 정리가 지연될 수 있습니다.',
                    NotificationCleanupStatus.complete =>
                      '확인 가능한 기존 테스트 알림만 정리했습니다. 다른 알림은 유지합니다.',
                    NotificationCleanupStatus.failed =>
                      '일부 테스트 알림의 확인 또는 정리를 완료하지 못했습니다. 다른 알림은 유지하며 다시 시도할 수 있습니다.',
                  }),
                  if (status == NotificationCleanupStatus.failed)
                    TextButton(
                      onPressed: () {
                        NotificationService().cancelLegacyNotifications();
                      },
                      child: const Text('예약 정리 다시 시도'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              '이 설정은 현재 계정의 앱 화면 안내에만 적용됩니다.',
              style: TextStyle(
                color: mediumGray,
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    NotificationItem notification,
    VoidCallback onRemove,
  ) {
    Color priorityColor;
    IconData priorityIcon;

    switch (notification.priority) {
      case NotificationPriority.urgent:
        priorityColor = dangerInk;
        priorityIcon = Icons.error_outline;
        break;
      case NotificationPriority.warning:
        priorityColor = warningInk;
        priorityIcon = Icons.warning_amber_outlined;
        break;
      case NotificationPriority.info:
        priorityColor = primaryGreen;
        priorityIcon = Icons.info_outline;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            backgroundColor: priorityColor.withValues(alpha: 0.1),
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
              Text(notification.message, style: const TextStyle(fontSize: 13)),
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
                    child: const Text('삭제', style: TextStyle(color: dangerInk)),
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

/// Persistence feedback is separate from system notification permissions.
class NotificationSettingsStatus extends StatelessWidget {
  const NotificationSettingsStatus({
    super.key,
    required this.status,
    required this.onRetry,
  });
  final NotificationSettingsPersistence status;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final failed =
        status == NotificationSettingsPersistence.loadFailed ||
        status == NotificationSettingsPersistence.writeFailed;
    final message = switch (status) {
      NotificationSettingsPersistence.saved => '현재 계정의 화면 안내 설정이 이 기기에 저장됩니다.',
      NotificationSettingsPersistence.saving => '화면 안내 설정을 저장하고 있어요.',
      NotificationSettingsPersistence.loadFailed =>
        '저장된 설정을 읽지 못해 앱 안의 기한 안내를 꺼 두었어요. 다시 불러오거나 설정을 직접 선택해 주세요.',
      NotificationSettingsPersistence.writeFailed =>
        '선택한 설정은 지금 적용되지만 저장하지 못했어요. 앱을 다시 시작하기 전에 다시 시도해 주세요.',
      NotificationSettingsPersistence.memoryOnly => '화면 안내 설정은 이번 실행에만 적용됩니다.',
    };
    return Semantics(
      liveRegion: failed || status == NotificationSettingsPersistence.saving,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: failed ? peachSurface : softGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color: failed ? warningInk : mediumGray,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            if (failed) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () {
                  onRetry();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(
                  status == NotificationSettingsPersistence.loadFailed
                      ? '설정 다시 불러오기'
                      : '설정 저장 다시 시도',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
