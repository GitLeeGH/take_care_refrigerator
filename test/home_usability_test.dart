import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/models.dart';
import 'package:take_care_refrigerator/src/providers.dart';
import 'package:take_care_refrigerator/src/pages/home_page.dart';
import 'package:take_care_refrigerator/src/services/inventory_day.dart';
import 'package:take_care_refrigerator/src/services/meal_history.dart';
import 'package:take_care_refrigerator/src/theme.dart';
import 'package:take_care_refrigerator/src/widgets/app_navigation.dart';
import 'package:take_care_refrigerator/src/widgets/ingredient_thumbnail.dart';
import 'package:take_care_refrigerator/src/services/ingredient_photos.dart';
import 'package:take_care_refrigerator/src/widgets/recipe_cover.dart';
import 'support/local_preferences_stub.dart';

void main() {
  stubLocalPreferences();
  for (final scale in [1.0, 1.6, 2.0]) {
    testWidgets('home has no disclosures or empty photo frames at ${scale}x', (
      tester,
    ) async {
      const capture = bool.fromEnvironment('HOME_CAPTURE');
      final width = scale == 1 ? 360.0 : 320.0;
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 32);
      tester.view.viewPadding = const FakeViewPadding(bottom: 32);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
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
      final recipes = [
        Recipe(
          id: 'a',
          name: '두부와 양파 한 접시',
          requiredIngredients: ['두부', '양파', '간장'],
          likeCount: 0,
          createdAt: day,
        ),
        Recipe(
          id: 'b',
          name: '달걀 채소 볶음',
          requiredIngredients: ['달걀', '양파'],
          likeCount: 0,
          createdAt: day,
        ),
        Recipe(
          id: 'seasonal',
          name: '무를 넣은 따뜻한 국',
          requiredIngredients: ['무'],
          likeCount: 0,
          createdAt: day,
        ),
      ];
      final items = [
        for (final row in [('달걀', 0), ('두부', 1), ('양파', 3), ('삼겹살', -1)])
          Ingredient(
            id: row.$1,
            name: row.$1,
            quantity: '1개',
            expiryDate: day.add(Duration(days: row.$2)),
            storageType: 'refrigerated',
            createdAt: day,
          ),
      ];
      final boundary = GlobalKey();
      var inventoryOpens = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            testCurationIdentityOverride,
            inventoryClockProvider.overrideWithValue(() => day),
            ingredientsProvider.overrideWith((ref) => Stream.value(items)),
            allRecipesListProvider.overrideWith((ref) async => recipes),
            recommendedIdsProvider.overrideWith((ref) async => ['a', 'b']),
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
                  fontFamily: 'Roboto',
                ),
              ),
            ),
            home: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                body: Column(
                  children: [
                    const Material(
                      color: softGreen,
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
                    Expanded(
                      child: DashboardPage(
                        onInventory: () => inventoryOpens++,
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
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('등록된 이미지가 없어요'), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsNothing);
      expect(tester.takeException(), isNull);
      for (final cover in find.byType(RecipeCover).evaluate()) {
        expect(
          tester.getSize(find.byWidget(cover.widget)).height,
          lessThan(180),
        );
      }
      Future<void> save(String suffix) async {
        if (!capture) return;
        await tester.runAsync(() async {
          for (final element in find.byType(IngredientThumbnail).evaluate()) {
            final thumbnail = element.widget as IngredientThumbnail;
            final photo = ingredientReferencePhotoFor(thumbnail.name);
            if (photo != null) {
              await precacheImage(
                ResizeImage(AssetImage(photo.assetPath), width: 512),
                element,
              );
            }
          }
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/home-usability-20261112/home-$scale-$suffix.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await save('top');
      await tester.scrollUntilVisible(
        find.text('내 냉장고'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('총 4개 재료'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      await save('inventory');
      await Scrollable.ensureVisible(
        tester.element(find.textContaining('기한 지난 재료 1개')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('기한 지난 재료 1개'));
      expect(inventoryOpens, 1);
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('내 냉장고').hitTestable(), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('사진 선택'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('사진 선택'), findsOneWidget);
      expect(find.text('직접 촬영'), findsOneWidget);
      expect(find.text('냉장고를 부탁해'), findsOneWidget);
      await save('actions');
      await tester.scrollUntilVisible(
        find.text('11월 제철 재료로'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      // Seasonal menu is visible without a disclosure tap.
      expect(find.text('무를 넣은 따뜻한 국'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  }
  for (final succeeds in [true, false]) {
    testWidgets(
      'adaptive cover ${succeeds ? 'displays registered source' : 'collapses failed source'}',
      (tester) async {
        final requests = <Uri>[];
        final client = _ImageClient(succeeds, requests);
        debugNetworkImageHttpClientProvider = () => client;

        try {
          await HttpOverrides.runZoned(() async {
            await tester.runAsync(() async {
              await tester.pumpWidget(
                MaterialApp(
                  home: Scaffold(
                    body: SizedBox(
                      width: 320,
                      child: RecipeCover(
                        imageUrl:
                            'https://example.test/${succeeds ? 'ok' : 'failed'}.png',
                        imageAspectRatio: 1.45,
                        placeholderBuilder: (_) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              );
              await Future<void>.delayed(const Duration(milliseconds: 150));
              await tester.pump();
            });
            await tester.pumpAndSettle();
            final size = tester.getSize(find.byType(RecipeCover));
            expect(size.height, succeeds ? closeTo(320 / 1.45, .1) : 0);
            expect(requests, [
              Uri.parse(
                'https://example.test/${succeeds ? 'ok' : 'failed'}.png',
              ),
            ]);
            expect(tester.takeException(), isNull);
          }, createHttpClient: (_) => client);
        } finally {
          debugNetworkImageHttpClientProvider = null;
        }
      },
    );
  }
}

class _ImageClient implements HttpClient {
  _ImageClient(this.succeeds, this.requests);
  final bool succeeds;
  final List<Uri> requests;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requests.add(url);
    return _ImageRequest(succeeds);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _ImageRequest implements HttpClientRequest {
  _ImageRequest(this.succeeds);
  final bool succeeds;
  @override
  final HttpHeaders headers = _Headers();
  @override
  Future<HttpClientResponse> close() async => _ImageResponse(succeeds);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Headers implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  _ImageResponse(this.succeeds);
  final bool succeeds;
  final bytes = File('assets/images/ingredients/onion.jpg').readAsBytesSync();
  @override
  int get statusCode => succeeds ? 200 : 404;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
