import '../services/recipe_example_photos.dart';
import '../services/recipe_photos.dart';
import 'recipe_photo_credits_page.dart';
import '../theme.dart';
import 'meal_assistant_page.dart';
import '../widgets/recipe_source_notice.dart';
import '../widgets/pantry_match_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models.dart';
import '../providers.dart';
import '../ingredient_matching.dart';
import '../services/cooking_steps.dart';
import '../widgets/external_video_reference.dart';
import '../widgets/recipe_cover.dart';
import 'add_recipe_page.dart';
import '../services/meal_history.dart';
import '../services/curation_foundation.dart';
import '../services/inventory_day.dart';
import '../widgets/meal_history_card.dart';

const cookingOrange = primaryGreen;
const _detailGreen = primaryGreen;
const _detailCream = lightGray;

class RecipeDetailPage extends ConsumerStatefulWidget {
  const RecipeDetailPage({super.key, required this.recipe});
  final Recipe recipe;
  @override
  ConsumerState<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends ConsumerState<RecipeDetailPage> {
  int tab = 0;
  Widget _inventoryError() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(liveRegion: true, child: const Text('재료 정보를 불러올 수 없습니다.')),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: () => ref.invalidate(ingredientsProvider),
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        icon: const Icon(Icons.refresh),
        label: const Text('재료 다시 불러오기'),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final inventory = ref.watch(ingredientsProvider);
    final profile = ref.watch(userProfileProvider).asData?.value;
    final likes = ref.watch(likedRecipeIdsProvider);
    final steps = savedCookingSteps(
      recipe.displayDescription,
      unverified: recipe.hasUnverifiedSteps,
    );
    final availability = IngredientAvailability(
      recipe.requiredIngredients,
      ref.watch(usableIngredientNamesProvider),
    );
    final lightTheme = Theme.of(context);
    return Theme(
      data: lightTheme,
      child: Scaffold(
        backgroundColor: _detailCream,
        appBar: AppBar(
          backgroundColor: _detailCream,
          foregroundColor: darkGray,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            '\uB808\uC2DC\uD53C',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              tooltip: 'AI 요리 도우미',
              icon: const Icon(Icons.auto_awesome_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MealAssistantPage(recipes: [recipe]),
                ),
              ),
            ),
            if (likes.asData != null)
              IconButton(
                tooltip: likes.asData!.value.contains(recipe.id)
                    ? '좋아요 취소'
                    : '좋아요 추가',
                icon: Icon(
                  likes.asData!.value.contains(recipe.id)
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
                onPressed: () async {
                  try {
                    await ref.read(likeRecipeProvider)(
                      recipe.id,
                      likes.asData!.value.contains(recipe.id),
                    );
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('좋아요를 저장하지 못했습니다.')),
                      );
                    }
                  }
                },
              ),
            if (profile?.role == 'admin')
              IconButton(
                tooltip: '레시피 수정',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddRecipePage(recipe: recipe),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final actions = <Widget>[
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _detailGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CookingPage(recipe: recipe),
                      ),
                    ),
                    child: const Text(
                      '조리 방법 보기',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: darkGray,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.restaurant_outlined),
                    label: const Text('먹었어요'),
                    onPressed: () {
                      final store = ref.read(mealHistoryProvider);
                      final today = ref.read(inventoryDayProvider);
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        showDragHandle: true,
                        builder: (context) => SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          child: MealHistoryCard(
                            store: store,
                            today: MealDay(today.year, today.month, today.day),
                          ),
                        ),
                      );
                    },
                  ),
                ];
                if (MediaQuery.textScalerOf(context).scale(14) > 21) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      actions[0],
                      const SizedBox(height: 8),
                      actions[1],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 3, child: actions[0]),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: actions[1]),
                  ],
                );
              },
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (RecipeCover(
                imageUrl: recipe.imageUrl,
                photo: recipePhotoFor(recipe),
                examplePhoto: recipeExamplePhotoFor(recipe),
                video: recipe.originalVideo,
              ).hasSources)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 1.5,
                      child: RecipeCover(
                        imageUrl: recipe.imageUrl,
                        photo: recipePhotoFor(recipe),
                        examplePhoto: recipeExamplePhotoFor(recipe),
                        video: recipe.originalVideo,
                        label: recipe.name,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  recipe.name,
                  style: const TextStyle(
                    color: darkGray,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.6,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: tab == i,
                        child: InkWell(
                          onTap: () => setState(() => tab = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: tab == i ? darkGray : warmBorder,
                                  width: tab == i ? 2 : 1,
                                ),
                              ),
                            ),
                            child: Text(
                              ['요약', '레시피', '재료'][i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: tab == i ? darkGray : mediumGray,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (tab == 0 &&
                        !inventory.isLoading &&
                        !inventory.hasError) ...[
                      _IngredientGroup(
                        title: '보유 재료',
                        names: availability.ownedIngredients,
                        availability: availability,
                        missing: false,
                      ),
                      const SizedBox(height: 12),
                      _IngredientGroup(
                        title: '추가로 필요한 재료',
                        names: availability.missingIngredients,
                        availability: availability,
                        missing: true,
                      ),
                      const SizedBox(height: 12),
                      const Text('이름 기준 비교이며 분량·신선도·알레르기 안전성을 보장하지 않아요.'),
                      const SizedBox(height: 18),
                    ],
                    Text(recipe.dataQualityNotice),
                    if (recipe.ingredientMatchingNotice != null) ...[
                      const SizedBox(height: 8),
                      Text(recipe.ingredientMatchingNotice!),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '조리 시간: ${recipe.totalTime?.trim().isNotEmpty == true ? recipe.totalTime : "미확인"} · 인원: ${recipe.servings?.trim().isNotEmpty == true ? recipe.servings : "미확인"}',
                    ),
                    const SizedBox(height: 12),
                    if (tab == 0) ...[
                      _InfoBox(
                        tinted: true,
                        child: Text(
                          recipe.hasUnverifiedSteps
                              ? '제작자 댓글에서 확인한 재료·분량입니다. 조리 순서와 영상 구간은 아직 확인되지 않았습니다.'
                              : '저장된 레시피를 바탕으로 표시합니다. 조리 전 분량과 과정을 확인해 주세요.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _InfoBox(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                if (recipe.totalTime?.isNotEmpty == true)
                                  Text('◷ ${recipe.totalTime}'),
                                if (recipe.cuisineType?.isNotEmpty == true)
                                  Text(recipe.cuisineType!),
                                Text(
                                  '재료 ${availability.requiredIngredients.length}가지',
                                ),
                                Text(
                                  steps.isEmpty
                                      ? '조리 단계 미등록'
                                      : '저장된 순서 ${steps.length}단계',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _InfoBox(
                        child: inventory.isLoading
                            ? const Text('재료 확인 중')
                            : inventory.hasError
                            ? _inventoryError()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  PantryMatchPanel(
                                    availability: availability,
                                    holdReason: recipe.recommendationHoldReason,
                                  ),
                                  if (availability
                                      .missingIngredients
                                      .isNotEmpty)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Icon(
                                        Icons.remove_circle_outline,
                                        color: cookingOrange,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ],
                    if (tab == 1) ...[
                      Text(
                        recipe.hasUnverifiedSteps ? '재료·출처 확인 정보' : '저장된 레시피',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (steps.isEmpty)
                        const _InfoBox(
                          tinted: true,
                          child: Text(
                            '진행할 조리 단계가 등록되어 있지 않습니다. 아래 원문을 확인해 주세요. 영상 시점은 자동으로 추정하지 않습니다.',
                          ),
                        ),
                      const SizedBox(height: 14),
                      if (recipe.displayDescription.isEmpty)
                        const Text('등록된 레시피 설명이 없습니다.')
                      else
                        MarkdownBody(data: recipe.displayDescription),
                    ],
                    if (tab == 2) ...[
                      if (inventory.isLoading)
                        const LinearProgressIndicator()
                      else if (inventory.hasError)
                        _inventoryError()
                      else
                        PantryMatchPanel(
                          availability: availability,
                          holdReason: recipe.recommendationHoldReason,
                        ),
                      const SizedBox(height: 12),
                      for (final name in availability.requiredIngredients)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _InfoBox(
                            child: Row(
                              children: [
                                Icon(
                                  inventory.isLoading ||
                                          inventory.hasError ||
                                          availability.isUncertain(name)
                                      ? Icons.help_outline
                                      : availability.owns(name)
                                      ? Icons.check_circle_outline
                                      : Icons.remove_circle_outline,
                                  color: cookingOrange,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    availability.isUncertain(name)
                                        ? '$name · 이름 확인 필요'
                                        : name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const Text('분량은 레시피 탭의 저장된 원문을 확인해 주세요.'),
                    ],
                    if (recipe.originalVideo case final video?) ...[
                      const SizedBox(height: 18),
                      ExternalVideoReference(video: video),
                    ],
                    if (recipePhotoFor(recipe) != null ||
                        recipeExamplePhotoFor(recipe) != null)
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RecipePhotoCreditsPage(),
                          ),
                        ),
                        icon: const Icon(Icons.photo_outlined),
                        label: Text(
                          recipePhotoFor(recipe) != null
                              ? '완성 음식 사진 · 식약처 · 출처'
                              : '음식 예시 사진 · 출처',
                        ),
                      ),
                    RecipeSourceNotice(recipe: recipe),
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

class _IngredientGroup extends StatelessWidget {
  const _IngredientGroup({
    required this.title,
    required this.names,
    required this.availability,
    required this.missing,
  });
  final String title;
  final List<String> names;
  final IngredientAvailability availability;
  final bool missing;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(bottom: 20),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: warmBorder)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: darkGray,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (names.isEmpty)
          Text(missing ? '등록된 재료 중 보유 미확인 항목이 없어요.' : '이름이 일치하는 보유 재료가 없어요.')
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final single = MediaQuery.textScalerOf(context).scale(14) > 21;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final name in names)
                    SizedBox(
                      width: single
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 12) / 2,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            availability.isUncertain(name)
                                ? Icons.help_outline
                                : missing
                                ? Icons.add_circle_outline
                                : Icons.check_circle_outline,
                            size: 20,
                            color: _detailGreen,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              availability.isUncertain(name)
                                  ? '$name · 이름 확인 필요'
                                  : name,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    ),
  );
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.child, this.tinted = false});
  final Widget child;
  final bool tinted;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: tinted
        ? const EdgeInsets.all(14)
        : const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: tinted ? softGreen : Colors.transparent,
      borderRadius: tinted ? BorderRadius.circular(8) : null,
    ),
    child: child,
  );
}

class CookingPage extends StatefulWidget {
  const CookingPage({super.key, required this.recipe});
  final Recipe recipe;
  @override
  State<CookingPage> createState() => _CookingPageState();
}

class _CookingPageState extends State<CookingPage> {
  int current = 0;
  bool completed = false;
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void move(int next) {
    setState(() {
      current = next;
      completed = false;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final steps = savedCookingSteps(
      recipe.displayDescription,
      unverified: recipe.hasUnverifiedSteps,
    );

    return Theme(
      data: Theme.of(context),
      child: Scaffold(
        backgroundColor: lightGray,
        appBar: AppBar(
          backgroundColor: lightGray,
          foregroundColor: darkGray,
          title: Text(recipe.name, style: const TextStyle(fontSize: 17)),
        ),
        bottomNavigationBar: steps.isEmpty
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: current > 0 || completed
                              ? () => move(completed ? current : current - 1)
                              : null,
                          child: const Text('이전'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: cookingOrange,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: completed
                              ? () => Navigator.pop(context)
                              : () {
                                  if (current + 1 < steps.length) {
                                    move(current + 1);
                                  } else {
                                    setState(() => completed = true);
                                  }
                                },
                          child: Text(
                            completed
                                ? '레시피로'
                                : current + 1 == steps.length
                                ? '완료'
                                : '다음',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        body: SingleChildScrollView(
          controller: scroll,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (recipe.originalVideo case final video?)
                  ExternalVideoReference(video: video),
                const SizedBox(height: 16),
                const Text('저장된 조리 정보 · 참고 영상은 외부 앱에서 재생돼요.'),
                const SizedBox(height: 20),
                if (steps.isEmpty) ...[
                  const Icon(
                    Icons.menu_book_outlined,
                    color: primaryGreen,
                    size: 40,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '아직 조리 단계가 없습니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '검증된 조리 순서가 저장되면 터치로 한 단계씩 진행할 수 있어요. 현재는 원본 영상과 저장된 레시피 정보를 확인해 주세요.',
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Semantics(
                    label: '${current + 1} / ${steps.length} 단계',
                    child: LinearProgressIndicator(
                      value: completed ? 1 : (current + 1) / steps.length,
                      color: darkGray,
                      backgroundColor: softGreen,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    completed ? '요리 완료' : '${current + 1} / ${steps.length} 단계',
                    style: const TextStyle(
                      color: primaryGreen,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: softGreen,
                      border: Border.all(color: warmBorder),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        completed
                            ? '수고하셨어요. 완성된 요리를 즐겨보세요.'
                            : '${current + 1}. ${steps[current]}',
                        style: const TextStyle(
                          color: darkGray,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  if (!completed)
                    for (var i = current + 1; i < steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Text(
                          '${i + 1}. ${steps[i]}',
                          style: const TextStyle(
                            fontSize: 18,
                            color: mediumGray,
                            height: 1.5,
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
