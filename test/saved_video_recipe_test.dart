import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_care_refrigerator/src/models.dart';
import 'package:take_care_refrigerator/src/pages/recipes_page.dart';
import 'package:take_care_refrigerator/src/providers.dart';
import 'package:take_care_refrigerator/src/widgets/original_video_panel.dart';
import 'package:take_care_refrigerator/src/widgets/recipe_cover.dart';

Recipe savedRecipe({
  String? description,
  String? video = 'rLEyOHvGb1Y',
  String? blog,
}) => Recipe.fromJson({
  'id': 'saved-server-row',
  'name': '저장된 영상 레시피',
  'description':
      description ?? '[확인된 재료와 분량]\n돼지고기 600g\n[아직 확인되지 않은 정보]\n조리 순서 미확인',
  'youtube_video_id': video,
  'blog_url': blog,
  'required_ingredients': ['돼지고기'],
  'created_at': '2026-10-28T05:24:36Z',
});

void main() {
  test('saved fields preserve unknown values and validate video links', () {
    final recipe = savedRecipe();
    expect(recipe.hasUnverifiedSteps, isTrue);
    expect(recipe.totalTime, isNull);
    expect(recipe.imageUrl, isNull);
    expect(recipe.originalVideo, isNotNull);
    expect(savedRecipe(video: 'invalid').originalVideo, isNull);
    expect(
      savedRecipe(
        video: null,
        blog: 'https://www.instagram.com/reel/ABCdef123/',
      ).originalVideo,
      isNotNull,
    );
    expect(
      savedRecipe(description: '1. 재료를 볶습니다.').hasUnverifiedSteps,
      isFalse,
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(recipeSortProvider), RecipeSortType.recent);
  });

  testWidgets(
    'existing card opens saved recipe with video and evidence, no invented steps',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ingredientsProvider.overrideWith(
              (ref) => Stream.value(<Ingredient>[]),
            ),
            userProfileProvider.overrideWith((ref) async => null),
            likedRecipeIdsProvider.overrideWith(
              (ref) => Stream.value(<String>{}),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: RecipeCard(recipe: savedRecipe())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RecipeCover>(find.byType(RecipeCover))
            .sources
            .single
            .host,
        'i.ytimg.com',
      );
      expect(find.text('영상 레시피 · 원본 함께 보기'), findsOneWidget);
      await tester.tap(find.text('저장된 영상 레시피'));
      await tester.pumpAndSettle();
      expect(find.byType(OriginalVideoPanel), findsOneWidget);
      expect(
        tester
            .widget<OriginalVideoPanel>(find.byType(OriginalVideoPanel))
            .playOnEntry,
        isFalse,
      );
      expect(find.byType(RecipeCover), findsWidgets);
      await tester.ensureVisible(find.text('레시피'));
      await tester.tap(find.text('레시피'));
      await tester.pumpAndSettle();
      expect(find.text('요리 시작하기'), findsNothing);
      expect(find.text('조리 방법'), findsNothing);
      expect(find.text('재료·출처 확인 정보'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
