import '../services/one_shot_receipt.dart';
import 'reminder_readiness.dart';
import '../services/auth_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../services/one_shot_expiry_reminder.dart';

class OneShotExpiryCard extends ConsumerWidget {
  const OneShotExpiryCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stock = ref.watch(ingredientsProvider);
    final auth = ref.watch(authGatewayProvider);
    final settings = ref.watch(notificationSettingsProvider);
    final service = ref.watch(oneShotReminderProvider);
    final ready =
        auth.sessionUsable &&
        !stock.isLoading &&
        !stock.hasError &&
        stock.hasValue &&
        settings.notificationsEnabled;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ValueListenableBuilder<OneShotStatus>(
          valueListenable: service.status,
          builder: (context, status, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '다음 오전 9시, 한 번 기한 확인',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '입력된 기한이 안내 기간 안에 드는 재료가 있을 때 예약합니다. 반복 알림이 아니며, 실제 도착은 절전 설정에 따라 늦어질 수 있습니다. 재료명은 알림에 표시하지 않습니다.',
              ),
              const SizedBox(height: 8),
              const Text(
                '재고 내용·안내 기간·계정이 바뀌거나 앱을 새로 시작하면 취소됩니다. 같은 계정으로 화면에 복귀하거나 같은 재고를 다시 받아도 유지됩니다. 재부팅 후에는 앱을 열어 다시 예약하세요. 다른 기기에서 바뀐 재고는 반영되지 않을 수 있습니다. 여행 중 시간대를 바꾼 경우 취소 후 다시 예약하세요.',
              ),
              const Text(
                '앱이 새로 시작되면 기존 예약을 먼저 취소하고, 같은 계정·동의 기준과 최신 재고를 확인한 경우에만 원래 시각으로 복원합니다. 오프라인·확인 실패·시간대 변경 시 다시 예약해 주세요.',
              ),
              const SizedBox(height: 12),
              Text(switch (status) {
                OneShotStatus.idle => '예약 전입니다.',
                OneShotStatus.busy => '권한과 예약 상태를 확인하고 있습니다.',
                OneShotStatus.cancelling =>
                  '예약 취소를 확인하고 있습니다. 완료 전에는 취소됐다고 단정할 수 없습니다.',
                OneShotStatus.scheduled =>
                  '다음 오전 9시 기준 1회 예약 요청을 완료했습니다. 실제 수신은 아직 확인되지 않았습니다.',
                OneShotStatus.denied =>
                  '알림 권한 또는 기한 확인 채널이 꺼져 있거나 지원하지 않는 기기입니다. 휴대폰 앱 알림 설정을 확인해 주세요. 앱 안의 안내는 계속 이용할 수 있습니다.',
                OneShotStatus.stale =>
                  '이전 예약을 확인할 수 없거나 계정·재고가 달라 예약을 유지하지 않았습니다. 최신 재고를 확인한 뒤 다시 예약해 주세요.',
                OneShotStatus.empty => '다음 오전 9시 기준 안내 기간에 해당하는 재료가 없습니다.',
                OneShotStatus.failed =>
                  '예약 또는 취소를 확인하지 못했습니다. 아래 취소를 다시 눌러 확인해 주세요.',
              }),
              ReminderReadiness(
                sessionUsable: auth.sessionUsable,
                loading: stock.isLoading,
                failed: stock.hasError,
                hasData: stock.hasValue,
                enabled: settings.notificationsEnabled,
                onRetry: () => ref.invalidate(ingredientsProvider),
              ),
              const Text(
                '이 버튼은 위의 자동 알림과 별도인 수동 1회 예약입니다. OS 상황에 따라 늦어지거나 표시되지 않을 수 있습니다.',
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed:
                    ready &&
                        status != OneShotStatus.busy &&
                        status != OneShotStatus.cancelling
                    ? () {
                        final owner = ref
                            .read(supabaseProvider)
                            .auth
                            .currentUser
                            ?.id;
                        if (owner == null ||
                            !ref.read(authGatewayProvider).sessionUsable) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '로그인 상태를 다시 확인해 주세요. 새 알림은 예약하지 않았습니다.',
                              ),
                            ),
                          );
                          return;
                        }
                        final captured = ref.read(ingredientsProvider);
                        final capturedSettings = ref.read(
                          notificationSettingsProvider,
                        );
                        if (captured.isLoading ||
                            captured.hasError ||
                            !captured.hasValue) {
                          return;
                        }
                        final at = nextExpiryReminder(
                          captured.value!,
                          DateTime.now(),
                          capturedSettings.daysBefore,
                        );
                        service.request(
                          at: at,
                          proof: at == null
                              ? null
                              : ReservationProof.create(
                                  owner,
                                  reminderInventoryIdentity(captured.value!),
                                  capturedSettings.daysBefore,
                                  at,
                                ),
                          stillValid: () =>
                              context.mounted &&
                              ref.read(authGatewayProvider).sessionUsable &&
                              ref.read(supabaseProvider).auth.currentUser?.id ==
                                  owner &&
                              !ref.read(ingredientsProvider).isLoading &&
                              !ref.read(ingredientsProvider).hasError &&
                              ref.read(ingredientsProvider).hasValue &&
                              reminderInventoryIdentity(
                                    ref.read(ingredientsProvider).value!,
                                  ) ==
                                  reminderInventoryIdentity(captured.value!) &&
                              ref
                                      .read(notificationSettingsProvider)
                                      .daysBefore ==
                                  capturedSettings.daysBefore &&
                              ref
                                  .read(notificationSettingsProvider)
                                  .notificationsEnabled &&
                              capturedSettings.notificationsEnabled,
                        );
                      }
                    : null,
                child: const Text('권한 확인 후 1회 예약'),
              ),
              TextButton(
                onPressed: status == OneShotStatus.cancelling
                    ? null
                    : () {
                        service.cancel();
                      },
                child: const Text('예약 취소 / 취소 재시도'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
