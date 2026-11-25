import 'package:flutter/material.dart';
import '../services/expiry_compatibility.dart';

/// Offline migration preview only; no live route or save control uses this yet.
class ExpiryCompatibilityCard extends StatelessWidget {
  const ExpiryCompatibilityCard({super.key, required this.draft});
  final IngredientExpiryDraft draft;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            draft.actualDate == null
                ? '등록된 소비기한: 모름'
                : '등록된 소비기한: ${calendarDateText(draft.actualDate!)}',
          ),
          const SizedBox(height: 12),
          Text(
            draft.referenceDate == null
                ? '참고 권장일: 없음'
                : '참고 권장일: ${calendarDateText(draft.referenceDate!)}',
          ),
          const SizedBox(height: 8),
          const Text('참고 권장일은 실제 소비기한이나 안전 보증이 아니에요.'),
          if (draft.actualDate == null)
            const Text(
              '도입 시 주의: 기한 미정 재료는 새 버전에서만 표시됩니다. 구형 앱이나 업데이트하지 않은 다른 기기에서는 보이지 않습니다.',
            ),
          if (draft.actualDate == null &&
              !unknownExpiryRegistrationEnabled) ...[
            const SizedBox(height: 12),
            const Text('미리보기: 소비기한 모름 상태의 등록은 아직 지원하지 않아요.'),
          ],
        ],
      ),
    ),
  );
}
