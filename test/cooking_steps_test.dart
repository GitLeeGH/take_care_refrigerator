import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/models.dart';
import 'package:take_care_refrigerator/src/pages/recipe_detail_page.dart';
import 'package:take_care_refrigerator/src/services/cooking_steps.dart';

void main() {
  test('only explicit saved instructions become steps', () {
    expect(
      savedCookingSteps(
        '## 조리 방법\n1. 씻기\n2. 썰기\n## 재료\n1. 양파',
        unverified: false,
      ),
      ['씻기', '썰기'],
    );
    expect(savedCookingSteps('1. 씻기\n2. 썰기', unverified: true), isEmpty);
    expect(
      savedCookingSteps('[확인된 재료와 분량]\n1. 돼지고기 600g', unverified: false),
      isEmpty,
    );
    expect(savedCookingSteps('양파를 썰고 볶는다.', unverified: false), isEmpty);
    expect(savedCookingSteps('1. 씻기\n3. 썰기', unverified: false), isEmpty);
  });
  testWidgets(
    'touch steps preserve order, completion and back at 320px with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final recipe = Recipe(
        id: 'test',
        name: '테스트 전용 순서',
        description: '## 조리 방법\n1. 재료를 씻습니다.\n2. 재료를 썹니다.',
        requiredIngredients: [],
        likeCount: 0,
        createdAt: DateTime(2026),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: CookingPage(recipe: recipe),
        ),
      );
      expect(find.text('1 / 2 단계'), findsOneWidget);
      await tester.tap(find.text('다음'));
      await tester.pump();
      expect(find.text('2 / 2 단계'), findsOneWidget);
      await tester.tap(find.text('이전'));
      await tester.pump();
      expect(find.text('1 / 2 단계'), findsOneWidget);
      await tester.tap(find.text('다음'));
      await tester.pump();
      await tester.tap(find.text('완료'));
      await tester.pump();
      expect(find.text('요리 완료'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('unknown steps show empty state without invented controls', (
    tester,
  ) async {
    final recipe = Recipe(
      id: 'test',
      name: '미확인',
      description: '[아직 확인되지 않은 정보]\n조리 순서 미확인',
      requiredIngredients: [],
      likeCount: 0,
      createdAt: DateTime(2026),
    );
    await tester.pumpWidget(MaterialApp(home: CookingPage(recipe: recipe)));
    expect(find.text('아직 조리 단계가 없습니다'), findsOneWidget);
    expect(find.text('다음'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
