import 'package:flutter/material.dart';
import '../ingredient_matching.dart';
import '../theme.dart';

/// Explains name matching without claiming quantities, freshness or safety.
class PantryMatchPanel extends StatelessWidget {
  const PantryMatchPanel({
    super.key,
    required this.availability,
    this.holdReason,
  });
  final IngredientAvailability availability;
  final String? holdReason;

  @override
  Widget build(BuildContext context) {
    if (holdReason != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '추천을 보류한 항목입니다. 등록된 재료 이름이 일치해도 조리 가능 여부는 확인되지 않았어요.',
          style: const TextStyle(color: warningInk),
        ),
      );
    }
    final empty = availability.requiredIngredients.isEmpty;
    final summary = empty
        ? '등록된 재료 정보가 없습니다.'
        : availability.canMake
        ? '재료 이름이 모두 일치 · 수량은 직접 확인해 주세요.'
        : '보유 미확인: ${availability.missingIngredients.join(', ')}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: availability.canMake ? softGreen : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (availability.ownedIngredients.isNotEmpty) ...[
            Text(
              '보유 재료: ${availability.ownedIngredients.join(', ')}',
              style: const TextStyle(
                color: primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (availability.uncertainIngredients.isNotEmpty)
            Text('이름 확인 필요: ${availability.uncertainIngredients.join(', ')}'),
          const Text('이름 기준 비교입니다. 부족한 분량과 재료 상태는 직접 확인해 주세요.'),
          const SizedBox(height: 6),
          Text(
            summary,
            style: TextStyle(
              color: empty || availability.canMake ? darkGray : warningInk,
            ),
          ),
        ],
      ),
    );
  }
}
