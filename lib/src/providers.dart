import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import 'models.dart';
import 'ingredient_matching.dart';
import 'services/notification_service.dart';

// 백그라운드에서 실행될 알림 콜백 (최상위 함수여야 함)
@pragma('vm:entry-point')
void _alarmCallback() async {
  print('🔔 백그라운드 알람 콜백 실행됨!');
  final notificationService = NotificationService();
  await notificationService.init();

  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now();
  final todayString =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final lastAlarmDate = prefs.getString('last_alarm_date');

  // 오늘 이미 알림을 보냈으면 스킵
  if (lastAlarmDate == todayString) {
    print('✅ 오늘 이미 알림 전송됨');
    return;
  }

  // 테스트 알림 표시
  await notificationService.showImmediateExpiryAlert('유통기한 확인', 0);
  await prefs.setString('last_alarm_date', todayString);
  print('✅ 백그라운드 알림 전송 완료');

  // 내일 9시에 다시 예약
  final tomorrow9AM = DateTime(now.year, now.month, now.day + 1, 9, 0, 0);
  await AndroidAlarmManager.oneShotAt(
    tomorrow9AM,
    0,
    _alarmCallback,
    exact: true,
    wakeup: true,
    rescheduleOnReboot: true,
  );
  print('✅ 내일 9시 알림 재예약 완료');
}

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
  }) => NotificationSettings(
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    daysBefore: daysBefore ?? this.daysBefore,
  );
}

// 알림 아이템 모델
class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final String ingredientId;
  final int daysLeft;
  final NotificationPriority priority;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.ingredientId,
    required this.daysLeft,
    required this.priority,
  });
}

enum NotificationPriority { urgent, warning, info }

// 알림 목록 상태 관리
class NotificationListNotifier extends Notifier<List<NotificationItem>> {
  @override
  List<NotificationItem> build() {
    return [];
  }

  void addNotification(NotificationItem notification) {
    state = [notification, ...state];
  }

  void removeNotification(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  void clearAllNotifications() {
    state = [];
  }

  void generateNotificationsFromIngredients(List<Ingredient> ingredients) {
    final now = DateTime.now();
    final newNotifications = <NotificationItem>[];

    for (final ingredient in ingredients) {
      final daysLeft = ingredient.expiryDate.difference(now).inDays;

      if (daysLeft <= 3) {
        final NotificationPriority priority;
        final String title;
        final String message;

        if (daysLeft <= 0) {
          priority = NotificationPriority.urgent;
          title = '🚨 유통기한 초과!';
          message = daysLeft == 0
              ? '${ingredient.name}의 유통기한이 오늘까지입니다'
              : '${ingredient.name}의 유통기한이 ${-daysLeft}일 지났습니다';
        } else if (daysLeft == 1) {
          priority = NotificationPriority.urgent;
          title = '🚨 유통기한 임박!';
          message = '${ingredient.name}의 유통기한이 내일까지입니다';
        } else {
          priority = NotificationPriority.warning;
          title = '⚠️ 유통기한 주의';
          message = '${ingredient.name}의 유통기한이 ${daysLeft}일 남았습니다';
        }

        // 이미 같은 재료에 대한 알림이 있는지 확인
        if (!state.any((n) => n.ingredientId == ingredient.id)) {
          newNotifications.add(
            NotificationItem(
              id: '${ingredient.id}_${DateTime.now().millisecondsSinceEpoch}',
              title: title,
              message: message,
              createdAt: now,
              ingredientId: ingredient.id,
              daysLeft: daysLeft,
              priority: priority,
            ),
          );
        }
      }
    }

    if (newNotifications.isNotEmpty) {
      state = [...newNotifications, ...state];
    }
  }
}

// =======================================================================
// Core Providers
// =======================================================================

final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final userProfileProvider = FutureProvider.autoDispose<UserProfile?>((
  ref,
) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  try {
    final response = await supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();
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
        final ingredients = data
            .map((item) => Ingredient.fromJson(item))
            .toList();
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

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) => state = query;
}

class RecipeSortNotifier extends Notifier<RecipeSortType> {
  @override
  RecipeSortType build() => RecipeSortType.recent;

  void update(RecipeSortType sort) => state = sort;
}

class CanMakeFilterNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void update(bool canMake) => state = canMake;
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);
final recipeSortProvider = NotifierProvider<RecipeSortNotifier, RecipeSortType>(
  RecipeSortNotifier.new,
);

// Provider for the 'can make only' filter
final canMakeFilterProvider = NotifierProvider<CanMakeFilterNotifier, bool>(
  CanMakeFilterNotifier.new,
);

// --- Data Fetching Providers for Recipe IDs ---

// 1. Recommended sort: rank by distinct owned ingredient names.
final recommendedIdsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final supabase = ref.watch(supabaseProvider);
  final ingredientsAsync = ref.watch(ingredientsProvider);

  // Recompute when inventory is available; do not use stale data on errors.
  if (ingredientsAsync.isLoading || ingredientsAsync.hasError) return [];
  final ingredients = ingredientsAsync.asData?.value ?? [];
  final ingredientNames = ingredients.map((e) => e.name).toList();

  if (ingredientNames.isEmpty) {
    return [];
  }

  try {
    // Step 1: Fetch all recipes
    final allRecipes = await supabase
        .from('recipes')
        .select()
        .then(
          (data) =>
              (data as List).map((item) => Recipe.fromJson(item)).toList(),
        );

    final availability = {
      for (final recipe in allRecipes)
        recipe.id: RecommendedRecipe.fromInventory(recipe, ingredientNames),
    };
    final filteredRecipes = allRecipes
        .where((recipe) => availability[recipe.id]!.ownedIngredientsCount > 0)
        .toList();
    filteredRecipes.sort(
      (a, b) => availability[b.id]!.ownedIngredientsCount.compareTo(
        availability[a.id]!.ownedIngredientsCount,
      ),
    );

    final result = filteredRecipes.map((r) => r.id).toList();
    return result;
  } catch (e) {
    return [];
  }
});

// 2. Popular Sort
final popularIdsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
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
class PaginatedRecipesNotifier extends Notifier<PaginatedRecipesState> {
  List<String> _sortedRecipeIds = [];
  int _page = 0;
  static const _pageSize = 10;

  @override
  PaginatedRecipesState build() {
    // 재료, 정렬 방식, 검색어, 필터가 변경되면 자동으로 재초기화
    ref.watch(ingredientsProvider);
    ref.watch(recipeSortProvider);
    ref.watch(searchQueryProvider);
    ref.watch(canMakeFilterProvider);

    // 초기화 시 init 호출
    WidgetsBinding.instance.addPostFrameCallback((_) => init());
    return const PaginatedRecipesState();
  }

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
      debugPrint(
        '[Recipes] Total sorted recipe IDs fetched: ${_sortedRecipeIds.length}',
      );

      _page = 0;
      // Reset state, and critically, set isLoading to false before calling fetchNextPage
      state = const PaginatedRecipesState(
        recipes: [],
        hasMore: true,
        isLoading: false,
      );
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
      final idsToFetch = _sortedRecipeIds.sublist(
        from,
        to + 1 > _sortedRecipeIds.length ? _sortedRecipeIds.length : to + 1,
      );

      if (idsToFetch.isEmpty) {
        debugPrint(
          '[Recipes] No IDs to fetch for page $_page. Setting hasMore to false.',
        );
        state = state.copyWith(isLoading: false, hasMore: false);
        return;
      }

      debugPrint('[Recipes] Fetching page $_page with IDs: $idsToFetch');

      final response = await ref
          .read(supabaseProvider)
          .from('recipes')
          .select()
          .filter('id', 'in', idsToFetch);

      final newRecipes = (response as List)
          .map((item) => Recipe.fromJson(item))
          .toList();
      debugPrint(
        '[Recipes] Fetched ${newRecipes.length} recipe details for page $_page',
      );

      // Preserve the sorted order from the ID list
      final orderedNewRecipes = idsToFetch
          .map(
            (id) => newRecipes.firstWhere(
              (recipe) => recipe.id == id,
              orElse: () => Recipe.fromJson({}),
            ),
          )
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

// The NotifierProvider
final paginatedRecipesProvider =
    NotifierProvider.autoDispose<
      PaginatedRecipesNotifier,
      PaginatedRecipesState
    >(PaginatedRecipesNotifier.new);

// Provider to fetch shelf life data from Supabase
final shelfLifeDataProvider = FutureProvider.autoDispose<Map<String, int>>((
  ref,
) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase.from('shelf_life_data').select('name, days');

  final Map<String, int> shelfLifeMap = {
    for (var item in response) item['name'] as String: item['days'] as int,
  };

  return shelfLifeMap;
});

// Provider to get all recipes at once, for features that need the full list.
final allRecipesListProvider = FutureProvider.autoDispose<List<Recipe>>((
  ref,
) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase.from('recipes').select();
  return (response as List).map((item) => Recipe.fromJson(item)).toList();
});

// Provider for recommending recipes based on expiring ingredients
final expiringIngredientsRecipesProvider = Provider.autoDispose<List<Recipe>>((
  ref,
) {
  final ingredientsValue = ref.watch(ingredientsProvider);
  final allRecipesValue = ref.watch(allRecipesListProvider);

  // Return empty list if either provider is not ready
  if (ingredientsValue.isLoading ||
      allRecipesValue.isLoading ||
      ingredientsValue.hasError ||
      allRecipesValue.hasError) {
    return [];
  }

  final ingredients = ingredientsValue.asData!.value;
  final allRecipes = allRecipesValue.asData!.value;

  // Find ingredients expiring within 3 days
  final expiringIngredients = ingredients
      .where(
        (i) =>
            !i.expiryDate.isBefore(
              DateTime.now(),
            ) && // Filter out already expired
            i.expiryDate.difference(DateTime.now()).inDays < 3,
      )
      .toList();

  if (expiringIngredients.isEmpty) {
    return [];
  }

  final expiringIngredientNames = expiringIngredients
      .map((e) => e.name)
      .toSet();

  final availability = {
    for (final recipe in allRecipes)
      recipe.id: IngredientAvailability(
        recipe.requiredIngredients,
        expiringIngredientNames,
      ),
  };
  final recommended = allRecipes
      .where((recipe) => availability[recipe.id]!.ownedIngredients.isNotEmpty)
      .toList();
  recommended.sort(
    (a, b) => availability[b.id]!.ownedIngredients.length.compareTo(
      availability[a.id]!.ownedIngredients.length,
    ),
  );

  return recommended;
});

// A final provider that applies the search query to the paginated list
final filteredPaginatedRecipesProvider = Provider.autoDispose<List<Recipe>>((
  ref,
) {
  final state = ref.watch(paginatedRecipesProvider);
  final searchQuery = ref.watch(searchQueryProvider);
  final sortType = ref.watch(recipeSortProvider);
  final canMakeOnly = ref.watch(canMakeFilterProvider);
  final inventory = ref.watch(ingredientsProvider);
  final ingredients = inventory.asData?.value ?? [];
  final myIngredientNames = ingredients.map((e) => e.name).toSet();

  var recipes = state.recipes;

  // Apply "Can Make Only" filter first
  if (canMakeOnly) {
    recipes = recipes
        .where(
          (recipe) =>
              !inventory.isLoading &&
              !inventory.hasError &&
              IngredientAvailability(
                recipe.requiredIngredients,
                myIngredientNames,
              ).canMake,
        )
        .toList();
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
final likedRecipesProvider = FutureProvider.autoDispose<List<Recipe>>((
  ref,
) async {
  final supabase = ref.watch(supabaseProvider);
  final likedIds = ref.watch(likedRecipeIdsProvider).asData?.value;

  if (likedIds == null || likedIds.isEmpty) {
    return [];
  }

  final response = await supabase
      .from('recipes')
      .select()
      .filter('id', 'in', likedIds.toList());
  return (response as List).map((item) => Recipe.fromJson(item)).toList();
});

final likeRecipeProvider = Provider((ref) {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;

  Future<void> toggleLike(String recipeId, bool isLiked) async {
    print(
      '[toggleLike] 함수 호출: recipeId=$recipeId, isLiked=$isLiked, userId=${user?.id}',
    );

    if (user == null) {
      print('[toggleLike] 사용자가 없습니다!');
      return;
    }

    try {
      if (isLiked) {
        print('[toggleLike] 좋아요 삭제 중...');
        await supabase.from('recipe_likes').delete().match({
          'user_id': user.id,
          'recipe_id': recipeId,
        });
        print('[toggleLike] 좋아요 삭제 완료');
      } else {
        print('[toggleLike] 좋아요 추가 중...');
        await supabase.from('recipe_likes').insert({
          'user_id': user.id,
          'recipe_id': recipeId,
        });
        print('[toggleLike] 좋아요 추가 완료');
      }

      // 좋아요 변경 후 모든 관련 provider 무효화
      print('[toggleLike] Provider 무효화 중...');
      ref.invalidate(likedRecipeIdsProvider); // 좋아요한 레시피 ID 목록 갱신
      ref.invalidate(likedRecipesProvider); // 좋아요한 레시피 상세 정보 갱신
      ref.invalidate(popularIdsProvider); // 인기순 레시피 재조회
      ref.invalidate(paginatedRecipesProvider); // 페이지네이션 레시피 재조회
      print('[toggleLike] Provider 무효화 완료!');
    } catch (e) {
      print('[toggleLike] 데이터베이스 오류: $e');
      rethrow;
    }
  }

  return toggleLike;
});

// Provider that creates and initializes the NotificationService (Singleton)
final notificationServiceProvider = FutureProvider<NotificationService>((
  ref,
) async {
  final service = NotificationService();
  if (!service.isInitialized) {
    await service.init();
  }
  return service;
});

final notificationSchedulerProvider = Provider.autoDispose((ref) {
  // 스케줄러 비활성화: 동적 알림(generatedNotificationsProvider)만 사용
  // 시스템 알림 중복 방지를 위해 초기 로그인 시에만 스케줄함
  if (kIsWeb) return;

  // Depend on the service provider to ensure it's initialized
  final notificationServiceAsync = ref.watch(notificationServiceProvider);
  final ingredientsAsync = ref.watch(ingredientsProvider);
  final settings = ref.watch(notificationSettingsProvider);

  print('📲 알림 스케줄러 실행 중...');
  print(
    '  - NotificationService: ${notificationServiceAsync.hasValue ? '준비됨' : '대기중'}',
  );
  print(
    '  - Ingredients: ${ingredientsAsync.hasValue ? '${ingredientsAsync.value?.length ?? 0}개' : '대기중'}',
  );
  print(
    '  - Settings: 알림=${settings.notificationsEnabled ? '활성화' : '비활성화'}, D-${settings.daysBefore}',
  );

  // Only schedule notifications if all dependencies are ready
  if (notificationServiceAsync.hasValue && ingredientsAsync.hasValue) {
    final ingredients = ingredientsAsync.value!;

    if (settings.notificationsEnabled && Platform.isAndroid) {
      // 매일 아침 9시에만 알림 스케줄
      final now = DateTime.now();

      // 오전 9시
      DateTime scheduleTime = DateTime(now.year, now.month, now.day, 9, 0, 0);

      print('⏰ 알림 예약 시간 설정: $scheduleTime (현재: $now)');

      // 만약 이미 설정 시간이 지났으면 내일 같은 시간으로 설정
      if (now.isAfter(scheduleTime)) {
        scheduleTime = scheduleTime.add(const Duration(days: 1));
      }

      // AndroidAlarmManager로 매일 9시에 알림 예약
      final alarmId = 0; // 고정 ID 사용
      AndroidAlarmManager.oneShotAt(
        scheduleTime,
        alarmId,
        _alarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      ).then((success) {
        if (success) {
          print('✅ AndroidAlarmManager 예약 성공: ${scheduleTime.toString()}');
          print('  - 총 재료: ${ingredients.length}개');
        } else {
          print('❌ AndroidAlarmManager 예약 실패');
        }
      });

      print('🔔 알림 스케줄링 완료!');
    } else {
      print('🔕 알림이 비활성화되어 있거나 Android가 아닙니다.');
    }
  } else {
    print('⏳ 알림 스케줄러 대기 중...');
    print(
      '  - NotificationService: ${notificationServiceAsync.hasValue ? '준비됨' : '로딩중'}',
    );
    print('  - Ingredients: ${ingredientsAsync.hasValue ? '준비됨' : '로딩중'}');
  }
});

class NotificationSettingsNotifier extends Notifier<NotificationSettings> {
  @override
  NotificationSettings build() {
    return NotificationSettings(notificationsEnabled: true, daysBefore: 3);
  }

  void toggleNotifications(bool enabled) =>
      state = state.copyWith(notificationsEnabled: enabled);
  void setDaysBefore(int days) => state = state.copyWith(daysBefore: days);
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
      NotificationSettingsNotifier.new,
    );

// 삭제된 알림을 관리하는 Provider
class DismissedNotificationsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void dismiss(String notificationId) {
    state = {...state, notificationId};
  }

  void dismissAll(List<String> notificationIds) {
    state = {...state, ...notificationIds};
  }

  void clearDismissed() {
    state = <String>{};
  }

  void removeDismissed(String notificationId) {
    state = {...state}..remove(notificationId);
  }
}

final dismissedNotificationsProvider =
    NotifierProvider<DismissedNotificationsNotifier, Set<String>>(
      DismissedNotificationsNotifier.new,
    );

final notificationListProvider =
    NotifierProvider<NotificationListNotifier, List<NotificationItem>>(
      NotificationListNotifier.new,
    );

// Provider to calculate notifications from ingredients (updates whenever ingredients change)
final generatedNotificationsProvider =
    Provider.autoDispose<List<NotificationItem>>((ref) {
      final ingredientsAsync = ref.watch(ingredientsProvider);
      final dismissedIds = ref.watch(dismissedNotificationsProvider);
      final now = DateTime.now();

      if (!ingredientsAsync.hasValue) {
        return [];
      }

      final ingredients = ingredientsAsync.value!;
      final notifications = <NotificationItem>[];

      print(
        '[generatedNotificationsProvider] 알림 동적 생성: ${ingredients.length}개 재료 확인',
      );

      for (final ingredient in ingredients) {
        final daysLeft = ingredient.expiryDate.difference(now).inDays;

        if (daysLeft <= 3) {
          // 삭제된 알림이면 스킵
          if (dismissedIds.contains(ingredient.id)) {
            continue;
          }

          final NotificationPriority priority;
          final String title;
          final String message;

          if (daysLeft <= 0) {
            priority = NotificationPriority.urgent;
            title = '🚨 유통기한 초과!';
            message = daysLeft == 0
                ? '${ingredient.name}의 유통기한이 오늘까지입니다'
                : '${ingredient.name}의 유통기한이 ${-daysLeft}일 지났습니다';
          } else if (daysLeft == 1) {
            priority = NotificationPriority.warning;
            title = '⚠️ 유통기한 임박!';
            message = '${ingredient.name}의 유통기한이 내일까지입니다';
          } else {
            priority = NotificationPriority.warning;
            title = '⚠️ 유통기한 임박!';
            message = '${ingredient.name}의 유통기한이 ${daysLeft}일 남았습니다';
          }

          notifications.add(
            NotificationItem(
              id: ingredient.id,
              title: title,
              message: message,
              createdAt: now,
              ingredientId: ingredient.id,
              daysLeft: daysLeft,
              priority: priority,
            ),
          );
        }
      }

      return notifications;
    });
