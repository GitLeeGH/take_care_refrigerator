import 'package:flutter/material.dart';

class ReminderReadiness extends StatelessWidget {
  const ReminderReadiness({
    super.key,
    required this.sessionUsable,
    required this.loading,
    required this.failed,
    required this.hasData,
    required this.enabled,
    required this.onRetry,
  });
  final bool sessionUsable, loading, failed, hasData, enabled;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final message = !sessionUsable
        ? '로그인 상태를 확인할 수 없거나 세션이 만료됐습니다. 마이페이지에서 로그인 상태를 확인해 주세요. 새 알림은 예약하지 않습니다.'
        : loading
        ? '최신 재고를 확인하고 있습니다. 확인이 끝나기 전에는 새 알림을 예약하지 않습니다.'
        : failed || !hasData
        ? '네트워크 연결 또는 재고 갱신에 문제가 있어 최신 재고를 확인하지 못했습니다. 연결을 확인한 뒤 다시 불러와 주세요.'
        : !enabled
        ? '앱 안에서 기한 안내 받기를 켠 뒤 1회 예약을 요청할 수 있습니다.'
        : null;
    if (message == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(liveRegion: true, child: Text(message)),
        if (sessionUsable && !loading && (failed || !hasData))
          TextButton(onPressed: onRetry, child: const Text('재고 다시 불러오기')),
        const Text(
          '다시 불러오기는 재고 조회만 합니다. 알림은 자동 예약되지 않습니다. 기존 예약을 중단하려면 아래 예약 취소를 눌러 주세요.',
        ),
      ],
    );
  }
}
