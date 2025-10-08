import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'services/notification_service.dart';

// Simple in-memory notification settings model
class NotificationSettings {
  final bool notificationsEnabled;
  final int daysBefore;

  NotificationSettings({
    required this.notificationsEnabled,
    required this.daysBefore,
  });

  NotificationSettings copyWith({
    bool? notificationsEnabled,
    int? daysBefore,
  }) =>
      NotificationSettings(
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        daysBefore: daysBefore ?? this.daysBefore,
      );
}

// =======================================================================
// Core Providers
// =======================================================================

final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final userProfileProvider = FutureProvider.autoDispose<UserProfile?>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  try {
    final response =
        await supabase.from('profiles').select('role').eq('id', user.id).single();
    final profileData = Map<String, dynamic>.from(response);
    profileData['id'] = user.id;
    return UserProfile.fromJson(profileData);
  } catch (e) {
    return UserProfile(id: user.id, role: 'user');
  }
});

final ingredientsProvider = StreamProvider.autoDispose<List<Ingredient>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return Stream.value([]);

  final controller = StreamController<List<Ingredient>>();
  final subscription = supabase
      .from('ingredients')
      .stream(primaryKey: ['id'])
      .eq('user_id', user.id)
      .order('expiry_date', ascending: true)
      .listen((data) {
    final ingredients =
        data.map((item) => Ingredient.fromJson(item)).toList();
    controller.add(ingredients);
  });

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

// =======================================================================
// Recipe Sorting and Pagination Providers
// =======================================================================

// --- UI State Providers ---
enum RecipeSortType { recommended, popular, recent }
final searchQueryProvider = StateProvider<String>((ref) => '');
final recipeSortProvider =
    StateProvider<RecipeSortType>((ref) => RecipeSortType.recommended);

// Provider for the 'can make only' filter
final canMakeFilterProvider = StateProvider<bool>((ref) => false);

// --- Data Fetching Providers for Recipe IDs ---

// 1. Recommended Sort (uses the new RPC function)
final recommendedIdsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final ingredientsAsync = ref.watch(ingredientsProvider);

  // Don't block; if ingredients are loading/error, proceed with an empty list for now.
  // The provider will re-run when ingredients are available.
  final ingredients = ingredientsAsync.asData?.value ?? [];
  final ingredientNames = ingredients.map((e) => e.name).toList();

  final response = await supabase.rpc(
    'get_recommended_recipes',
    params: {'p_user_ingredients': ingredientNames},
  );

  if (response == null) {
    return []; // Handle potential null response from RPC
  }

  // The RPC returns a list of objects like [{id: '...'}, {id: '...'}]
  return (response as List).map((item) => item['id'] as String).toList();
});

// 2. Popular Sort
final popularIdsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final searchQuery = ref.watch(searchQueryProvider);

  var query = supabase.from('recipes').select('id');

  if (searchQuery.isNotEmpty) {
    query = query.ilike('name', '%$searchQuery%');
  }

  final response = await query.order('like_count', ascending: false);
  return (response as List).map((item) => item['id'] as String).toList();
});

// 3. Recent Sort
final recentIdsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final searchQuery = ref.watch(searchQueryProvider);

  var query = supabase.from('recipes').select('id');

  if (searchQuery.isNotEmpty) {
    query = query.ilike('name', '%$searchQuery%');
  }

  final response = await query.order('created_at', ascending: false);
  return (response as List).map((item) => item['id'] as String).toList();
});

// --- Main Paginated Recipe Provider ---

// The State class for our notifier
@immutable
class PaginatedRecipesState {
  const PaginatedRecipesState({
    this.recipes = const [],
    this.isLoading = false,
    this.hasMore = true,
  });

  final List<Recipe> recipes;
  final bool hasMore;
  final bool isLoading;

  PaginatedRecipesState copyWith({
    List<Recipe>? recipes,
    bool? hasMore,
    bool? isLoading,
  }) {
    return PaginatedRecipesState(
      recipes: recipes ?? this.recipes,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// The Notifier
class PaginatedRecipesNotifier extends StateNotifier<PaginatedRecipesState> {
  PaginatedRecipesNotifier(this.ref) : super(const PaginatedRecipesState());

  final Ref ref;
  List<String> _sortedRecipeIds = [];
  int _page = 0;
  static const _pageSize = 10;

  Future<void> init() async {
    state = const PaginatedRecipesState(isLoading: true);
    try {
      final sortType = ref.read(recipeSortProvider);
      debugPrint('[Recipes] Initializing with sort type: $sortType');

      final idsFuture = switch (sortType) {
        RecipeSortType.recommended => ref.read(recommendedIdsProvider.future),
        RecipeSortType.popular => ref.read(popularIdsProvider.future),
        RecipeSortType.recent => ref.read(recentIdsProvider.future),
      };

      _sortedRecipeIds = await idsFuture;
      debugPrint('[Recipes] Total sorted recipe IDs fetched: ${_sortedRecipeIds.length}');

      _page = 0;
      // Reset state, and critically, set isLoading to false before calling fetchNextPage
      state = const PaginatedRecipesState(recipes: [], hasMore: true, isLoading: false);
      await fetchNextPage();
    } catch (e, s) {
      state = state.copyWith(isLoading: false, hasMore: false);
      debugPrint('[Recipes] Error during init: $e\n$s');
    }
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final from = _page * _pageSize;
      debugPrint('[Recipes] Attempting to fetch page: $_page');

      if (from >= _sortedRecipeIds.length) {
        debugPrint('[Recipes] No more pages to fetch. Reached end of ID list.');
        state = state.copyWith(isLoading: false, hasMore: false);
        return;
      }

      final to = from + _pageSize - 1;
      final idsToFetch = _sortedRecipeIds.sublist(from, 
        to + 1 > _sortedRecipeIds.length ? _sortedRecipeIds.length : to + 1
      );

      if (idsToFetch.isEmpty) {
        debugPrint('[Recipes] No IDs to fetch for page $_page. Setting hasMore to false.');
        state = state.copyWith(isLoading: false, hasMore: false);
        return;
      }
      
      debugPrint('[Recipes] Fetching page $_page with IDs: $idsToFetch');

      final response = await ref
          .read(supabaseProvider)
          .from('recipes')
          .select()
          .filter('id', 'in', idsToFetch);

      final newRecipes = (response as List).map((item) => Recipe.fromJson(item)).toList();
      debugPrint('[Recipes] Fetched ${newRecipes.length} recipe details for page $_page');

      // Preserve the sorted order from the ID list
      final orderedNewRecipes = idsToFetch
          .map((id) => newRecipes.firstWhere((recipe) => recipe.id == id, orElse: () => Recipe.fromJson({})))
          .where((r) => r.id.isNotEmpty)
          .toList();

      state = state.copyWith(
        recipes: [...state.recipes, ...orderedNewRecipes],
        hasMore: newRecipes.length >= _pageSize,
        isLoading: false,
      );
      _page++;
    } catch (e, s) {
      state = state.copyWith(isLoading: false, hasMore: false);
      debugPrint('[Recipes] Error during fetchNextPage: $e\n$s');
    }
  }
}

// The StateNotifierProvider
final paginatedRecipesProvider = StateNotifierProvider.autoDispose<
    PaginatedRecipesNotifier, PaginatedRecipesState>((ref) {
  final notifier = PaginatedRecipesNotifier(ref);

  // Call init when the provider is first created.
  notifier.init();

  // When sort type or search query changes, re-initialize the notifier.
  ref.listen(recipeSortProvider, (_, __) => notifier.init());
  ref.listen(searchQueryProvider, (_, __) {
    // We debounce this slightly to avoid re-initializing on every keystroke.
    // This is a simple debounce implementation.
    final timer = Timer(const Duration(milliseconds: 500), () {
      notifier.init();
    });
    ref.onDispose(() => timer.cancel());
  });

  return notifier;
});

// Provider to fetch shelf life data from Supabase
final shelfLifeDataProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase.from('shelf_life_data').select('name, days');

  final Map<String, int> shelfLifeMap = {
    for (var item in response)
      item['name'] as String: item['days'] as int,
  };

  return shelfLifeMap;
});

// Provider to get all recipes at once, for features that need the full list.
final allRecipesListProvider = FutureProvider.autoDispose<List<Recipe>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase.from('recipes').select();
  return (response as List).map((item) => Recipe.fromJson(item)).toList();
});

// Provider for recommending recipes based on expiring ingredients
final expiringIngredientsRecipesProvider = Provider.autoDispose<List<Recipe>>((ref) {
  final ingredientsValue = ref.watch(ingredientsProvider);
  final allRecipesValue = ref.watch(allRecipesListProvider);

  // Return empty list if either provider is not ready
  if (ingredientsValue.isLoading || allRecipesValue.isLoading || ingredientsValue.hasError || allRecipesValue.hasError) {
    return [];
  }

  final ingredients = ingredientsValue.asData!.value;
  final allRecipes = allRecipesValue.asData!.value;

  // Find ingredients expiring within 3 days
  final expiringIngredients = ingredients.where((i) =>
    !i.expiryDate.isBefore(DateTime.now()) && // Filter out already expired
    i.expiryDate.difference(DateTime.now()).inDays < 3
  ).toList();

  if (expiringIngredients.isEmpty) {
    return [];
  }

  final expiringIngredientNames = expiringIngredients.map((e) => e.name).toSet();

  // Find recipes that use at least one of the expiring ingredients
  final recommended = allRecipes.where((recipe) {
    final required = recipe.requiredIngredients.toSet();
    return required.intersection(expiringIngredientNames).isNotEmpty;
  }).toList();

  // Sort by the number of expiring ingredients used
  recommended.sort((a, b) {
    final aCount = a.requiredIngredients.toSet().intersection(expiringIngredientNames).length;
    final bCount = b.requiredIngredients.toSet().intersection(expiringIngredientNames).length;
    return bCount.compareTo(aCount);
  });

  return recommended;
});

// A final provider that applies the search query to the paginated list
final filteredPaginatedRecipesProvider = Provider.autoDispose<List<Recipe>>((ref) {
  final state = ref.watch(paginatedRecipesProvider);
  final searchQuery = ref.watch(searchQueryProvider);
  final sortType = ref.watch(recipeSortProvider);
  final canMakeOnly = ref.watch(canMakeFilterProvider);
  final ingredients = ref.watch(ingredientsProvider).asData?.value ?? [];
  final myIngredientNames = ingredients.map((e) => e.name).toSet();

  var recipes = state.recipes;

  // Apply "Can Make Only" filter first
  if (canMakeOnly) {
    recipes = recipes.where((recipe) {
      final required = recipe.requiredIngredients.toSet();
      return required.every((ingredient) => myIngredientNames.contains(ingredient));
    }).toList();
  }

  // Then, apply search query ONLY for the recommended sort, as others are pre-filtered.
  if (searchQuery.isNotEmpty && sortType == RecipeSortType.recommended) {
    recipes = recipes.where((r) {
      return r.name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();
  }

  return recipes;
});


// =======================================================================
// Other Providers (Likes, Notifications, etc.)
// =======================================================================

final likedRecipeIdsProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return Stream.value({});

  return supabase
      .from('recipe_likes')
      .stream(primaryKey: ['user_id', 'recipe_id'])
      .eq('user_id', user.id)
      .map((data) => data.map((row) => row['recipe_id'] as String).toSet());
});

// Provider to get the full Recipe objects for the liked recipes
final likedRecipesProvider = FutureProvider.autoDispose<List<Recipe>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final likedIds = ref.watch(likedRecipeIdsProvider).asData?.value;

  if (likedIds == null || likedIds.isEmpty) {
    return [];
  }

  final response = await supabase.from('recipes').select().filter('id', 'in', likedIds.toList());
  return (response as List).map((item) => Recipe.fromJson(item)).toList();
});

final likeRecipeProvider = Provider.autoDispose((ref) {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;

  Future<void> toggleLike(String recipeId, bool isLiked) async {
    if (user == null) return;

    if (isLiked) {
      await supabase
          .from('recipe_likes')
          .delete()
          .match({'user_id': user.id, 'recipe_id': recipeId});
    } else {
      await supabase
          .from('recipe_likes')
          .insert({'user_id': user.id, 'recipe_id': recipeId});
    }
    ref.invalidate(popularIdsProvider); // Invalidate to refetch sorted IDs
  }

  return toggleLike;
});

// Provider that creates and initializes the NotificationService
final notificationServiceProvider = FutureProvider<NotificationService>((ref) async {
  final service = NotificationService();
  await service.init();
  return service;
});


final notificationSchedulerProvider = Provider.autoDispose((ref) {
  // Notifications are not supported on web, so disable this provider.
  if (kIsWeb) return;

  // Depend on the service provider to ensure it's initialized
  final notificationServiceAsync = ref.watch(notificationServiceProvider);
  final ingredientsAsync = ref.watch(ingredientsProvider);
  final settings = ref.watch(notificationSettingsProvider);

  // Only schedule notifications if all dependencies are ready
  if (notificationServiceAsync.hasValue && ingredientsAsync.hasValue) {
    final notificationService = notificationServiceAsync.value!;
    final ingredients = ingredientsAsync.value!;

    if (settings.notificationsEnabled) {
      notificationService.cancelAllNotifications();
      for (final ingredient in ingredients) {
        final notificationDate =
            ingredient.expiryDate.subtract(Duration(days: settings.daysBefore));
        if (notificationDate.isAfter(DateTime.now())) {
          notificationService.scheduleNotification(
            id: ingredient.id.hashCode,
            title: '유통기한 임박 알림',
            body: '${ingredient.name}의 유통기한이 ${settings.daysBefore}일 남았습니다!',
            scheduledDate: notificationDate,
          );
        }
      }
    }
  }
});

class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  NotificationSettingsNotifier()
      : super(NotificationSettings(notificationsEnabled: true, daysBefore: 3));

  void toggleNotifications(bool enabled) =>
      state = state.copyWith(notificationsEnabled: enabled);
  void setDaysBefore(int days) => state = state.copyWith(daysBefore: days);
}

final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
  (ref,) {
    return NotificationSettingsNotifier();
  },
);
