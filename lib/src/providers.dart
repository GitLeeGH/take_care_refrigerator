import 'services/curation_preferences.dart';
import 'services/notification_preferences.dart';
import 'widgets/test_notification_card.dart';
import 'services/verify_reservation.dart';
import 'services/reminder_auth_boundary.dart';
import 'services/one_shot_expiry_reminder.dart';
import 'services/inventory_quantity.dart';
import 'services/calendar_day.dart';
import 'services/ingredient_stream.dart';
import 'services/inventory_day.dart';
import 'services/local_recipe_curation.dart';
import 'services/meal_history.dart';
import 'services/storage_reference.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'ingredient_matching.dart';
import 'services/notification_service.dart';

// 백그라운드에서 실행될 알림 콜백 (최상위 함수여야 함)
@pragma('vm:entry-point')
void _alarmCallback() {
  /* Legacy entry point: never emit or reschedule. */
}

// Simple in-memory notification settings model
enum NotificationSettingsPersistence {
  memoryOnly,
  saved,
  saving,
  loadFailed,
  writeFailed,
}

class NotificationSettings {
  final NotificationSettingsPersistence persistenceStatus;
  final bool notificationsEnabled;
  final int daysBefore;

  NotificationSettings({
    this.persistenceStatus = NotificationSettingsPersistence.memoryOnly,
    required this.notificationsEnabled,
    required this.daysBefore,
  });

  NotificationSettings copyWith({
    NotificationSettingsPersistence? persistenceStatus,
    bool? notificationsEnabled,
    int? daysBefore,
  }) => NotificationSettings(
    persistenceStatus: persistenceStatus ?? this.persistenceStatus,
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
    final now = ref.read(inventoryClockProvider)();
    final newNotifications = <NotificationItem>[];

    for (final ingredient in ingredients) {
      if (isExplicitlyEmptyQuantity(ingredient.quantity)) continue;
      final daysLeft = calendarDayDifference(ingredient.expiryDate, now);

      if (daysLeft <= 3) {
        final NotificationPriority priority;
        final String title;
        final String message;

        if (daysLeft <= 0) {
          priority = NotificationPriority.urgent;
          title = daysLeft == 0 ? '오늘까지인 재료' : '🚨 유통기한 초과!';
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

// Disabled until the additive remote migration and RLS checks are confirmed.
final storageReferencesEnabledProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment(
    'ENABLE_STORAGE_REFERENCES',
    defaultValue: false,
  ),
);
final storageReferenceGatewayProvider = Provider<StorageReferenceGateway>(
  (ref) => SupabaseStorageReferenceGateway(ref.watch(supabaseProvider)),
);
final storedStorageReferencesProvider =
    FutureProvider.autoDispose<List<StoredStorageReference>>((ref) async {
      if (!ref.watch(storageReferencesEnabledProvider)) return [];
      final client = ref.watch(supabaseProvider);
      final uid = client.auth.currentUser?.id;
      if (uid == null) return [];
      final subscription = client.auth.onAuthStateChange.listen((_) {
        if (client.auth.currentUser?.id != uid) ref.invalidateSelf();
      });
      ref.onDispose(subscription.cancel);
      return ref.watch(storageReferenceGatewayProvider).read();
    });

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

  // Keep errors visible until a new snapshot or an explicit user retry.
  return accountIngredientStream(
    supabase
        .from('ingredients')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('expiry_date', ascending: true),
    user.id,
    () => supabase.auth.currentUser?.id,
  );
}, retry: (_, _) => null);

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

// One eligibility rule for recommendations, filters and displayed matches.
final usableIngredientNamesProvider = Provider.autoDispose<List<String>>((ref) {
  final inventory = ref.watch(ingredientsProvider);
  if (inventory.isLoading || inventory.hasError) return [];
  return usableInventoryNames(
    inventory.asData?.value ?? [],
    ref.watch(inventoryDayProvider),
  );
});

final recipeMatchesFiltersProvider =
    Provider.autoDispose<bool Function(Recipe)>((ref) {
      final query = ref.watch(searchQueryProvider).toLowerCase();
      final sort = ref.watch(recipeSortProvider);
      final canMakeOnly = ref.watch(canMakeFilterProvider);
      final names = ref.watch(usableIngredientNamesProvider);
      return (recipe) =>
          (sort == RecipeSortType.recommended || canMakeOnly
              ? recipe.eligibleForRecommendation
              : recipe.eligibleForBrowsing) &&
          (!canMakeOnly ||
              IngredientAvailability(
                recipe.requiredIngredients,
                names,
              ).canMake) &&
          (sort != RecipeSortType.recommended ||
              query.isEmpty ||
              recipe.name.toLowerCase().contains(query));
    });

// Injectable read-only boundary; pagination tests exercise the real notifier.
final recipeDetailsLoaderProvider =
    Provider<Future<List<Recipe>> Function(List<String>)>((ref) {
      final client = ref.watch(supabaseProvider);
      return (ids) async {
        final response = await client
            .from('recipes')
            .select()
            .filter('id', 'in', ids);
        return (response as List).map((item) => Recipe.fromJson(item)).toList();
      };
    });

// --- Data Fetching Providers for Recipe IDs ---

const recipeReadTimeout = Duration(seconds: 30);

// 1. Shared pantry ranking with optional, account-scoped meal history.
final recommendedIdsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final preferencesFuture = ref.watch(activeCurationPreferencesProvider.future);
  final inventory = ref.watch(ingredientsProvider);
  if (inventory.isLoading || inventory.hasError) return [];
  final now = ref.watch(inventoryDayProvider);
  final ingredients = inventory.asData?.value ?? <Ingredient>[];
  if (usableInventoryNames(ingredients, now).isEmpty) return [];
  final history = ref.watch(mealRecommendationHistoryProvider);
  // Reuse the read-only catalog; a history change must not fetch it again.
  final recipes = await ref.watch(allRecipesListProvider.future);
  final preferences = await preferencesFuture;
  return curateLocalRecipes(
    recipes: recipes,
    inventory: ingredients,
    now: now,
    preferred: localPreferenceNames(preferences.preferred),
    avoided: localPreferenceNames(preferences.avoided),
    prioritizeExpiring: preferences.prioritizeExpiring,
    mealOwner: history.owner,
    meals: history.records,
  ).map((match) => match.recipe.id).toList();
}, retry: (_, _) => null);

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
    this.hasError = false,
    this.scannedCount = 0,
  });

  final List<Recipe> recipes;
  final bool hasMore;
  final bool isLoading;
  final bool hasError;
  final int scannedCount;

  PaginatedRecipesState copyWith({
    List<Recipe>? recipes,
    bool? hasMore,
    bool? isLoading,
    bool? hasError,
    int? scannedCount,
  }) {
    return PaginatedRecipesState(
      recipes: recipes ?? this.recipes,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      scannedCount: scannedCount ?? this.scannedCount,
    );
  }
}

// The Notifier
class PaginatedRecipesNotifier extends Notifier<PaginatedRecipesState> {
  List<String> _sortedRecipeIds = [];
  int _nextIndex = 0;
  int _generation = 0;
  static const _pageSize = 10;
  // One user action can scan at most 30 IDs in three sequential requests.
  static const _maxPagesPerAction = 3;

  @override
  PaginatedRecipesState build() {
    final inventory = ref.watch(ingredientsProvider);
    ref.watch(recipeMatchesFiltersProvider);
    // Any dependency change invalidates pending reads before the next frame.
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    final recommended =
        ref.watch(recipeSortProvider) == RecipeSortType.recommended;
    // Future identity changes when ranking inputs change, not on completion.
    // Invalidate pagination for new history without a fetch loop.
    if (recommended) ref.watch(recommendedIdsProvider.future);
    final needsInventory = ref.watch(canMakeFilterProvider) || recommended;
    if (inventory.isLoading && needsInventory) {
      return const PaginatedRecipesState(isLoading: true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.mounted && generation == _generation) init();
    });
    return const PaginatedRecipesState();
  }

  bool _current(int generation) => ref.mounted && generation == _generation;

  Future<void> init() async {
    final generation = ++_generation;
    _sortedRecipeIds = [];
    _nextIndex = 0;
    state = const PaginatedRecipesState(isLoading: true);
    try {
      final sort = ref.read(recipeSortProvider);
      if (sort == RecipeSortType.recommended ||
          ref.read(canMakeFilterProvider)) {
        if (ref.read(ingredientsProvider).isLoading) {
          await ref.read(ingredientsProvider.future);
          if (!_current(generation)) return;
        }
        if (ref.read(ingredientsProvider).hasError) {
          state = const PaginatedRecipesState(hasMore: false, hasError: true);
          return;
        }
      }
      final ids = await (switch (sort) {
        RecipeSortType.recommended => ref.read(recommendedIdsProvider.future),
        RecipeSortType.popular => ref.read(popularIdsProvider.future),
        RecipeSortType.recent => ref.read(recentIdsProvider.future),
      }).timeout(recipeReadTimeout);
      if (!_current(generation)) return;
      _sortedRecipeIds = List.of(ids);
      state = PaginatedRecipesState(hasMore: ids.isNotEmpty);
      await fetchNextPage();
    } catch (_) {
      if (!_current(generation)) return;
      state = state.copyWith(isLoading: false, hasMore: false, hasError: true);
    }
  }

  // A user refresh must invalidate IDs as well as fetch fresh detail rows.
  Future<void> refresh() async {
    ref.invalidate(recommendedIdsProvider);
    ref.invalidate(popularIdsProvider);
    ref.invalidate(recentIdsProvider);
    ref.invalidate(allRecipesListProvider);
    await init();
  }

  Future<void> retry() async {
    if (state.isLoading) return;
    if (_sortedRecipeIds.isEmpty) {
      // A failed or timed-out FutureProvider may still retain its old future.
      await refresh();
    } else {
      await fetchNextPage();
    }
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || !state.hasMore) return;
    final generation = _generation;
    final matches = ref.read(recipeMatchesFiltersProvider);
    state = state.copyWith(isLoading: true, hasError: false);
    try {
      final load = ref.read(recipeDetailsLoaderProvider);
      var requests = 0;
      while (_nextIndex < _sortedRecipeIds.length &&
          requests < _maxPagesPerAction) {
        requests++;
        final end = (_nextIndex + _pageSize).clamp(0, _sortedRecipeIds.length);
        final ids = _sortedRecipeIds.sublist(_nextIndex, end);
        final rows = await load(ids).timeout(recipeReadTimeout);
        if (!_current(generation)) return;
        final byId = {for (final recipe in rows) recipe.id: recipe};
        final ordered = [
          for (final id in ids)
            if (byId[id] != null) byId[id]!,
        ];
        _nextIndex = end;
        state = state.copyWith(
          recipes: [...state.recipes, ...ordered],
          // Missing/deleted detail rows do not consume the remaining ID pages.
          hasMore: _nextIndex < _sortedRecipeIds.length,
          scannedCount: _nextIndex,
        );
        // A filtered-out or entirely missing page must not strand the user.
        if (ordered.any(matches) || !state.hasMore) break;
      }
      state = state.copyWith(
        isLoading: false,
        hasMore: _nextIndex < _sortedRecipeIds.length,
      );
    } catch (_) {
      if (!_current(generation)) return;
      // Retry the failed slice, preserving completed scans and visible cards.
      state = state.copyWith(
        isLoading: false,
        hasMore: _nextIndex < _sortedRecipeIds.length,
        hasError: true,
      );
    }
  }
}

// The NotifierProvider
final paginatedRecipesProvider =
    NotifierProvider.autoDispose<
      PaginatedRecipesNotifier,
      PaginatedRecipesState
    >(PaginatedRecipesNotifier.new);

// Legacy shelf_life_data.days has no provenance or storage conditions.
// Do not expose it as an expiry/default-date provider.

// Provider to get all recipes at once, for features that need the full list.
final allRecipesListProvider = FutureProvider.autoDispose<List<Recipe>>((
  ref,
) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('recipes')
      .select()
      .timeout(recipeReadTimeout);
  return (response as List).map((item) => Recipe.fromJson(item)).toList();
}, retry: (_, _) => null);

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

  final now = ref.watch(inventoryDayProvider);
  if (expiringInventoryNames(ingredients, now).isEmpty) return [];
  // Home still requires an actual expiring match, but ranks using the entire
  // usable pantry. One expiring seasoning must not outrank a near-complete meal.
  final matches = curateLocalRecipes(
    recipes: allRecipes,
    inventory: ingredients,
    now: now,
  ).where((match) => match.expiring.isNotEmpty).toList();
  if (matches.isEmpty) return [];
  final history = ref.watch(mealRecommendationHistoryProvider);
  return curateLocalRecipes(
    recipes: matches.map((match) => match.recipe),
    inventory: ingredients,
    now: now,
    mealOwner: history.owner,
    meals: history.records,
  ).map((match) => match.recipe).toList();
});

// A final provider that applies the search query to the paginated list
final filteredPaginatedRecipesProvider = Provider.autoDispose<List<Recipe>>((
  ref,
) {
  final state = ref.watch(paginatedRecipesProvider);
  final matches = ref.watch(recipeMatchesFiltersProvider);
  return state.recipes.where(matches).toList();
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
    if (user == null) {
      return;
    }

    try {
      if (isLiked) {
        await supabase.from('recipe_likes').delete().match({
          'user_id': user.id,
          'recipe_id': recipeId,
        });
      } else {
        await supabase.from('recipe_likes').insert({
          'user_id': user.id,
          'recipe_id': recipeId,
        });
      }

      // 좋아요 변경 후 모든 관련 provider 무효화
      ref.invalidate(likedRecipeIdsProvider); // 좋아요한 레시피 ID 목록 갱신
      ref.invalidate(likedRecipesProvider); // 좋아요한 레시피 상세 정보 갱신
      ref.invalidate(popularIdsProvider); // 인기순 레시피 재조회
      ref.invalidate(paginatedRecipesProvider); // 페이지네이션 레시피 재조회
    } catch (e) {
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

final oneShotReminderProvider = Provider<OneShotExpiryReminder>(
  (ref) => OneShotExpiryReminder.instance,
);

final notificationCleanupProvider = Provider<Future<bool> Function()>(
  (ref) => () async {
    final reminder = ref.read(oneShotReminderProvider);
    var ledgerCleared = true;
    try {
      await invalidateReminderSession(includeLocal: false);
    } catch (_) {
      ledgerCleared = false;
    }
    await reminder.cancel(needsRebooking: true);
    await explicitTestReminder.cancel();
    final legacyCleared = await NotificationService()
        .cancelLegacyNotifications();
    return ledgerCleared && legacyCleared;
  },
);

final notificationSchedulerProvider = Provider.autoDispose((ref) {
  // Rebuilding an AsyncValue or refreshing an unchanged list is not a mutation.
  // Initial process/auth cleanup happens separately, not on every stream emission.
  ref.listen(notificationSettingsProvider, (previous, next) {
    if (previous != null &&
        (previous.notificationsEnabled != next.notificationsEnabled ||
            previous.daysBefore != next.daysBefore)) {
      ref.read(notificationCleanupProvider)();
    }
  });
  ref.listen(ingredientsProvider, (previous, next) {
    String? identity(AsyncValue<List<Ingredient>>? value) =>
        value == null || value.isLoading || value.hasError || !value.hasValue
        ? null
        : reminderInventoryIdentity(value.value!);
    final reminder = ref.read(oneShotReminderProvider);
    if (reminder.recoveryPending && next.hasError) {
      ref.read(notificationCleanupProvider)();
    } else if (reminder.recoveryPending && identity(next) != null) {
      final client = ref.read(supabaseProvider);
      final owner = client.auth.currentUser?.id;
      final captured = identity(next)!;
      final settings = ref.read(notificationSettingsProvider);
      var alive = true;
      ref.onDispose(() => alive = false);
      reminder.recover(
        verify: () =>
            verifyReservation(client, owner ?? '', settings.daysBefore),
        stillValid: () =>
            alive &&
            client.auth.currentUser?.id == owner &&
            owner != null &&
            identity(ref.read(ingredientsProvider)) == captured &&
            ref.read(notificationSettingsProvider).notificationsEnabled &&
            settings.notificationsEnabled &&
            ref.read(notificationSettingsProvider).daysBefore ==
                settings.daysBefore,
      );
    } else if (identity(previous) != identity(next)) {
      ref.read(notificationCleanupProvider)();
    }
  });
});

final notificationPreferencesStoreProvider =
    Provider<NotificationPreferencesStore?>((ref) => null);
final notificationPreferencesAccountProvider = Provider<String?>((ref) => null);

class NotificationSettingsNotifier extends Notifier<NotificationSettings> {
  int _revision = 0;
  @override
  NotificationSettings build() {
    _revision++;
    final store = ref.watch(notificationPreferencesStoreProvider);
    final owner = ref.watch(notificationPreferencesAccountProvider);
    return _load(store, owner);
  }

  NotificationSettings _load(
    NotificationPreferencesStore? store,
    String? owner,
  ) {
    if (store == null || owner == null) {
      return NotificationSettings(notificationsEnabled: true, daysBefore: 3);
    }
    try {
      final value = store.load(owner);
      return NotificationSettings(
        notificationsEnabled: value.enabled,
        daysBefore: value.daysBefore,
        persistenceStatus: NotificationSettingsPersistence.saved,
      );
    } catch (_) {
      // A failed load must not briefly enable reminders that the user disabled.
      return NotificationSettings(
        notificationsEnabled: false,
        daysBefore: 3,
        persistenceStatus: NotificationSettingsPersistence.loadFailed,
      );
    }
  }

  void toggleNotifications(bool enabled) {
    state = state.copyWith(notificationsEnabled: enabled);
    if (!enabled) ref.read(notificationCleanupProvider)();
    unawaited(_persist());
  }

  void setDaysBefore(int days) {
    if (!const {1, 3, 7}.contains(days))
      throw ArgumentError.value(days, 'days');
    state = state.copyWith(daysBefore: days);
    unawaited(_persist());
  }

  Future<void> retryPersistence() async {
    if (state.persistenceStatus == NotificationSettingsPersistence.loadFailed) {
      _revision++;
      final store = ref.read(notificationPreferencesStoreProvider);
      final owner = ref.read(notificationPreferencesAccountProvider);
      if (store != null && owner != null) store.forgetFailedLoad(owner);
      state = _load(store, owner);
      return;
    }
    await _persist();
  }

  Future<void> _persist() async {
    final revision = ++_revision;
    final store = ref.read(notificationPreferencesStoreProvider);
    final owner = ref.read(notificationPreferencesAccountProvider);
    if (store == null || owner == null) {
      state = state.copyWith(
        persistenceStatus: NotificationSettingsPersistence.memoryOnly,
      );
      return;
    }
    final value = InAppNotificationPreferences(
      enabled: state.notificationsEnabled,
      daysBefore: state.daysBefore,
    );
    state = state.copyWith(
      persistenceStatus: NotificationSettingsPersistence.saving,
    );
    try {
      await store.save(owner, value);
      if (ref.mounted && revision == _revision) {
        state = state.copyWith(
          persistenceStatus: NotificationSettingsPersistence.saved,
        );
      }
    } catch (_) {
      if (ref.mounted && revision == _revision) {
        state = state.copyWith(
          persistenceStatus: NotificationSettingsPersistence.writeFailed,
        );
      }
    }
  }
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
      ref.watch(inventoryDayProvider);
      final now = ref.watch(inventoryClockProvider)();

      final settings = ref.watch(notificationSettingsProvider);
      if (!settings.notificationsEnabled ||
          ingredientsAsync.isLoading ||
          ingredientsAsync.hasError ||
          !ingredientsAsync.hasValue) {
        return [];
      }

      final ingredients = ingredientsAsync.value!;
      final notifications = <NotificationItem>[];

      for (final ingredient in ingredients) {
        if (isExplicitlyEmptyQuantity(ingredient.quantity)) continue;
        final daysLeft = calendarDayDifference(ingredient.expiryDate, now);
        final noticeId =
            'expiry:${ingredient.id}:${ingredient.expiryDate.year}-${ingredient.expiryDate.month}-${ingredient.expiryDate.day}:${now.year}-${now.month}-${now.day}';

        if (daysLeft <= settings.daysBefore) {
          // 삭제된 알림이면 스킵
          if (dismissedIds.contains(noticeId)) {
            continue;
          }

          final NotificationPriority priority;
          final String title;
          final String message;

          if (daysLeft <= 0) {
            priority = NotificationPriority.urgent;
            title = daysLeft == 0 ? '오늘까지인 재료' : '🚨 유통기한 초과!';
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
              id: noticeId,
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

      final references =
          ref.watch(storedStorageReferencesProvider).asData?.value ??
          const <StoredStorageReference>[];
      if (settings.notificationsEnabled) {
        final owned = {for (final item in ingredients) item.id: item};
        for (final reference in references) {
          final item = owned[reference.ingredientId];
          if (item == null ||
              isExplicitlyEmptyQuantity(item.quantity) ||
              item.storageType != 'refrigerated' ||
              !reference.active) {
            continue;
          }
          final days = reference.daysLeft(now);
          final noticeId =
              '${reference.notificationId}:${now.year}-${now.month}-${now.day}';
          if (days > settings.daysBefore || dismissedIds.contains(noticeId)) {
            continue;
          }
          notifications.add(
            NotificationItem(
              id: noticeId,
              title: '먼저 먹기 참고 알림',
              message: reference.notificationBody(item.name),
              createdAt: now,
              ingredientId: item.id,
              daysLeft: days,
              priority: NotificationPriority.info,
            ),
          );
        }
      }

      return notifications;
    });

// Read-only accessor, not a cached identity. Tests do not need an auth client.
final currentSessionUserProvider = Provider<User? Function()>((ref) {
  final client = ref.watch(supabaseProvider);
  return () => client.auth.currentUser;
});
