import 'curation_foundation.dart';
import 'inventory_quantity.dart';
import 'calendar_day.dart';
import '../ingredient_matching.dart';
import '../models.dart';

Set<String> localPreferenceNames(String value) => value
    .split(',')
    .map(normalizeIngredientName)
    .where((name) => name.isNotEmpty)
    .toSet();

/// Calendar-date eligibility only; this does not establish food safety.
/// Keep expired records in inventory, but exclude them from cooking matches.
List<String> usableInventoryNames(
  Iterable<Ingredient> inventory,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  return inventory
      .where((item) {
        if (isExplicitlyEmptyQuantity(item.quantity)) return false;
        final expiry = DateTime(
          item.expiryDate.year,
          item.expiryDate.month,
          item.expiryDate.day,
        );
        return calendarDayDifference(expiry, today) >= 0;
      })
      .map((item) => item.name)
      .toList();
}

List<String> expiringInventoryNames(
  Iterable<Ingredient> inventory,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  return inventory
      .where((item) {
        if (isExplicitlyEmptyQuantity(item.quantity)) return false;
        final expiry = DateTime(
          item.expiryDate.year,
          item.expiryDate.month,
          item.expiryDate.day,
        );
        final days = calendarDayDifference(expiry, today);
        return days >= 0 && days <= 3;
      })
      .map((item) => item.name)
      .toList();
}

class LocalRecipeMatch {
  const LocalRecipeMatch(
    this.recipe,
    this.availability,
    this.expiring,
    this.preferred, {
    this.repeatedThisWeek = false,
    this.earliestExpiryDays,
  });
  final Recipe recipe;
  final IngredientAvailability availability;
  final List<String> expiring;
  final List<String> preferred;
  final bool repeatedThisWeek;

  /// Earliest usable matched expiry within three days; not a safety guarantee.
  final int? earliestExpiryDays;
}

/// Pure local ranking of supplied records. No demographic inference, network,
/// persistence, ingredient substitutions or allergen-safety assertions.
List<LocalRecipeMatch> curateLocalRecipes({
  required Iterable<Recipe> recipes,
  required Iterable<Ingredient> inventory,
  required DateTime now,
  Set<String> preferred = const {},
  Set<String> avoided = const {},
  bool prioritizeExpiring = true,
  String? mealOwner,
  Iterable<MealRecord> meals = const [],
}) {
  final stock = inventory.toList();
  final names = usableInventoryNames(stock, now);
  final expiryBuckets = <int, List<String>>{
    for (var day = 0; day <= 3; day++) day: <String>[],
  };
  for (final item in stock) {
    if (isExplicitlyEmptyQuantity(item.quantity)) continue;
    final days = calendarDayDifference(item.expiryDate, now);
    expiryBuckets[days]?.add(item.name);
  }
  final soon = expiringInventoryNames(stock, now);
  final result = <LocalRecipeMatch>[];
  for (final recipe in uniqueRecommendationRecipes(recipes)) {
    if (!recipe.eligibleForRecommendation) continue;
    final availability = IngredientAvailability(
      recipe.requiredIngredients,
      names,
    );
    if (availability.ownedIngredients.isEmpty) continue;
    if (recipe.requiredIngredients.any(
      (name) => matchesAvoidedIngredient(name, avoided),
    )) {
      continue;
    }
    result.add(
      LocalRecipeMatch(
        recipe,
        availability,
        IngredientAvailability(
          recipe.requiredIngredients,
          soon,
        ).ownedIngredients,
        IngredientAvailability(
          recipe.requiredIngredients,
          preferred,
        ).ownedIngredients,
        earliestExpiryDays: [
          for (var day = 0; day <= 3; day++)
            if (IngredientAvailability(
              recipe.requiredIngredients,
              expiryBuckets[day]!,
            ).ownedIngredients.isNotEmpty)
              day,
        ].firstOrNull,
        repeatedThisWeek:
            mealOwner != null &&
            eatenThisWeek(
              owner: mealOwner,
              name: recipe.name,
              today: MealDay(now.year, now.month, now.day),
              records: meals,
            ),
      ),
    );
  }
  result.sort((a, b) {
    final pantry = compareIngredientAvailability(
      a.availability,
      b.availability,
    );
    if (pantry != 0) return pantry;
    // Coverage remains primary. Within equivalent matches, use today's stock
    // before less urgent ingredients, even when that meal was eaten recently.
    if (prioritizeExpiring) {
      final urgency = (a.earliestExpiryDays ?? 4).compareTo(
        b.earliestExpiryDays ?? 4,
      );
      if (urgency != 0) return urgency;
      final expiring = b.expiring.length.compareTo(a.expiring.length);
      if (expiring != 0) return expiring;
    }
    if (a.repeatedThisWeek != b.repeatedThisWeek) {
      return a.repeatedThisWeek ? 1 : -1;
    }
    final preference = b.preferred.length.compareTo(a.preferred.length);
    if (preference != 0) return preference;
    return a.recipe.id.compareTo(b.recipe.id);
  });
  return result;
}
