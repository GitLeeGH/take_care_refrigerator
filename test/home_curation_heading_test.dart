import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/models.dart';
import 'package:take_care_refrigerator/src/providers.dart';
import 'package:take_care_refrigerator/src/theme.dart';
import 'package:take_care_refrigerator/src/widgets/home_curation_section.dart';

void main() {
  testWidgets('curation uses a distinct section heading and neutral subtitle', (
    tester,
  ) async {
    final recipe = Recipe(
      id: 'a',
      name: '두부 요리',
      requiredIngredients: ['두부'],
      likeCount: 0,
      createdAt: DateTime(2026),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recommendedIdsProvider.overrideWith((ref) async => ['a']),
          allRecipesListProvider.overrideWith((ref) async => [recipe]),
          ingredientsProvider.overrideWith(
            (ref) => Stream.value(<Ingredient>[]),
          ),
          usableIngredientNamesProvider.overrideWithValue(['두부']),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: HomeCurationSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('이런 메뉴 어때요?'), findsOneWidget);
    expect(find.text('오늘 뭐 먹지?'), findsNothing);
    expect(
      tester.widget<Text>(find.text('내 재료·취향과 식사 시간으로 고른 추천')).style?.color,
      mediumGray,
    );
    expect(find.text('두부 요리'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
