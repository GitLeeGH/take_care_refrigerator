import '../services/recipe_example_photos.dart';
import '../services/recipe_photos.dart';
import '../services/recipe_preview.dart';
import '../widgets/app_presentation.dart';
import 'local_curation_page.dart';
import '../widgets/pantry_match_panel.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../providers.dart';
import '../models.dart';
import '../ingredient_matching.dart';
import '../theme.dart';
import '../widgets/recipe_cover.dart';
import 'add_recipe_page.dart';
import 'recipe_import_page.dart';
import 'recipe_detail_page.dart';
export 'recipe_detail_page.dart' show RecipeDetailPage;

class RecipesPage extends ConsumerStatefulWidget {
  const RecipesPage({super.key});

  @override
  ConsumerState<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends ConsumerState<RecipesPage> {
  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);
    final state = ref.watch(paginatedRecipesProvider);
    final recipes = ref.watch(filteredPaginatedRecipesProvider);
    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        toolbarHeight: pageToolbarHeight(context),
        title: const Text('레시피'),
        actions: [
          IconButton(
            tooltip: '\ub0b4 \uc7ac\ub8cc\ub85c \ucd94\ucc9c',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LocalCurationPage()),
            ),
          ),
          IconButton(
            tooltip: '\uc601\uc0c1 \ub808\uc2dc\ud53c \ubbf8\ub9ac\ubcf4\uae30',
            icon: const Icon(Icons.video_library_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const RecipeImportPage())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(paginatedRecipesProvider.notifier).refresh(),
        child: ListView(
          key: const ValueKey('menu-editorial-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 28),
          children: [
            const Text(
              '\uc624\ub298\uc758 \ud55c \ub07c',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: darkGray,
                letterSpacing: -1.1,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '\ub0c9\uc7a5\uace0 \uc18d \uc7ac\ub8cc\ub85c, \ub354 \ub9db\uc788\uac8c.',
              style: TextStyle(color: mediumGray, fontSize: 14),
            ),
            const SizedBox(height: 24),
            const RecipeSearchBar(),
            const SizedBox(height: 20),
            Material(
              color: softGreen,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LocalCurationPage()),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 22,
                        color: primaryGreen,
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '\ub0b4 \uc7ac\ub8cc\ub85c \ucd94\ucc9c',
                              style: TextStyle(
                                color: darkGray,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              '\ubcf4\uc720 \uc7ac\ub8cc\uc640 \ucde8\ud5a5\uc73c\ub85c \uba54\ub274 \ucc3e\uae30',
                              style: TextStyle(
                                color: darkGray,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: primaryGreen,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              '\ub808\uc2dc\ud53c \ub458\ub7ec\ubcf4\uae30',
              style: sectionHeadingStyle,
            ),
            const SizedBox(height: 12),
            const SortOptions(),
            if (state.hasError)
              TextButton.icon(
                onPressed: () =>
                    ref.read(paginatedRecipesProvider.notifier).retry(),
                icon: const Icon(Icons.refresh),
                label: const Text(
                  '\ub808\uc2dc\ud53c\ub97c \ubd88\ub7ec\uc624\uc9c0 \ubabb\ud588\uc5b4\uc694 \u00b7 \ub2e4\uc2dc \uc2dc\ub3c4',
                ),
              ),
            const SizedBox(height: 12),
            if (recipes.isEmpty && state.isLoading)
              Shimmer.fromColors(
                baseColor: warmBorder,
                highlightColor: Colors.white,
                child: const Column(
                  children: [RecipeCardSkeleton(), RecipeCardSkeleton()],
                ),
              )
            else if (recipes.isEmpty)
              AppEmptyState(
                icon: Icons.restaurant_menu_outlined,
                title: state.hasError
                    ? '\uac80\uc0c9\uc744 \uc644\ub8cc\ud558\uc9c0 \ubabb\ud588\uc5b4\uc694'
                    : state.hasMore
                    ? '\uc544\uc9c1 \uc77c\uce58\ud558\ub294 \ub808\uc2dc\ud53c\ub97c \ucc3e\uc9c0 \ubabb\ud588\uc5b4\uc694'
                    : '\ud45c\uc2dc\ud560 \ub808\uc2dc\ud53c\uac00 \uc5c6\uc5b4\uc694',
                message: state.hasError
                    ? '\uc544\ub798 \ub2e4\uc2dc \uc2dc\ub3c4\ub85c \uc911\ub2e8\ub41c \uac80\uc0c9\uc744 \uc774\uc5b4\uac08 \uc218 \uc788\uc5b4\uc694.'
                    : state.hasMore
                    ? '${state.scannedCount}\uac1c\ub97c \ud655\uc778\ud588\uc5b4\uc694. \ub2e4\uc74c \ub808\uc2dc\ud53c\ub97c \ub354 \ucc3e\uc544\ubcfc \uc218 \uc788\uc5b4\uc694.'
                    : '\uac80\uc0c9\uc5b4\uc640 \ud544\ud130\ub97c \ud655\uc778\ud558\uac70\ub098 \uc544\ub798\ub85c \ub2f9\uaca8 \ub2e4\uc2dc \ubd88\ub7ec\uc640 \uc8fc\uc138\uc694.',
                action: state.hasMore && !state.hasError
                    ? TextButton(
                        onPressed: () => ref
                            .read(paginatedRecipesProvider.notifier)
                            .fetchNextPage(),
                        child: const Text('\ub354 \ucc3e\uae30'),
                      )
                    : null,
              )
            else ...[
              for (final recipe in recipes) RecipeCard(recipe: recipe),
              if (state.hasMore && !state.hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: state.isLoading
                        ? const CircularProgressIndicator()
                        : TextButton(
                            onPressed: () => ref
                                .read(paginatedRecipesProvider.notifier)
                                .fetchNextPage(),
                            child: const Text(
                              '\ub354 \ubd88\ub7ec\uc624\uae30',
                            ),
                          ),
                  ),
                ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: userProfile.when(
        data: (profile) {
          if (profile?.role != 'admin') return null;
          return RecipeCreateAction(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddRecipePage()),
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (e, s) => const SizedBox.shrink(),
      ),
    );
  }
}

class RecipeSearchBar extends ConsumerStatefulWidget {
  const RecipeSearchBar({super.key});

  @override
  ConsumerState<RecipeSearchBar> createState() => _RecipeSearchBarState();
}

class _RecipeSearchBarState extends ConsumerState<RecipeSearchBar> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: TextField(
        onChanged: (query) {
          if (_debounce?.isActive ?? false) _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 500), () {
            ref.read(searchQueryProvider.notifier).update(query);
            ref.invalidate(paginatedRecipesProvider);
          });
        },
        decoration: InputDecoration(
          hintText: '레시피 검색',
          prefixIcon: const Icon(Icons.search, color: mediumGray),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class SortOptions extends ConsumerWidget {
  const SortOptions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSort = ref.watch(recipeSortProvider);
    final canMakeOnly = ref.watch(canMakeFilterProvider);

    final sortOptions = {
      '추천순': RecipeSortType.recommended,
      '전체 탐색 · 인기순': RecipeSortType.popular,
      '전체 탐색 · 최신순': RecipeSortType.recent,
    };

    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in sortOptions.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.key),
                      selected: selectedSort == entry.value,
                      selectedColor: primaryGreen,
                      backgroundColor: softGreen,
                      showCheckmark: false,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      labelStyle: TextStyle(
                        color: selectedSort == entry.value
                            ? Colors.white
                            : darkGray,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          ref
                              .read(recipeSortProvider.notifier)
                              .update(entry.value);
                          ref.invalidate(paginatedRecipesProvider);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (selectedSort == RecipeSortType.recommended)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              shape: const Border(),
              collapsedShape: const Border(),
              title: const Text(
                '\ucd94\ucc9c \uae30\uc900',
                style: TextStyle(fontSize: 12, color: mediumGray),
              ),
              children: const [
                Text(
                  '\ubcf4\uc720 \uc7ac\ub8cc \ube44\uc728\uacfc \ubcf4\uc720 \ubbf8\ud655\uc778 \uc218\ub97c \uba3c\uc800 \ubd10\uc694. \uac19\uc740 \uacc4\uc815\uc774\uba74 \ud655\uc778\ub41c \uc774\ubc88 \uc8fc \uc2dd\uc0ac \uae30\ub85d\uacfc 3\uc77c \uc774\ub0b4 \uc7ac\ub8cc\ub97c \ubc18\uc601\ud574\uc694.',
                  style: TextStyle(
                    fontSize: 12,
                    color: mediumGray,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '재료 이름이 모두 일치하는 요리',
              style: TextStyle(fontSize: 14),
            ),
            value: canMakeOnly,
            onChanged: (value) {
              ref.read(canMakeFilterProvider.notifier).update(value);
            },
          ),
        ],
      ),
    );
  }
}

class RecipeCard extends ConsumerWidget {
  final Recipe recipe;
  const RecipeCard({super.key, required this.recipe, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredients = ref.watch(ingredientsProvider);
    final availability = IngredientAvailability(
      recipe.requiredIngredients,
      ref.watch(usableIngredientNamesProvider),
    );
    final inventoryReady = !ingredients.isLoading && !ingredients.hasError;
    final hasAllIngredients =
        inventoryReady &&
        recipe.eligibleForRecommendation &&
        availability.canMake;
    final image = recipe.originalVideo == null ? recipe.imageUrl : null;
    final photo = recipe.originalVideo == null ? recipePhotoFor(recipe) : null;
    final examplePhoto = recipe.originalVideo == null
        ? recipeExamplePhotoFor(recipe)
        : null;
    final hasCover = RecipeCover(
      imageUrl: image,
      photo: photo,
      examplePhoto: examplePhoto,
    ).hasSources;

    void openRecipe() => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecipeDetailPage(recipe: recipe)),
    );

    return Semantics(
      button: true,
      onTap: openRecipe,
      label: '${recipe.name} \ub808\uc2dc\ud53c \uc0c1\uc138 \uc5f4\uae30',
      child: Card(
        key: const ValueKey('menu-editorial-card'),
        margin: const EdgeInsets.only(bottom: 20),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          excludeFromSemantics: true,
          onTap: openRecipe,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasCover)
                SizedBox(
                  key: const ValueKey('menu-recipe-cover'),
                  height: compact ? 140 : 190,
                  child: RecipeCover(
                    imageUrl: image,
                    photo: photo,
                    examplePhoto: examplePhoto,
                    label: '${recipe.name} \uc774\ubbf8\uc9c0',
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            recipe.name,
                            key: const ValueKey('menu-recipe-title'),
                            style: TextStyle(
                              color: darkGray,
                              fontSize: compact ? 19 : 22,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              letterSpacing: -.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(
                            Icons.arrow_outward_rounded,
                            color: primaryGreen,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                    if (recipe.displayDescription.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        recipePreviewText(recipe.displayDescription),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: mediumGray,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (inventoryReady &&
                        recipe.recommendationHoldReason == null)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _MenuBadge(
                            '${availability.ownedIngredients.length} / ${availability.requiredIngredients.length} \uc7ac\ub8cc \ubcf4\uc720\uc911',
                            missing: false,
                          ),
                          if (availability.missingIngredients.isNotEmpty)
                            _MenuBadge(
                              '\ubcf4\uc720 \ubbf8\ud655\uc778 ${availability.missingIngredients.length}',
                              missing: true,
                            ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Icon(
                            hasAllIngredients
                                ? Icons.check_circle
                                : Icons.info_outline,
                            color: hasAllIngredients
                                ? primaryGreen
                                : warningInk,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ingredients.isLoading
                                  ? '\uc7ac\ub8cc \ud655\uc778 \uc911'
                                  : ingredients.hasError
                                  ? '\uc7ac\ub8cc \uc815\ubcf4\ub97c \ubd88\ub7ec\uc62c \uc218 \uc5c6\uc2b5\ub2c8\ub2e4.'
                                  : '\uc7ac\ub8cc \ubaa9\ub85d \ud655\uc778 \ud544\uc694',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    Text(
                      recipe.dataQualityNotice,
                      style: const TextStyle(
                        fontSize: 12,
                        color: mediumGray,
                        height: 1.5,
                      ),
                    ),
                    if (recipe.originalVideo != null) ...[
                      const SizedBox(height: 8),
                      const Text(
                        '\uc800\uc7a5\ub41c \uc74c\uc2dd \uc815\ubcf4 \u00b7 \ucc38\uace0 \uc601\uc0c1\uc740 \uc678\ubd80\uc5d0\uc11c \ubcf4\uae30',
                        style: TextStyle(
                          color: primaryGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (recipe.browsingContentWarning != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        recipe.browsingContentWarning!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (inventoryReady) ...[
                      const SizedBox(height: 8),
                      PantryMatchPanel(
                        availability: availability,
                        holdReason: recipe.recommendationHoldReason,
                      ),
                    ],
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

class _MenuBadge extends StatelessWidget {
  const _MenuBadge(this.label, {required this.missing});
  final String label;
  final bool missing;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: missing ? const Color(0xFFF3F3F3) : softGreen,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: missing ? warningInk : darkGray,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class RecipeCardSkeleton extends StatelessWidget {
  const RecipeCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 180, width: double.infinity, color: Colors.white),
          Padding(
            padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 20, width: 200, color: Colors.white),
                const SizedBox(height: 8),
                Container(
                  height: 16,
                  width: double.infinity,
                  color: Colors.white,
                ),
                const SizedBox(height: 4),
                Container(height: 16, width: 150, color: Colors.white),
                const SizedBox(height: 12),
                Container(height: 20, width: 180, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A separate layout region keeps the admin action clear of scrollable cards.
class RecipeCreateAction extends StatelessWidget {
  const RecipeCreateAction({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 8),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add),
        label: const Text('레시피 추가'),
      ),
    ),
  );
}
