import 'package:take_care_refrigerator/src/widgets/app_navigation.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/models.dart';
import 'package:take_care_refrigerator/src/providers.dart';
import 'package:take_care_refrigerator/src/theme.dart';
import 'package:take_care_refrigerator/src/pages/home_page.dart';
import 'package:take_care_refrigerator/src/pages/recipes_page.dart';
import 'package:take_care_refrigerator/src/pages/login_page.dart';

void main() {
  testWidgets(
    'small screens support inventory, recipe filters and login without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const capture = bool.fromEnvironment('UI_CAPTURE');
      if (capture) {
        await tester.runAsync(() async {
          final font = FontLoader('Roboto')
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  await File(r'C:\Windows\Fonts\malgun.ttf').readAsBytes(),
                ),
              ),
            );
          await font.load();
          final fallback = FontLoader('Ahem')
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  await File(r'C:\Windows\Fonts\malgun.ttf').readAsBytes(),
                ),
              ),
            );
          await fallback.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  await File(
                    r'C:\Users\User\develop\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
                  ).readAsBytes(),
                ),
              ),
            );
          await icons.load();
        });
      }
      final recipe = Recipe(
        id: 'demo',
        name: '두부와 양파 한 접시',
        requiredIngredients: ['두부', '양파', '간장'],
        totalTime: '15분',
        description: '1. 두부와 양파를 먹기 좋게 썰어요.\n\n2. 팬에 재료를 넣고 충분히 익혀 주세요.',
        likeCount: 0,
        createdAt: DateTime(2026),
      );
      final items = [
        Ingredient(
          id: 'demo',
          name: '두부',
          quantity: '1모',
          expiryDate: DateTime.now().add(const Duration(days: 2)),
          storageType: 'refrigerated',
          createdAt: DateTime.now(),
        ),
      ];
      items.addAll([
        Ingredient(
          id: 'demo2',
          name: '달걀',
          quantity: '6개',
          expiryDate: DateTime.now(),
          storageType: 'refrigerated',
          createdAt: DateTime.now(),
        ),
        Ingredient(
          id: 'demo3',
          name: '대파',
          quantity: '1단',
          expiryDate: DateTime.now().add(const Duration(days: 7)),
          storageType: 'frozen',
          createdAt: DateTime.now(),
        ),
        Ingredient(
          id: 'demo4',
          name: '양파',
          quantity: '2개',
          expiryDate: DateTime.now().add(const Duration(days: 10)),
          storageType: 'ambient',
          createdAt: DateTime.now(),
        ),
      ]);
      items.addAll([
        Ingredient(
          id: 'demo5',
          name: '토마토',
          quantity: '3개',
          expiryDate: DateTime.now().add(const Duration(days: 11)),
          storageType: 'refrigerated',
          createdAt: DateTime.now(),
        ),
        Ingredient(
          id: 'demo6',
          name: '우유',
          quantity: '1팩',
          expiryDate: DateTime.now().add(const Duration(days: 12)),
          storageType: 'refrigerated',
          createdAt: DateTime.now(),
        ),
      ]);
      final boundary = GlobalKey();
      bool denyPhoto = false;
      Future<void> show(Widget page, String name) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ingredientImagePickerProvider.overrideWithValue((source) async {
                if (denyPhoto)
                  throw PlatformException(code: 'camera_access_denied');
                return null;
              }),
              userProfileProvider.overrideWith((ref) async => null),
              likedRecipeIdsProvider.overrideWith(
                (ref) => Stream.value(<String>{}),
              ),
              ingredientsProvider.overrideWith((ref) => Stream.value(items)),
              expiringIngredientsRecipesProvider.overrideWith(
                (ref) => [recipe],
              ),
              shelfLifeDataProvider.overrideWith(
                (ref) async => <String, int>{},
              ),
            ],
            child: MaterialApp(
              theme: capture
                  ? appTheme.copyWith(
                      appBarTheme: appTheme.appBarTheme.copyWith(
                        titleTextStyle: appTheme.appBarTheme.titleTextStyle!
                            .copyWith(fontFamily: 'Roboto'),
                      ),
                    )
                  : appTheme,
              home: RepaintBoundary(
                key: boundary,
                child: Column(
                  children: [
                    const Material(
                      color: Color(0xFFE8EEE4),
                      child: SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Text(
                            '미리보기 · 예시 데이터',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: page),
                    if (name == 'home' || name == 'inventory')
                      AppNavigation(
                        index: name == 'home' ? 0 : 1,
                        onSelected: (_) {},
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (capture) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('build/ui-preview/$name.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }

      await show(
        DashboardPage(
          onInventory: () {},
          onRecipes: () {},
          onNotifications: () {},
        ),
        'home',
      );
      await show(RecipeDetailPage(recipe: recipe), 'detail');
      await tester.ensureVisible(find.text('레시피'));
      await tester.tap(find.text('레시피'));
      await tester.pumpAndSettle();
      expect(find.text('저장된 레시피'), findsOneWidget);
      await show(const HomePage(), 'inventory');
      await tester.tap(find.text('냉동'));
      await tester.pumpAndSettle();
      expect(find.text('대파'), findsOneWidget);
      expect(find.text('두부'), findsNothing);
      await tester.tap(find.text('전체'));
      await tester.tap(find.byTooltip('재료 검색'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '없는 재료');
      await tester.pumpAndSettle();
      expect(find.textContaining('표시할 재료가 없어요.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.viewPadding = const FakeViewPadding(bottom: 48);
      tester.view.padding = const FakeViewPadding(bottom: 48);
      await tester.tap(find.text('재료 추가').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('사진 촬영'));
      await tester.tap(find.text('사진 촬영'));
      await tester.pumpAndSettle();
      expect(find.text('선택 취소'), findsNothing);
      denyPhoto = true;
      await tester.tap(find.text('사진 촬영'));
      await tester.pumpAndSettle();
      expect(find.textContaining('카메라·사진 권한'), findsOneWidget);
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('추가하기'));
      expect(
        tester.getBottomRight(find.widgetWithText(ElevatedButton, '추가하기')).dy,
        lessThanOrEqualTo(592),
      );
      expect(tester.takeException(), isNull);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.view.physicalSize = const Size(360, 800);
      await tester.ensureVisible(find.text('추가하기'));
      expect(
        tester.getBottomRight(find.widgetWithText(ElevatedButton, '추가하기')).dy,
        lessThanOrEqualTo(752),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('추가하기'));
      expect(
        tester.getBottomRight(find.widgetWithText(ElevatedButton, '추가하기')).dy,
        lessThanOrEqualTo(500),
      );
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      tester.view.resetViewPadding();
      tester.view.resetPadding();
      await show(
        Scaffold(
          body: ListView(
            children: [
              const SortOptions(),
              RecipeCard(recipe: recipe),
            ],
          ),
        ),
        'recipes',
      );
      await show(const LoginPage(), 'login');
      await tester.tap(find.text('이메일로 로그인 또는 회원가입'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('이메일로 로그인'));
      await tester.tap(find.text('이메일로 로그인'));
      await tester.pumpAndSettle();
      expect(find.text('유효한 이메일을 입력하세요.'), findsOneWidget);
      expect(find.text('6자 이상의 비밀번호를 입력하세요.'), findsOneWidget);
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await show(
        DashboardPage(
          onInventory: () {},
          onRecipes: () {},
          onNotifications: () {},
        ),
        'home-large',
      );
      await show(const HomePage(), 'inventory-large');
      await show(RecipeDetailPage(recipe: recipe), 'detail-large');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
