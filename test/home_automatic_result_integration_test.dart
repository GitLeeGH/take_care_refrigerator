import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:take_care_refrigerator/src/services/inventory_day.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/models.dart';
import 'package:take_care_refrigerator/src/providers.dart';
import 'package:take_care_refrigerator/src/services/curation_preferences.dart';
import 'package:take_care_refrigerator/src/services/home_automatic_curation.dart';
import 'package:take_care_refrigerator/src/services/meal_assistant.dart';
import 'package:take_care_refrigerator/src/services/meal_assistant_gateway.dart';
import 'package:take_care_refrigerator/src/widgets/home_curation_section.dart';

class Identity implements CurationIdentity {
  @override
  String? get account => 'owner';
  @override
  Stream<void> get changes => const Stream.empty();
}

class Attempts implements HomeAutomaticAttemptStore {
  @override
  Future<bool> reserve(String owner, String revision, DateTime now) async =>
      true;
}

class Gateway implements MealAssistantGateway, AutomaticDispatchGateway {
  int calls = 0, gets = 0;
  final pending = Completer<void>();
  Map? sent;
  String? failCode;
  @override
  bool get enabled => true;
  @override
  bool supports(MealAssistantTask task) => true;
  late final delegate = HttpMealAssistantGateway(
    endpoint: Uri.parse(
      'https://brghwnwkfhbhamrrrqnr.supabase.co/functions/v1/cooking-assist',
    ),
    publishableKey: 'synthetic',
    accessToken: () => 'synthetic',
    clientFactory: () => MockClient((r) async {
      if (r.method == 'GET') {
        gets++;
        return http.Response(
          jsonEncode({
            'ready': true,
            'monthly_limit_usd': 10,
            'budget_scope': 'app-ai-shared-v1',
            'automatic_consent_version': automaticMealConsentVersion,
            'manual_meal_period_version': 'meal-period-v1',
            'manual_meal_period_consent_version':
                manualMealPeriodConsentVersion,
            'automatic_meal_period_version': 'meal-period-v1',
            'automatic_meal_period_consent_version':
                automaticMealPeriodConsentVersion,
          }),
          200,
        );
      }
      calls++;
      if (failCode != null)
        return http.Response(jsonEncode({'error': failCode}), 409);
      sent = jsonDecode(r.body) as Map;
      await pending.future;
      return http.Response(
        jsonEncode({
          'request_id': sent!['request_id'],
          'input_revision': sent!['input_revision'],
          'owner_id': 'owner',
          'needs_review': true,
          'result': {
            'menus': [
              {'id': 'b', 'reason': '두부로 간편하게 만들 수 있어요.'},
            ],
            'answer': '',
            'steps': [],
            'warnings': [],
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
  @override
  Future<MealAssistantResult> ask(
    MealAssistantConsent c, {
    required bool Function() isCurrent,
  }) => delegate.ask(c, isCurrent: isCurrent);
  @override
  Future<MealAssistantResult> askAutomatic(
    MealAssistantConsent c, {
    required bool Function() isCurrent,
    required Future<bool> Function() beforeDispatch,
  }) => delegate.askAutomatic(
    c,
    isCurrent: isCurrent,
    beforeDispatch: beforeDispatch,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'automatic success renders AI result and reason in home without asking again',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
      final gateway = Gateway();
      Widget app() => ProviderScope(
        overrides: [
          inventoryClockProvider.overrideWithValue(
            () => DateTime(2026, 11, 14, 12),
          ),
          curationIdentityProvider.overrideWithValue(Identity()),
          homeAutomaticAttemptStoreProvider.overrideWithValue(
            PreferencesHomeAutomaticAttemptStore(),
          ),
          mealAssistantGatewayProvider.overrideWithValue(gateway),
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
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('오늘 점심, 이런 메뉴 어때요?'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('AI 추천 허용')).dy,
        lessThan(tester.getTopLeft(find.text('두부 볶음')).dy),
      );
      await tester.ensureVisible(find.text('AI 추천 허용'));
      await tester.tap(find.text('AI 추천 허용'));
      await tester.pumpAndSettle();
      expect(find.text('보내는 정보와 이용 안내'), findsOneWidget);
      expect(find.textContaining('"task"'), findsNothing);
      await tester.tap(find.text('동의하고 추천 켜기'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('점심 메뉴를 고르고 있어요…'), findsOneWidget);
      expect(gateway.calls, 1);
      if (homeMealPeriodAiEnabled) {
        expect(gateway.sent!['meal_period'], 'lunch');
        expect(
          gateway.sent!['consent_version'],
          automaticMealPeriodConsentVersion,
        );
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      gateway.pending.complete();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(gateway.calls, 1);
      expect(find.text('최근 AI 추천 · 6시간 이내 결과'), findsOneWidget);
      expect(find.text('두부로 간편하게 만들 수 있어요.'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(gateway.calls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      // App restart keeps cached result but requires a new explicit grant.
      await tester.tap(find.text('AI 추천 허용'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('동의하고 추천 켜기'));
      await tester.pumpAndSettle();
      expect(gateway.calls, 1);
      expect(find.text('두부로 간편하게 만들 수 있어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
