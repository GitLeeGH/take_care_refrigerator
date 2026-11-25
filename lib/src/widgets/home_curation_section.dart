import '../services/home_meal_period.dart';
import 'home_automatic_curation_panel.dart';
import 'home_manual_curation_panel.dart';

import '../services/recipe_photos.dart';
import '../services/recipe_example_photos.dart';
import 'app_presentation.dart';
import '../services/contextual_menu_curation.dart';
import 'recipe_cover.dart';
import '../theme.dart';
import '../services/home_ai_selection.dart';
import '../services/meal_assistant.dart';
import '../services/curation_preferences.dart';
import '../services/inventory_day.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../models.dart';
import '../ingredient_matching.dart';
import '../pages/recipe_detail_page.dart';

/// Local recommendations never trigger a paid call. AI retains exact-input consent.
class HomeCurationSection extends ConsumerWidget {
  const HomeCurationSection({super.key, this.active = true})
    : _seasonalOnly = false;
  const HomeCurationSection.seasonal({super.key})
    : active = false,
      _seasonalOnly = true;
  final bool _seasonalOnly;
  final bool active;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranked = ref.watch(recommendedIdsProvider);
    final catalog = ref.watch(allRecipesListProvider);
    final pantry = ref.watch(usableIngredientNamesProvider);
    final inventory = ref.watch(ingredientsProvider);
    if (inventory.isLoading || catalog.isLoading || ranked.isLoading) {
      if (_seasonalOnly) return const SizedBox.shrink();
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('오늘의 메뉴를 고르고 있어요.'),
      );
    }
    if (inventory.hasError || catalog.hasError || ranked.hasError) {
      if (_seasonalOnly) return const SizedBox.shrink();
      return TextButton.icon(
        onPressed: () {
          ref.invalidate(ingredientsProvider);
          ref.invalidate(allRecipesListProvider);
          ref.invalidate(activeCurationPreferencesProvider);
          ref.invalidate(recommendedIdsProvider);
        },
        icon: const Icon(Icons.refresh),
        label: Text(catalog.hasError ? '레시피를 불러오지 못했어요 · 다시 시도' : '추천 다시 불러오기'),
      );
    }
    final byId = <String, Recipe>{
      for (final r in catalog.asData?.value ?? <Recipe>[]) r.id: r,
    };
    final rankedRecipes = <Recipe>[
      for (final id in ranked.asData?.value ?? <String>[])
        if (byId[id] != null && byId[id]!.eligibleForRecommendation) byId[id]!,
    ];
    // The AI preview stays bounded; local shopping suggestions use all matches.
    final moment = ref.watch(homeMealMomentProvider);
    final period = mealPeriodAt(moment);
    final mealLabel = mealPeriodLabel(period);
    final recipes = mealPeriodCandidates(
      rankedRecipes.take(10).toList(),
      period,
      pantry: pantry,
    );
    final today = ref.watch(inventoryDayProvider);
    final cached = ref.watch(homeAiSelectionProvider);
    HomeAiSelection? selection;
    if (cached != null && recipes.isNotEmpty) {
      try {
        final draft = MealAssistantDraft(
          task: MealAssistantTask.menus,
          candidates: [
            for (final r in recipes)
              {
                'id': r.id,
                'name': r.name,
                'ingredients': r.requiredIngredients,
                'steps': <String>[],
              },
          ],
          pantry: pantry,
        );
        final owner = ref.read(curationIdentityProvider).account;
        if (owner != null &&
            cached.matches(
              owner,
              draft.revision,
              DateTime.now(),
              mealPeriod: (homeMealPeriodAiEnabled || homeManualMealAiEnabled)
                  ? period.name
                  : null,
            ) &&
            cached.result.menus.every(
              (m) => byId[m.id]?.eligibleForRecommendation == true,
            )) {
          selection = cached;
        }
      } on MealAssistantFailure {
        /* Retain local suggestions. */
      }
    }
    final displayed = selection == null
        ? recipes.take(2).toList()
        : [for (final menu in selection.result.menus.take(2)) byId[menu.id]!];
    final seasonal = officialSeasonalMenus(
      byId.values,
      today.month,
    ).where((r) => !displayed.any((d) => d.id == r.recipe.id)).take(1).toList();
    if (_seasonalOnly) {
      return seasonal.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 24),
              child: _SeasonalSuggestion(
                menu: seasonal.first,
                month: today.month,
              ),
            );
    }
    Recipe? extraRecipe;
    // Prefer a displayed menu, then find an alternative beyond the two hero cards.
    // Preserve the shared coverage/history/expiry ranking and review gates.
    for (final recipe in [...displayed, ...rankedRecipes]) {
      final match = IngredientAvailability(recipe.requiredIngredients, pantry);
      if (match.ownedIngredients.isNotEmpty &&
          match.missingIngredients.isNotEmpty) {
        extraRecipe = recipe;
        break;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeading('오늘 $mealLabel, 이런 메뉴 어때요?'),
        const SizedBox(height: 6),
        Text(
          selection == null ? '내 재료·취향과 식사 시간으로 고른 추천' : '최근 AI 추천 · 6시간 이내 결과',
          style: const TextStyle(color: mediumGray, fontSize: 14),
        ),
        if (recipes.isNotEmpty) ...[
          const SizedBox(height: 8),
          if (homeManualMealAiEnabled)
            HomeManualCurationPanel(
              recipes: recipes,
              pantry: pantry,
              active: active,
              mealLabel: mealLabel,
            )
          else
            HomeAutomaticCurationPanel(
              recipes: recipes,
              pantry: pantry,
              active: active,
              mealLabel: mealLabel,
            ),
        ],
        const SizedBox(height: 18),
        if (displayed.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              final single =
                  constraints.maxWidth < 310 ||
                  MediaQuery.textScalerOf(context).scale(16) > 22;
              final tiles = [
                for (var i = 0; i < displayed.length; i++)
                  _Suggestion(
                    recipe: displayed[i],
                    pantry: pantry,
                    number: i + 1,
                    reason: selection == null
                        ? null
                        : selection.result.menus[i].reason,
                  ),
              ];
              if (single || tiles.length == 1) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      tiles[i],
                    ],
                  ],
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      SizedBox(
                        width: constraints.maxWidth * .9,
                        child: tiles[i],
                      ),
                    ],
                  ],
                ),
              );
            },
          )
        else ...[
          const Text('현재 재료에 맞는 추천 메뉴가 없어요.'),
          if (byId.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('재료와 레시피를 등록하면 여기에서 추천해드려요.'),
            )
          else ...[
            const SizedBox(height: 16),
            const Text('저장된 레시피 둘러보기', style: sectionHeadingStyle),
            const SizedBox(height: 4),
            const Text(
              '내 재료 추천이 아닌 저장된 레시피예요.',
              style: TextStyle(fontSize: 12, color: mediumGray),
            ),
            for (final r in byId.values.take(3))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r.name),
                trailing: const Icon(Icons.arrow_forward, size: 18),
                onTap: () => _openRecipe(context, r),
              ),
          ],
        ],
        if (displayed.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text(
            '재료 이름 기준 · 분량과 상태는 확인해 주세요.',
            style: TextStyle(color: mediumGray, fontSize: 12, height: 1.4),
          ),
        ],
        if (extraRecipe != null) ...[
          const SizedBox(height: 16),
          _ShoppingSuggestion(recipe: extraRecipe, pantry: pantry),
        ],
      ],
    );
  }
}

void _openRecipe(BuildContext context, Recipe recipe) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => RecipeDetailPage(recipe: recipe)));

class _Suggestion extends StatelessWidget {
  const _Suggestion({
    required this.recipe,
    required this.pantry,
    required this.number,
    this.reason,
  });
  final Recipe recipe;
  final List<String> pantry;
  final int number;
  final String? reason;
  @override
  Widget build(BuildContext context) {
    final match = IngredientAvailability(recipe.requiredIngredients, pantry);
    final missing = match.missingIngredients;
    final missingSummary =
        missing.take(2).join(', ') +
        (missing.length > 2 ? ' 외 ${missing.length - 2}개' : '');
    final cover = RecipeCover(
      imageUrl: recipe.imageUrl,
      video: recipe.originalVideo,
      photo: recipePhotoFor(recipe),
      examplePhoto: recipeExamplePhotoFor(recipe),
      label: recipe.name,
      placeholderBuilder: (message) => Semantics(
        label: message,
        child: const ColoredBox(
          color: Color(0xFF63564E),
          child: Center(
            child: Icon(
              Icons.restaurant_outlined,
              size: 52,
              color: Colors.white54,
            ),
          ),
        ),
      ),
    );
    final hasPhoto = cover.hasSources;
    final ink = hasPhoto ? Colors.white : darkGray;
    return Semantics(
      button: true,
      label: '${recipe.name} 레시피 열기',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openRecipe(context, recipe),
          child: Stack(
            children: [
              if (hasPhoto) ...[
                Positioned.fill(child: cover),
                const Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0, .25, .7, 1],
                          colors: [
                            Colors.transparent,
                            Color(0x18000000),
                            Color(0xD9000000),
                            Color(0xED000000),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasPhoto)
                      const SizedBox(height: 108)
                    else ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: CircleAvatar(
                          backgroundColor: coralSurface,
                          foregroundColor: primaryGreen,
                          child: Icon(Icons.restaurant_menu),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    Text(
                      '추천 0$number',
                      style: TextStyle(
                        color: hasPhoto ? Colors.white70 : primaryGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      recipe.name,
                      style: TextStyle(
                        fontSize: 22,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.6,
                        color: ink,
                      ),
                    ),
                    if (recipe.totalTime?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(
                        recipe.totalTime!,
                        style: TextStyle(fontSize: 12, color: ink),
                      ),
                    ],
                    if (match.ownedIngredients.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '보유 · ${match.ownedIngredients.take(3).join(', ')}${match.ownedIngredients.length > 3 ? ' 외 ${match.ownedIngredients.length - 3}개' : ''}',
                        style: TextStyle(
                          color: hasPhoto ? Colors.white70 : mediumGray,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: hasPhoto ? Colors.white : coralSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          missing.isEmpty ? '있는 재료로' : '$missingSummary 더하기',
                          style: const TextStyle(
                            color: primaryGreen,
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (reason != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        reason!,
                        style: TextStyle(color: ink, fontSize: 13, height: 1.5),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '레시피 보기',
                            style: TextStyle(fontSize: 12, color: ink),
                          ),
                        ),
                        Icon(Icons.arrow_forward, size: 18, color: ink),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShoppingSuggestion extends StatelessWidget {
  const _ShoppingSuggestion({required this.recipe, required this.pantry});
  final Recipe recipe;
  final List<String> pantry;
  @override
  Widget build(BuildContext context) {
    final missing = IngredientAvailability(
      recipe.requiredIngredients,
      pantry,
    ).missingIngredients;
    return Material(
      color: coralSurface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openRecipe(context, recipe),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '장볼 때 이것만 더',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: mediumGray,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${missing.join(', ')} 더 준비하면 ${recipe.name}도 가능해요',
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeasonalSuggestion extends StatelessWidget {
  const _SeasonalSuggestion({required this.menu, required this.month});
  final ContextMenu menu;
  final int month;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$month월 제철 재료로',
        style: const TextStyle(
          fontSize: 14,
          color: mediumGray,
          fontWeight: FontWeight.w600,
        ),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          menu.recipe.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        subtitle: Text(
          menu.reason,
          style: const TextStyle(fontSize: 12, color: mediumGray, height: 1.5),
        ),
        trailing: const Icon(Icons.arrow_forward, size: 18, color: mediumGray),
        onTap: () => _openRecipe(context, menu.recipe),
      ),
      const Text(
        '국내 월별 추천 기준 · 산지와 재배 방식에 따라 달라질 수 있어요.',
        style: TextStyle(color: mediumGray, fontSize: 11, height: 1.5),
      ),
    ],
  );
}
