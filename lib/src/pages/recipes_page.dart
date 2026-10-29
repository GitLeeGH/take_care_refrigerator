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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // The listener for the scroll controller to trigger pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.9) {
        ref.read(paginatedRecipesProvider.notifier).fetchNextPage();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);
    final recipesState = ref.watch(paginatedRecipesProvider);
    final filteredRecipes = ref.watch(filteredPaginatedRecipesProvider);

    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        title: const RecipeSearchBar(),
        backgroundColor: lightGray,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: '영상 레시피 미리보기',
            icon: const Icon(Icons.video_library_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const RecipeImportPage())),
          ),
        ],
      ),
      body: Column(
        children: [
          const SortOptions(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(paginatedRecipesProvider.notifier).init(),
              child: (recipesState.recipes.isEmpty && recipesState.isLoading)
                  ? _buildLoadingShimmer()
                  : _buildRecipeList(filteredRecipes, recipesState.hasMore),
            ),
          ),
        ],
      ),
      floatingActionButton: userProfile.when(
        data: (profile) {
          if (profile?.role == 'admin') {
            return FloatingActionButton(
              heroTag: UniqueKey(),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddRecipePage(),
                  ),
                );
              },
              backgroundColor: primaryBlue,
              child: const Icon(Icons.add, color: Colors.white),
            );
          }
          return null;
        },
        loading: () => const SizedBox.shrink(),
        error: (e, s) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => const RecipeCardSkeleton(),
      ),
    );
  }

  Widget _buildRecipeList(List<Recipe> recipes, bool hasMore) {
    if (recipes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 80, color: mediumGray),
              SizedBox(height: 24),
              Text(
                '레시피를 찾을 수 없어요',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkGray,
                ),
              ),
              SizedBox(height: 12),
              Text(
                '검색어를 확인하시거나\n다른 정렬을 시도해보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: mediumGray, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: recipes.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == recipes.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final recipe = recipes[index];
        return RecipeCard(recipe: recipe);
      },
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
    return SizedBox(
      height: 48,
      child: TextField(
        onChanged: (query) {
          if (_debounce?.isActive ?? false) _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 500), () {
            ref.read(searchQueryProvider.notifier).update(query);
            ref.invalidate(paginatedRecipesProvider);
          });
        },
        decoration: InputDecoration(
          hintText: '오늘은 무엇을 만들까요?',
          prefixIcon: const Icon(Icons.search, color: mediumGray),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
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
      '인기순': RecipeSortType.popular,
      '최신순': RecipeSortType.recent,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      selectedColor: softGreen,
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
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '보유 재료로 만들 수 있는 요리',
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
      (ingredients.asData?.value ?? <Ingredient>[]).map((e) => e.name),
    );
    final inventoryReady = !ingredients.isLoading && !ingredients.hasError;
    final hasAllIngredients = inventoryReady && availability.canMake;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeDetailPage(recipe: recipe),
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 20),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compact ? 12 : 24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: compact ? 132 : 180,
              width: double.infinity,
              child: RecipeCover(
                imageUrl: recipe.imageUrl,
                video: recipe.originalVideo,
                label: '${recipe.name} 이미지',
              ),
            ),
            Padding(
              padding: EdgeInsets.all(compact ? 10 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (recipe.originalVideo != null)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        '영상 레시피 · 원본 함께 보기',
                        style: TextStyle(
                          color: primaryGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (!compact)
                    Text(
                      recipe.displayDescription,
                      style: const TextStyle(color: mediumGray, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  SizedBox(height: compact ? 0 : 12),
                  Row(
                    children: [
                      Icon(
                        hasAllIngredients
                            ? Icons.check_circle
                            : Icons.error_outline,
                        color: hasAllIngredients ? primaryGreen : warningInk,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ingredients.isLoading
                              ? '재료 확인 중'
                              : ingredients.hasError
                              ? '재료 정보를 불러올 수 없습니다.'
                              : '${availability.ownedIngredients.length} / ${availability.requiredIngredients.length} 재료 보유중',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  if (inventoryReady && !compact) ...[
                    const SizedBox(height: 8),
                    Text(_ingredientSummary(availability)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecipeCardSkeleton extends StatelessWidget {
  const RecipeCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 180, width: double.infinity, color: Colors.white),
          Padding(
            padding: const EdgeInsets.all(16),
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

String _ingredientSummary(IngredientAvailability availability) {
  if (availability.requiredIngredients.isEmpty) return '등록된 재료 정보가 없습니다.';
  if (availability.canMake) return '모든 재료 보유 · 수량은 직접 확인해 주세요.';
  return '부족한 재료: ${availability.missingIngredients.join(', ')}';
}
