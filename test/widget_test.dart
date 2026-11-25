import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/models.dart';
import 'package:take_care_refrigerator/src/pages/recipes_page.dart';
import 'package:take_care_refrigerator/src/providers.dart';

Ingredient ingredient(String name) => Ingredient(
  id: name,
  name: name,
  quantity: '1',
  expiryDate: DateTime(2030),
  storageType: '냉장',
  createdAt: DateTime(2026),
);

void main() {
  final recipe = Recipe(
    id: '1',
    name: '두부 요리',
    requiredIngredients: ['양파', '두부', ' 양파 '],
    likeCount: 0,
    createdAt: DateTime(2026),
  );

  testWidgets('card and detail agree and update when inventory changes', (
    tester,
  ) async {
    final inventory = StreamController<List<Ingredient>>();
    addTearDown(() async {
      // Unmount even after a failed assertion so a paused route subscription
      // cannot keep StreamController.close waiting indefinitely.
      await tester.pumpWidget(const SizedBox.shrink());
      await inventory.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ingredientsProvider.overrideWith((ref) => inventory.stream),
          userProfileProvider.overrideWith((ref) async => null),
          likedRecipeIdsProvider.overrideWith(
            (ref) => Stream.value(<String>{}),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: RecipeCard(recipe: recipe)),
        ),
      ),
    );
    expect(find.text('재료 확인 중'), findsOneWidget);
    expect(find.textContaining('보유 미확인:'), findsNothing);
    inventory.add([ingredient(' 양파 ')]);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2 재료 보유중'), findsOneWidget);
    expect(find.text('보유 미확인: 두부'), findsOneWidget);
    await tester.tap(find.text('두부 요리'));
    await tester.pumpAndSettle();
    expect(find.text('보유 미확인: 두부'), findsOneWidget);
    expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
    inventory.add([ingredient('양파'), ingredient('두부')]);
    await tester.pumpAndSettle();
    expect(find.text('재료 이름이 모두 일치 · 수량은 직접 확인해 주세요.'), findsOneWidget);
    expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('2 / 2 재료 보유중'), findsOneWidget);
  });

  testWidgets('inventory errors are not shown as missing ingredients', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          ingredientsProvider.overrideWith(
            (ref) => Stream<List<Ingredient>>.error(StateError('offline')),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: RecipeCard(recipe: recipe)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('재료 정보를 불러올 수 없습니다.'), findsOneWidget);
    expect(find.textContaining('보유 미확인:'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
