import 'package:flutter/material.dart';
import '../models.dart';
import '../services/food_catalog.dart';
import '../services/ingredient_photos.dart';
import '../services/inventory_quantity.dart';
import '../theme.dart';
import 'ingredient_thumbnail.dart';

/// Counts registered ingredient entries, never guesses their physical quantity.
int fridgeCategory(Ingredient item) {
  final category = findFood(item.name)?.category;
  if (category == '채소' || category == '건채소') return 0;
  if (category == '육류') return 1;
  if (const [
    '계란',
    '달걀',
    '우유',
    '치즈',
    '버터',
    '요거트',
    '요구르트',
    '생크림',
    '모차렐라',
    '체더치즈',
  ].contains(item.name.trim()))
    return 2;
  return 3;
}

class FridgeInventoryVisual extends StatelessWidget {
  const FridgeInventoryVisual({
    super.key,
    required this.items,
    required this.onTap,
  });
  final List<Ingredient> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stocked = items
        .where((i) => !isExplicitlyEmptyQuantity(i.quantity))
        .toList();
    final counts = List<int>.filled(4, 0);
    for (final item in stocked) {
      counts[fridgeCategory(item)]++;
    }
    final names = stocked.map((i) => i.name).toSet().take(5).toList();
    const labels = ['채소', '육류', '계란·유제품', '기타'];
    final fridge = Semantics(
      label: '내 냉장고 열기',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('fridge-open'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: ExcludeSemantics(
            child: _FridgeShelves(
              names: names
                  .where((name) => ingredientReferencePhotoFor(name) != null)
                  .toList(),
            ),
          ),
        ),
      ),
    );
    final categories = LayoutBuilder(
      builder: (context, c) => Wrap(
        spacing: 12,
        runSpacing: 20,
        children: [
          for (var i = 0; i < 4; i++)
            SizedBox(
              width: (c.maxWidth - 12) / 2,
              child: Semantics(
                label: '${labels[i]} ${counts[i]}개',
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        [
                          Icons.eco_outlined,
                          Icons.restaurant_outlined,
                          Icons.egg_outlined,
                          Icons.inventory_2_outlined,
                        ][i],
                        color: primaryGreen,
                        size: 22,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        labels[i],
                        style: const TextStyle(fontSize: 12, color: mediumGray),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${counts[i]}개',
                        key: ValueKey('fridge-category-$i'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '총 ${stocked.length}개 재료',
          style: const TextStyle(
            color: mediumGray,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, c) {
            final stacked =
                MediaQuery.textScalerOf(context).scale(14) > 20 ||
                c.maxWidth < 260;
            if (stacked)
              return Column(
                children: [
                  SizedBox(width: 112, child: fridge),
                  const SizedBox(height: 20),
                  categories,
                ],
              );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 100, child: fridge),
                const SizedBox(width: 24),
                Expanded(child: categories),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: lightGray,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '주요 재료',
                style: TextStyle(
                  fontSize: 13,
                  color: mediumGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              if (names.isEmpty)
                const Text(
                  '등록한 재료가 여기에 보여요.',
                  style: TextStyle(fontSize: 13, color: mediumGray),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in names)
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        key: ValueKey('fridge-ingredient-$name'),
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (ingredientReferencePhotoFor(name) !=
                                  null) ...[
                                IngredientThumbnail(
                                  name: name,
                                  width: 32,
                                  height: 32,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Decorative shelf view uses only the names in the current inventory.
class _FridgeShelves extends StatelessWidget {
  const _FridgeShelves({required this.names});
  final List<String> names;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '등록된 재료의 냉장고 참고 이미지',
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 13, 6, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFC6CDD3), width: 3),
          gradient: const LinearGradient(
            colors: [Color(0xFFF7F9FA), Color(0xFFDDE4E9), Color(0xFFF7F9FA)],
          ),
        ),
        child: Column(
          children: [
            for (var shelf = 0; shelf < 3; shelf++)
              Container(
                height: 54,
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.fromLTRB(2, 4, 2, 5),
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F9FA),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFADB9C3), width: 3),
                  ),
                ),
                child: Row(
                  children: [
                    for (
                      var index = shelf * 2;
                      index < shelf * 2 + 2 && index < names.length;
                      index++
                    )
                      Expanded(
                        child: IngredientThumbnail(
                          name: names[index],
                          width: 32,
                          height: 40,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
