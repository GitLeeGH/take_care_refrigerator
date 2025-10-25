import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../providers.dart';
import '../models.dart';
import '../theme.dart';
import 'add_recipe_page.dart';

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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const RecipeSearchBar(),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
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
        // We need to create a RecommendedRecipe object to pass to the card
        // This part is a bit of a hack because we don't have the recommendation details here
        // A better solution would be to refactor RecipeCard to not require it.
        final recommendedRecipe = RecommendedRecipe(
          recipe: recipe,
          ownedIngredientsCount: 0, // Placeholder
          requiredIngredientsCount: recipe.requiredIngredients.length,
          missingIngredients: [], // Placeholder
        );
        return RecipeCard(recommendedRecipe: recommendedRecipe);
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
          hintText: '레시피 검색...',
          prefixIcon: const Icon(Icons.search, color: mediumGray),
          filled: true,
          fillColor: const Color(0xFFF1F3F5),
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

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: sortOptions.entries.map((entry) {
                  final isSelected = selectedSort == entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(entry.key),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          ref
                              .read(recipeSortProvider.notifier)
                              .update(entry.value);
                          // 정렬 변경 시 레시피 목록 provider 무효화
                          ref.invalidate(paginatedRecipesProvider);
                        }
                      },
                      selectedColor: primaryBlue.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: isSelected ? primaryBlue : darkGray,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? primaryBlue : Colors.grey[300]!,
                        ),
                      ),
                      backgroundColor: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const VerticalDivider(width: 16, indent: 8, endIndent: 8),
          Text(
            '만들 수 있는 요리만',
            style: TextStyle(
              fontSize: 12,
              color: canMakeOnly ? primaryBlue : mediumGray,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Switch(
            value: canMakeOnly,
            onChanged: (value) {
              ref.read(canMakeFilterProvider.notifier).update(value);
              ref.invalidate(paginatedRecipesProvider);
            },
            activeThumbColor: primaryBlue,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            trackOutlineWidth: WidgetStateProperty.all(0),
          ),
        ],
      ),
    );
  }
}

class RecipeCard extends ConsumerWidget {
  final RecommendedRecipe recommendedRecipe;
  const RecipeCard({super.key, required this.recommendedRecipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = recommendedRecipe.recipe;
    final ingredients = ref.watch(ingredientsProvider);

    // Calculate recommendation details on the fly for the card
    final ownedIngredientsCount = ingredients.when(
      data: (data) {
        final myIngredientNames = data.map((e) => e.name).toSet();
        return recipe.requiredIngredients
            .where((req) => myIngredientNames.contains(req))
            .length;
      },
      loading: () => 0,
      error: (_, __) => 0,
    );
    final hasAllIngredients =
        ownedIngredientsCount == recipe.requiredIngredients.length;

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              width: double.infinity,
              child: (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty)
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: recipe.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(
                            Icons.ramen_dining_outlined,
                            size: 60,
                            color: mediumGray,
                          ),
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.ramen_dining_outlined,
                        size: 60,
                        color: mediumGray,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
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
                  Text(
                    recipe.description ?? '',
                    style: const TextStyle(color: mediumGray, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        hasAllIngredients
                            ? Icons.check_circle
                            : Icons.error_outline,
                        color: hasAllIngredients
                            ? const Color(0xFF20C997)
                            : Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$ownedIngredientsCount / ${recipe.requiredIngredients.length} 재료 보유중',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecipeDetailPage extends ConsumerStatefulWidget {
  final Recipe recipe;
  const RecipeDetailPage({super.key, required this.recipe});

  @override
  ConsumerState<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends ConsumerState<RecipeDetailPage> {
  Future<void> _launchURL(Uri url) async {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // Could not launch the URL
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final userProfile = ref.watch(userProfileProvider);
    final likedIdsAsync = ref.watch(likedRecipeIdsProvider);
    final ingredientsAsync = ref.watch(ingredientsProvider);

    final hasYoutubeLink = recipe.youtubeVideoId?.isNotEmpty ?? false;
    final hasBlogLink = recipe.blogUrl?.isNotEmpty ?? false;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          recipe.name,
          style: const TextStyle(color: darkGray, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: darkGray),
        actions: [
          likedIdsAsync.when(
            data: (likedIds) {
              final isLiked = likedIds.contains(recipe.id);
              return IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.redAccent : mediumGray,
                ),
                onPressed: () async {
                  try {
                    await ref.read(likeRecipeProvider)(recipe.id, isLiked);
                  } catch (e) {
                    // 오류 처리
                  }
                },
              );
            },
            loading: () => const IconButton(
              icon: Icon(Icons.favorite_border, color: mediumGray),
              onPressed: null,
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          userProfile.when(
            data: (profile) {
              if (profile?.role == 'admin') {
                return IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    // We need to create a RecommendedRecipe object to pass to the edit page
                    final recommendedRecipe = RecommendedRecipe(
                      recipe: recipe,
                      ownedIngredientsCount: 0, // Placeholder
                      requiredIngredientsCount:
                          recipe.requiredIngredients.length,
                      missingIngredients: [], // Placeholder
                    );
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AddRecipePage(recipe: recipe),
                      ),
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (e, s) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty)
              GestureDetector(
                onTap: () => hasYoutubeLink
                    ? _launchURL(
                        Uri.parse(
                          'https://www.youtube.com/watch?v=${recipe.youtubeVideoId!}',
                        ),
                      )
                    : null,
                child: Container(
                  height: 220,
                  width: double.infinity,
                  color: Colors.black,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CachedNetworkImage(
                        imageUrl: recipe.imageUrl!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        color: hasYoutubeLink
                            ? Colors.black.withOpacity(0.3)
                            : null,
                        colorBlendMode: hasYoutubeLink
                            ? BlendMode.darken
                            : null,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Colors.grey[800]!,
                          highlightColor: Colors.grey[700]!,
                          child: Container(color: Colors.black),
                        ),
                        errorWidget: (context, url, error) =>
                            const SizedBox.shrink(),
                      ),
                      if (hasYoutubeLink)
                        const Icon(
                          Icons.play_circle_outline,
                          color: Colors.white70,
                          size: 70,
                        ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (recipe.description != null &&
                      recipe.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: MarkdownBody(data: recipe.description!),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    '필요한 재료',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ingredientsAsync.when(
                    data: (ingredients) {
                      final myIngredientNames = ingredients
                          .map((e) => e.name)
                          .toSet();
                      return Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: recipe.requiredIngredients.map((ing) {
                          final isOwned = myIngredientNames.contains(ing);
                          return Chip(
                            avatar: Icon(
                              isOwned
                                  ? Icons.check_circle
                                  : Icons.remove_circle_outline,
                              color: isOwned
                                  ? const Color(0xFF087F5B)
                                  : const Color(0xFFC62828),
                              size: 18,
                            ),
                            label: Text(ing),
                            backgroundColor: isOwned
                                ? const Color(0xFF20C997).withOpacity(0.1)
                                : const Color(0xFFE57373).withOpacity(0.1),
                            labelStyle: TextStyle(
                              color: isOwned
                                  ? const Color(0xFF087F5B)
                                  : const Color(0xFFC62828),
                              fontWeight: FontWeight.w500,
                            ),
                            side: BorderSide.none,
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const Text('재료 정보를 불러올 수 없습니다.'),
                  ),
                  const SizedBox(height: 24),
                  if (hasYoutubeLink)
                    ElevatedButton.icon(
                      onPressed: () => _launchURL(
                        Uri.parse(
                          'https://www.youtube.com/watch?v=${recipe.youtubeVideoId!}',
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow, color: Colors.white),
                      label: const Text(
                        '유튜브 영상 보러가기',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF0000),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  if (hasYoutubeLink && hasBlogLink) const SizedBox(height: 12),
                  if (hasBlogLink)
                    ElevatedButton.icon(
                      onPressed: () => _launchURL(Uri.parse(recipe.blogUrl!)),
                      icon: const Icon(
                        Icons.article_outlined,
                        color: Colors.white,
                      ),
                      label: const Text(
                        '블로그 레시피 보기',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF20C997),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 220, width: double.infinity, color: Colors.white),
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
