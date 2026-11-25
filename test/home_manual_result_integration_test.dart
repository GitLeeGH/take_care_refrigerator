import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:take_care_refrigerator/src/models.dart';
import 'package:take_care_refrigerator/src/providers.dart';
import 'package:take_care_refrigerator/src/services/curation_preferences.dart';
import 'package:take_care_refrigerator/src/services/inventory_day.dart';
import 'package:take_care_refrigerator/src/services/meal_assistant.dart';
import 'package:take_care_refrigerator/src/services/meal_assistant_gateway.dart';
import 'package:take_care_refrigerator/src/widgets/home_curation_section.dart';
import 'home_automatic_result_integration_test.dart' as f;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'manual home never sends until tap; repeat taps are new one-shot requests',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final g = f.Gateway();
      final recipes = [
        for (final id in ['a', 'b'])
          Recipe(
            id: id,
            name: id == 'a' ? '두부 볶음' : '두부 구이',
            requiredIngredients: ['두부'],
            likeCount: 0,
            createdAt: DateTime(2026),
          ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryClockProvider.overrideWithValue(
              () => DateTime(2026, 11, 14, 12),
            ),
            curationIdentityProvider.overrideWithValue(f.Identity()),
            mealAssistantGatewayProvider.overrideWithValue(g),
            recommendedIdsProvider.overrideWith((ref) async => ['a', 'b']),
            allRecipesListProvider.overrideWith((ref) async => recipes),
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
      await tester.pump(const Duration(minutes: 1));
      expect(g.calls, 0);
      expect(g.gets, 0);
      expect(find.text('동의하고 AI 추천받기'), findsOneWidget);
      await tester.tap(find.text('동의하고 AI 추천받기'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(g.calls, 1);
      expect(g.sent!['consent_version'], manualMealPeriodConsentVersion);
      expect(g.sent!['meal_period'], 'lunch');
      final first = g.sent!['request_id'];
      final revision = g.sent!['input_revision'];
      await tester.tap(find.text('점심 메뉴 고르는 중…'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(g.calls, 1);
      g.pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('두부로 간편하게 만들 수 있어요.'), findsOneWidget);
      await tester.pump(const Duration(minutes: 1));
      expect(g.calls, 1);
      await tester.tap(find.text('다시 추천받기'));
      await tester.pumpAndSettle();
      expect(g.calls, 2);
      expect(g.sent!['request_id'], isNot(first));
      expect(g.sent!['input_revision'], revision);
      g.failCode = 'rate_limited';
      await tester.tap(find.text('다시 추천받기'));
      await tester.pumpAndSettle();
      expect(g.calls, 3);
      expect(find.textContaining('오늘 AI 이용 한도 10회'), findsOneWidget);
      await tester.pump(const Duration(minutes: 10));
      expect(g.calls, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
