import 'food_catalog_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/calendar_day.dart';
import '../services/inventory_day.dart';
import '../theme.dart';
import 'storage_reference_panel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import 'ingredient_photo.dart';
import 'ingredient_thumbnail.dart';

enum IngredientDetailAction { edit, delete }

class IngredientDetailDialog extends ConsumerWidget {
  const IngredientDetailDialog({super.key, required this.ingredient});
  final Ingredient ingredient;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(inventoryDayProvider);
    final day = DateTime(
      ingredient.expiryDate.year,
      ingredient.expiryDate.month,
      ingredient.expiryDate.day,
    );
    final left = calendarDayDifference(day, now);
    final status = left < 0
        ? '${-left}일 경과'
        : left == 0
        ? '오늘까지'
        : '$left일 남음';
    return AlertDialog(
      semanticLabel: '${ingredient.name} 재료 상세',
      scrollable: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Text(ingredient.name),
      content: SizedBox(
        width: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 160,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: softGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: IngredientPhoto(
                  path: ingredient.imagePath,
                  fallback: IngredientThumbnail(
                    name: ingredient.name,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '수량  ${ingredient.quantity}',
              style: const TextStyle(fontSize: 17),
            ),
            const SizedBox(height: 12),
            Text(
              '보관 장소  ${{'refrigerated': '냉장', 'frozen': '냉동', 'ambient': '실온'}[ingredient.storageType] ?? ingredient.storageType}',
              style: const TextStyle(fontSize: 17),
            ),
            const SizedBox(height: 12),
            Text(
              '기록된 날짜  ${DateFormat('yyyy.MM.dd').format(day)}',
              style: const TextStyle(fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              status,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: left < 0
                    ? const Color(0xFFA43A2C)
                    : const Color(0xFF245943),
              ),
            ),
            const SizedBox(height: 12),
            FoodCatalogButton(name: ingredient.name),
            StorageReferencePanel(ingredient: ingredient),
            const Text(
              '포장지의 소비기한과 보관 조건이 우선입니다.\n등록한 날짜만으로 식품 안전을 판단할 수 없습니다.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF555E55),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      actionsOverflowButtonSpacing: 4,
      actions: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () =>
                  Navigator.pop(context, IngredientDetailAction.delete),
              child: const Text(
                '삭제',
                style: TextStyle(color: Color(0xFFA43A2C)),
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () =>
                  Navigator.pop(context, IngredientDetailAction.edit),
              child: const Text('수정'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        ),
      ],
    );
  }
}
