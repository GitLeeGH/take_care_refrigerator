import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models.dart';
import '../providers.dart';
import '../services/storage_reference.dart';
import 'storage_guidance_dialog.dart';

/// Kept separate from the recorded expiry and hidden until remote rollout.
class StorageReferencePanel extends ConsumerWidget {
  const StorageReferencePanel({super.key, required this.ingredient});
  final Ingredient ingredient;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(storageReferencesEnabledProvider)) {
      return StorageGuidanceButton(
        name: ingredient.name,
        storageType: ingredient.storageType,
      );
    }
    final state = ref.watch(storedStorageReferencesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const Text(
          '참고 권장일 · 소비기한과 별개',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        state.when(
          skipLoadingOnRefresh: false,
          data: (rows) {
            final matches = rows.where(
              (row) => row.ingredientId == ingredient.id,
            );
            if (matches.isEmpty) {
              return const Text('저장한 참고일이 없습니다. 기존 등록 날짜는 그대로 유지됩니다.');
            }
            final saved = matches.first;
            final active =
                saved.active && ingredient.storageType == 'refrigerated';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '먼저 먹기 권장일(참고): ${referenceDateText(saved.remindOn)}${saved.manuallyAdjusted ? ' · 직접 수정' : ''}',
                ),
                Text(
                  '구매일 ${referenceDateText(saved.purchasedOn)} · 자료 기준일 ${referenceDateText(saved.suggestedOn)}',
                ),
                Text('근거: ${saved.guideLabel} / ${saved.catalogVersion}'),
                for (final source in saved.sourceUrls)
                  Text(source, softWrap: true),
                if (!active) const Text('보관 조건 재확인이 필요해 참고 알림이 중지되었습니다.'),
                const Text('실제 소비기한이나 안전 보증이 아닙니다. 제품 표시와 보관 지시를 우선하세요.'),
              ],
            );
          },
          loading: () => const Text('참고일 확인 중…'),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(storedStorageReferencesProvider),
            child: const Text('참고일을 불러오지 못했습니다. 다시 확인'),
          ),
        ),
        StorageGuidanceButton(
          name: ingredient.name,
          storageType: ingredient.storageType,
          ingredientId: ingredient.id,
          onSave: (draft) async {
            // Only the separate reference table is written; never Ingredient.
            await ref.read(storageReferenceGatewayProvider).save(draft);
            ref.invalidate(storedStorageReferencesProvider);
          },
        ),
      ],
    );
  }
}
