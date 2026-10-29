import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/ingredient_matching.dart';
import 'package:take_care_refrigerator/src/models.dart';

void main() {
  test('normalizes whitespace and case without matching parts of names', () {
    final result = IngredientAvailability(
      [' Green   Onion ', '양파', '간장', '소금'],
      ['green onion', '양파가루', '진간장', '소금 1큰술'],
    );
    expect(result.ownedIngredients, ['Green   Onion']);
    expect(result.missingIngredients, ['양파', '간장', '소금']);
    expect(result.canMake, isFalse);
  });

  test('ignores blank names and counts each normalized requirement once', () {
    final result = IngredientAvailability(
      [' ', '양파', ' 양파 ', 'SALT', 'salt'],
      ['양파', '양파', ' salt ', ''],
    );
    expect(result.requiredIngredients, ['양파', 'SALT']);
    expect(result.ownedIngredients.length, 2);
    expect(result.missingIngredients, isEmpty);
    expect(result.canMake, isTrue);
  });

  test(
    'empty requirements are unknown, empty inventory has actual missing names',
    () {
      expect(IngredientAvailability(['', ' '], ['']).canMake, isFalse);
      final result = IngredientAvailability(['두부', '달걀'], []);
      expect(result.ownedIngredients, isEmpty);
      expect(result.missingIngredients, ['두부', '달걀']);
      expect(result.canMake, isFalse);
    },
  );

  test('does not infer quantities, preparation or substitutions', () {
    final result = IngredientAvailability(
      ['소금 1큰술', '다진 마늘', '우유', '고추장'],
      ['소금', '마늘', '두유', '고추장소스'],
    );
    expect(result.ownedIngredients, isEmpty);
    expect(result.missingIngredients.length, 4);
  });

  test(
    'recommended model contains real missing names and consistent counts',
    () {
      final recipe = Recipe(
        id: '1',
        name: '요리',
        requiredIngredients: ['양파', '두부', ' 두부 '],
        likeCount: 0,
        createdAt: DateTime(2026),
      );
      final result = RecommendedRecipe.fromInventory(recipe, [' 양파 ']);
      expect(result.ownedIngredientsCount, 1);
      expect(result.requiredIngredientsCount, 2);
      expect(result.missingIngredients, ['두부']);
    },
  );
}
