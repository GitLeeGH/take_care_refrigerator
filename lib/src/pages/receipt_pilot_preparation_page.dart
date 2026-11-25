import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/receipt_pilot_preparation.dart';

class ReceiptPilotPreparationLauncher extends ConsumerWidget {
  const ReceiptPilotPreparationLauncher({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(receiptPilotPreparationEnabledProvider)) {
      return const SizedBox.shrink();
    }
    return Card(
      child: ListTile(
        leading: const Icon(Icons.verified_user_outlined),
        title: const Text('현재 계정의 합성 시험 준비'),
        subtitle: const Text('개발용 · 사진 전송·AI 호출·금액 예약 없음'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ReceiptPilotPreparationPage(),
          ),
        ),
      ),
    );
  }
}

class ReceiptPilotPreparationPage extends ConsumerStatefulWidget {
  const ReceiptPilotPreparationPage({super.key});
  @override
  ConsumerState<ReceiptPilotPreparationPage> createState() =>
      _ReceiptPilotPreparationPageState();
}

class _ReceiptPilotPreparationPageState
    extends ConsumerState<ReceiptPilotPreparationPage>
    with WidgetsBindingObserver {
  ReceiptPilotPreparationController? _controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(receiptPilotPreparationEnabledProvider)) {
      _controller = ref.read(receiptPilotPreparationControllerProvider);
      scheduleMicrotask(() {
        if (mounted) _controller!.initialize();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller?.resumeView();
    } else {
      _controller?.closeReview();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.closeReview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(receiptPilotPreparationEnabledProvider) ||
        _controller == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('현재 계정 시험 준비')),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('현재 계정의 시험 준비 기능은 꺼져 있습니다.'),
          ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: _controller!,
      builder: (context, _) {
        final controller = _controller!;
        final phase = controller.phase;
        final label = controller.accountLabel;
        final code = controller.preparationCode;
        return Scaffold(
          appBar: AppBar(title: const Text('현재 계정 시험 준비')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  '이 단계는 현재 로그인 계정과 세션을 고정 합성 영수증 시험의 준비 후보로 기록합니다. '
                  '사진을 전송하지 않고, 금액을 예약하지 않으며, AI를 호출하지 않습니다.',
                ),
                const SizedBox(height: 16),
                if (label != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '현재 로그인 계정',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            label,
                            key: const ValueKey(
                              'receipt-pilot-current-account',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  '준비 코드는 최대 5분 동안만 유효합니다. 계정이나 로그인 상태가 바뀌거나 '
                  '앱을 벗어나면 화면의 코드를 지웁니다. '
                  '5분은 코드의 유효기간이며, 서버 준비 기록은 감사 목적으로 남을 수 있습니다.\n\n'
                  '전달 정보는 현재 앱 로그인 인증, 새 준비 식별값, 고정 시험 식별값·사진 해시와 명시적 동의뿐입니다.\n\n'
                  '운영자가 사용자가 확인한 정확한 코드와 계정을 대조해 별도로 승인해야 합니다. '
                  '준비 코드는 전송·지출 권한이 아니며, 이 단계가 시험을 자동 승인하지 않습니다.\n\n'
                  '이후 실제 합성 사진 전송과 최대 US\$0.60 비용 동의는 별도의 시험 화면에서 다시 확인합니다.',
                ),
                if (phase == ReceiptPilotPreparationPhase.ready &&
                    label != null) ...[
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: controller.consented,
                    onChanged: (value) =>
                        controller.confirmCurrentAccount(value ?? false),
                    title: const Text(
                      '위에 표시된 현재 계정과 지금의 로그인 세션으로 고정 합성 시험을 준비할 것을 확인합니다. '
                      '이 단계에서는 사진 전송·금액 예약·AI 호출이 없음을 확인했습니다.',
                    ),
                  ),
                  FilledButton(
                    onPressed: controller.canPrepare
                        ? () => unawaited(controller.prepare())
                        : null,
                    child: const Text('현재 계정으로 준비 요청'),
                  ),
                  if (!controller.cooldownComplete)
                    const Text('직전 준비 요청 후 30초가 지나야 새 준비를 요청할 수 있습니다.'),
                ],
                if (phase == ReceiptPilotPreparationPhase.preparing) ...[
                  const SizedBox(height: 24),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 12),
                  const Text('현재 계정의 준비 후보를 기록 중입니다. 자동 재시도하지 않습니다.'),
                ],
                if (code != null) ...[
                  const SizedBox(height: 24),
                  const Text(
                    '준비 코드 · 승인 권한 없음',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    code,
                    key: const ValueKey('receipt-pilot-preparation-code'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '이 코드를 운영자에게 직접 전달하고 위 현재 계정의 준비 후보임을 확인해 주세요. '
                    '운영자가 정확한 코드와 계정을 확인하기 전에는 유료 시험을 시작할 수 없습니다.',
                  ),
                ],
                if (controller.message != null) ...[
                  const SizedBox(height: 16),
                  Semantics(liveRegion: true, child: Text(controller.message!)),
                ],
                if ({
                  ReceiptPilotPreparationPhase.prepared,
                  ReceiptPilotPreparationPhase.failed,
                  ReceiptPilotPreparationPhase.unavailable,
                }.contains(phase)) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: controller.canStartNew
                        ? controller.startNewPreparation
                        : null,
                    child: const Text('현재 계정으로 새 준비 확인'),
                  ),
                  const Text(
                    '새 준비는 기존 화면의 코드를 지우고 현재 계정 확인과 동의부터 다시 시작합니다. 자동 요청하지 않습니다.',
                  ),
                ],
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('닫기'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
