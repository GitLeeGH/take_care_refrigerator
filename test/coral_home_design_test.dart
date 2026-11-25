import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/models.dart';
import 'package:take_care_refrigerator/src/pages/home_page.dart';
import 'package:take_care_refrigerator/src/providers.dart';
import 'package:take_care_refrigerator/src/services/inventory_day.dart';
import 'package:take_care_refrigerator/src/services/meal_history.dart';
import 'package:take_care_refrigerator/src/services/recipe_example_photos.dart';
import 'package:take_care_refrigerator/src/services/recipe_photos.dart';
import 'package:take_care_refrigerator/src/theme.dart';
import 'package:take_care_refrigerator/src/widgets/app_navigation.dart';
import 'package:take_care_refrigerator/src/widgets/registration_hero.dart';
import 'support/local_preferences_stub.dart';

void main() {
  stubLocalPreferences();
  for (final scale in [1.0, 1.6, 2.0]) {
    testWidgets('Coral Table brand, registration, photos and inventory at $scale', (
      tester,
    ) async {
      const capture = bool.fromEnvironment('CORAL_CAPTURE');
      const originalPhotos = bool.fromEnvironment('CORAL_SOURCE_PHOTOS');
      tester.view.physicalSize = Size(scale == 1 ? 360 : 320, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      tester.view.padding = const FakeViewPadding(bottom: 24);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      if (capture) {
        if (const String.fromEnvironment('CAPTURE_KOREAN_FONT').isEmpty ||
            const String.fromEnvironment(
              'CAPTURE_MATERIAL_ICONS_FONT',
            ).isEmpty) {
          throw StateError(
            'Screenshot capture requires both font path defines.',
          );
        }
        await tester.runAsync(() async {
          final font = ByteData.sublistView(
            await File(
              const String.fromEnvironment('CAPTURE_KOREAN_FONT'),
            ).readAsBytes(),
          );
          for (final family in ['Roboto', 'Ahem']) {
            await (FontLoader(family)..addFont(Future.value(font))).load();
          }
          await (FontLoader('MaterialIcons')..addFont(
                Future.value(
                  ByteData.sublistView(
                    await File(
                      const String.fromEnvironment(
                        'CAPTURE_MATERIAL_ICONS_FONT',
                      ),
                    ).readAsBytes(),
                  ),
                ),
              ))
              .load();
        });
      }
      final day = DateTime(2026, 11, 12);
      final recipes = originalPhotos
          ? [
              for (final photo in sourceRecordRecipePhotos)
                Recipe(
                  id: 'source-${photo.sourceId}',
                  name: photo.name,
                  blogUrl: RecipePhoto.sourceUrl,
                  description:
                      '<!-- mfds-import:v1;batch=visual-fixture;id=${photo.sourceId}; -->',
                  requiredIngredients: photo.sourceId == '700'
                      ? ['달걀', '쑥', '호두', '당근', '소금']
                      : ['아욱', '된장', '마늘', '소금'],
                  likeCount: 0,
                  createdAt: day,
                ),
            ]
          : [
              Recipe(
                id: 'banana',
                name: '바나나 스무디',
                requiredIngredients: ['바나나', '우유'],
                description: '바나나와 우유를 곱게 갈아요.',
                likeCount: 0,
                createdAt: day,
              ),
              Recipe(
                id: 'pumpkin',
                name: '단호박 수프',
                requiredIngredients: ['단호박', '우유'],
                description: '익힌 단호박을 우유와 함께 곱게 갈아요.',
                likeCount: 0,
                createdAt: day,
              ),
            ];
      final items = [
        for (final pair
            in originalPhotos
                ? [('당근', 0), ('소금', 2), ('마늘', 3)]
                : [('바나나', 0), ('우유', 2), ('당근', 3)])
          Ingredient(
            id: pair.$1,
            name: pair.$1,
            quantity: '1개',
            expiryDate: day.add(Duration(days: pair.$2)),
            storageType: 'refrigerated',
            createdAt: day,
          ),
      ];
      final boundary = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            testCurationIdentityOverride,
            inventoryClockProvider.overrideWithValue(() => day),
            ingredientsProvider.overrideWith((ref) => Stream.value(items)),
            allRecipesListProvider.overrideWith((ref) async => recipes),
            recommendedIdsProvider.overrideWith(
              (ref) async => recipes.map((r) => r.id).toList(),
            ),
            mealRecommendationHistoryProvider.overrideWith(
              (ref) => const MealRecommendationHistory(),
            ),
            userProfileProvider.overrideWith((ref) async => null),
            likedRecipeIdsProvider.overrideWith(
              (ref) => Stream.value(<String>{}),
            ),
          ],
          child: MaterialApp(
            theme: appTheme.copyWith(
              appBarTheme: appTheme.appBarTheme.copyWith(
                titleTextStyle: appTheme.appBarTheme.titleTextStyle!.copyWith(
                  fontFamily: capture ? 'Roboto' : null,
                ),
              ),
            ),
            home: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                body: Column(
                  children: [
                    const Material(
                      color: coralSurface,
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(
                          '미리보기 · 예시 데이터',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    Expanded(
                      child: DashboardPage(
                        onInventory: () {},
                        onRecipes: () {},
                        onNotifications: () {},
                      ),
                    ),
                  ],
                ),
                bottomNavigationBar: AppNavigation(
                  index: 0,
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('냉장고를 부탁해'), findsOneWidget);
      expect(find.text('내 냉장고').hitTestable(), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      await tester.runAsync(() async {
        for (final recipe in recipes) {
          final asset =
              recipePhotoFor(recipe)?.assetPath ??
              recipeExamplePhotoFor(recipe)!.assetPath;
          await precacheImage(
            ResizeImage(AssetImage(asset), width: 768),
            tester.element(find.byType(DashboardPage)),
          );
        }
      });
      await tester.pumpAndSettle();
      Future<void> save(String suffix) async {
        if (!capture) return;
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/coral-table-20261112/home-${originalPhotos ? 'original-' : ''}$scale-$suffix.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await save('top');
      await tester.scrollUntilVisible(
        find.text('내 냉장고'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await save('inventory');
      expect(find.text('총 3개 재료'), findsOneWidget);
      final homeScroll = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('AI 재료 등록'),
        120,
        scrollable: homeScroll,
      );
      expect(find.text('영수증 사진으로 품목을 확인하고 등록해요.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('이런 메뉴 어때요?'),
        120,
        scrollable: homeScroll,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'receipt actions retain explicit visible labels and direct callbacks',
    (tester) async {
      var gallery = 0, camera = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: RegistrationHero(
              onGallery: () => gallery++,
              onCamera: () => camera++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('사진 선택'));
      await tester.tap(find.text('직접 촬영'));
      expect(gallery, 1);
      expect(camera, 1);
      expect(find.textContaining('냉장고 사진'), findsNothing);
    },
  );
}
