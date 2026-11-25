import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/receipt_synthetic_pilot.dart';

/// This launcher has no dependency on auth, storage, image or gateway while OFF.
class ReceiptSyntheticPilotLauncher extends ConsumerWidget {
  const ReceiptSyntheticPilotLauncher({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(receiptSyntheticPilotEnabledProvider)) {
      return const SizedBox.shrink();
    }
    return Card(
      child: ListTile(
        leading: const Icon(Icons.science_outlined),
        title: const Text('합성 영수증 1회 시험'),
        subtitle: const Text('개발용 · 고정 합성 사진만 사용'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ReceiptSyntheticPilotPage(),
          ),
        ),
      ),
    );
  }
}

class ReceiptSyntheticPilotPage extends ConsumerStatefulWidget {
  const ReceiptSyntheticPilotPage({super.key});
  @override
  ConsumerState<ReceiptSyntheticPilotPage> createState() =>
      _ReceiptSyntheticPilotPageState();
}

class _ReceiptSyntheticPilotPageState
    extends ConsumerState<ReceiptSyntheticPilotPage>
    with WidgetsBindingObserver {
  ReceiptSyntheticPilotController? _controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(receiptSyntheticPilotEnabledProvider)) {
      _controller = ref.read(receiptSyntheticPilotControllerProvider);
      scheduleMicrotask(() {
        if (mounted) unawaited(_controller!.initialize());
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _controller?.closeReview();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.closeReview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(receiptSyntheticPilotEnabledProvider) ||
        _controller == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('합성 영수증 시험')),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('합성 영수증 시험은 꺼져 있습니다.'),
          ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: _controller!,
      builder: (context, _) {
        final controller = _controller!;
        final phase = controller.phase;
        final bytes = controller.previewBytes;
        final busy = {
          ReceiptPilotPhase.loading,
          ReceiptPilotPhase.checking,
          ReceiptPilotPhase.committing,
          ReceiptPilotPhase.sending,
        }.contains(phase);
        return Scaffold(
          appBar: AppBar(title: const Text('합성 영수증 1회 시험')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('고정 합성 사진만 사용합니다. 카메라·앨범·실제 영수증을 선택하는 기능은 없습니다.'),
                if (bytes != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 360,
                    child: InteractiveViewer(
                      maxScale: 6,
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        semanticLabel: '가상 영수증. 우유 2개, 두부 1개, 사과 1개. 실제 구매 아님.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '받는 곳: 앱 서버(Supabase)를 거쳐 OpenAI\n'
                    '전달 정보: 위 고정 합성 사진 1장. 실제 구매·개인정보 없음\n'
                    '목적: gpt-6-luna의 영수증 품목 분석 시험\n'
                    '비용: 기존 API 사용/크레딧 결제로 1회 최대 US\$0.60. '
                    '공유 월 US\$10 한도 안에서 처리하며 기존 예약 금액은 유지됩니다.\n'
                    '보관: OpenAI API 데이터 정책에 따라 보안·오남용 감시 목적 등의 보관이 발생할 수 있습니다.\n'
                    '중복 방지: 전송 시도 후 다시 보내지 않습니다. 응답을 못 받아도 비용이 발생했을 수 있습니다.\n'
                    '결과는 시험 화면에서만 확인하며 식재료에 저장하지 않습니다.',
                  ),
                ],
                const SizedBox(height: 20),
                if (phase == ReceiptPilotPhase.idle)
                  FilledButton(
                    onPressed: () => unawaited(controller.prepare()),
                    child: const Text('로그인된 시험 준비 확인'),
                  ),
                if (phase == ReceiptPilotPhase.ready) ...[
                  const Text(
                    '서버가 현재 로그인 상태와 이 합성 시험의 준비를 확인했습니다. 제한 시간 안에 전송할 수 있습니다.',
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: controller.consented,
                    onChanged: (value) => controller.confirm(value ?? false),
                    title: const Text(
                      '위 고정 합성 사진의 OpenAI 전송과 1회 최대 US\$0.60 비용을 확인하고 동의합니다.',
                    ),
                  ),
                  FilledButton(
                    onPressed: controller.canSend
                        ? () => unawaited(controller.submit())
                        : null,
                    child: const Text('합성 사진 1회 전송'),
                  ),
                ],
                if (busy) ...[
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 12),
                  Text(switch (phase) {
                    ReceiptPilotPhase.checking =>
                      '시험 준비만 확인 중입니다. 사진은 아직 보내지 않았습니다.',
                    ReceiptPilotPhase.committing => '중복 방지 상태를 저장 중입니다.',
                    ReceiptPilotPhase.sending =>
                      '합성 사진을 한 번 전송했습니다. 자동 재시도하지 않습니다.',
                    _ => '로컬 시험 상태를 확인 중입니다.',
                  }),
                ],
                if (controller.message != null) ...[
                  const SizedBox(height: 16),
                  Semantics(liveRegion: true, child: Text(controller.message!)),
                ],
                if (phase == ReceiptPilotPhase.succeeded &&
                    controller.result != null) ...[
                  const SizedBox(height: 20),
                  const Text(
                    '시험 결과 · 저장하지 않음',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (controller.result!.review.isEmpty)
                    const Text('분석된 품목 후보가 없습니다.'),
                  for (final item in controller.result!.review)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.text),
                      subtitle: Text(item.reason),
                    ),
                ],
                const SizedBox(height: 20),
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
