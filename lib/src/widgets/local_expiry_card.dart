import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../local_expiry_provider.dart';
import '../providers.dart';
import '../services/auth_gateway.dart';
import '../services/local_expiry_reminders.dart';

class LocalExpiryCard extends ConsumerStatefulWidget {
  const LocalExpiryCard({super.key});
  @override
  ConsumerState<LocalExpiryCard> createState() => _LocalExpiryCardState();
}

class _LocalExpiryCardState extends ConsumerState<LocalExpiryCard> {
  int _days = 3;
  bool _requesting = false;
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      if (!mounted) return;
      final owner = ref.read(authGatewayProvider).accountId;
      if (owner != null)
        await ref.read(localExpiryControllerProvider).refresh(owner);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(localExpiryControllerProvider);
    final auth = ref.watch(authGatewayProvider);
    final stock = ref.watch(ingredientsProvider);
    final owner = auth.accountId;
    final ready =
        owner != null &&
        !localExpiryMutationInProgress(owner) &&
        auth.sessionUsable &&
        stock.hasValue &&
        !stock.isLoading &&
        !stock.hasError;
    Future<void> enable(int days) async {
      if (!ready || _requesting) return;
      setState(() => _requesting = true);
      final mutationEpoch = localExpiryMutationEpoch(owner);
      try {
        final captured = await ref.read(localExpiryDatesReaderProvider)(owner);
        if (!mounted) return;
        final project = dotenv.isInitialized
            ? Uri.tryParse(
                    dotenv.env['SUPABASE_URL'] ?? '',
                  )?.host.split('.').first ??
                  ''
            : '';
        await controller.enable(
          owner: owner,
          project: project,
          days: days,
          dates: captured,
          current: () =>
              mounted &&
              !localExpiryMutationInProgress(owner) &&
              localExpiryMutationEpoch(owner) == mutationEpoch &&
              ref.read(authGatewayProvider).accountId == owner &&
              ref.read(authGatewayProvider).sessionUsable,
        );
      } catch (_) {
        controller.reportFailure();
      } finally {
        if (mounted) setState(() => _requesting = false);
      }
    }

    String date(DateTime value) =>
        '${value.month}월 ${value.day}일 ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final supported = controller.platform.supported;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    '자동 기한 알림',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('기한이 가까운 재료가 있으면 오전 9시 기준 하루 한 번'),
                  value: state.enabled,
                  onChanged:
                      !supported ||
                          controller.busy ||
                          _requesting ||
                          owner == null ||
                          (!state.enabled && !ready)
                      ? null
                      : (value) {
                          if (value) {
                            enable(_days);
                          } else {
                            controller.disable(owner);
                          }
                        },
                ),
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('소비기한 당일까지'),
                    DropdownButton<int>(
                      value: state.enabled ? state.days : _days,
                      items: [1, 3, 7]
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text('$d일 전'),
                            ),
                          )
                          .toList(),
                      onChanged:
                          controller.busy ||
                              !supported ||
                              (state.enabled && !ready)
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() => _days = value);
                              if (state.enabled) enable(value);
                            },
                    ),
                  ],
                ),
                const Text(
                  '이 휴대폰에서 마지막으로 확인한 재료 기준이에요. 재료를 수정하거나 삭제하면 동기화 후 반영해요. 다른 기기에서 바꾼 내용은 이 앱을 열어 동기화해야 반영됩니다.',
                ),
                const SizedBox(height: 8),
                const Text(
                  '인터넷이 없어도 예약은 유지돼요. 소리 없이 알림창에 표시되며, 절전 상태에 따라 오전 중 늦게 오거나 건너뛸 수 있어요. 로그아웃·계정 변경 또는 끄기를 하면 취소돼요.',
                ),
                const SizedBox(height: 8),
                Text(
                  !supported
                      ? 'Android 기기에서 사용할 수 있어요.'
                      : controller.busy
                      ? '알림 설정을 확인하고 있어요…'
                      : !state.enabled
                      ? '자동 알림이 꺼져 있어요.'
                      : !state.permission
                      ? '휴대폰 알림 또는 이 알림 채널이 꺼져 있어요. 설정에서 허용해 주세요.'
                      : state.updatedAt == null
                      ? '재료 변경 결과를 확인할 때까지 알림을 멈췄어요. 재고를 새로고침해 주세요.'
                      : state.nextAt != null
                      ? '다음 예약: ${date(state.nextAt!)} 전후'
                      : '현재 예약할 재료가 없어요. 재료를 동기화하면 자동으로 다시 확인해요.',
                ),
                if (!ready && !state.enabled)
                  const Text('로그인과 재고 불러오기를 완료한 뒤 켤 수 있어요.'),
                if (controller.error != null)
                  Text(
                    controller.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (owner != null)
                  TextButton(
                    onPressed: controller.busy
                        ? null
                        : () => controller.refresh(owner),
                    child: const Text('상태 다시 확인'),
                  ),
                if (kDebugMode && state.enabled && owner != null) ...[
                  OutlinedButton(
                    onPressed: controller.busy
                        ? null
                        : () => controller.test(owner),
                    child: const Text('실제 재료 알림 1회 확인'),
                  ),
                  const Text(
                    '현재 조건에 맞는 재료가 있을 때 약 1분 뒤 테스트해요. 정기 예약과 별개이며 소리 없이 표시돼요.',
                  ),
                  if (controller.testDue != null)
                    Text(
                      '테스트 요청: ${date(controller.testDue!)} 이후 · 실제 수신은 알림창에서 확인해 주세요.',
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
