/// Name-based availability only: quantities, substitutions and preparation
/// instructions cannot be inferred from the existing free-text fields.
String normalizeIngredientName(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

class IngredientAvailability {
  IngredientAvailability(
    Iterable<String> required,
    Iterable<String> inventory,
  ) {
    final owned = inventory.map(normalizeIngredientName).toSet()..remove('');
    final unique = <String, String>{};
    for (final name in required) {
      final key = normalizeIngredientName(name);
      if (key.isNotEmpty) unique.putIfAbsent(key, () => name.trim());
    }
    requiredIngredients = List.unmodifiable(unique.values);
    ownedIngredients = List.unmodifiable([
      for (final entry in unique.entries)
        if (owned.contains(entry.key)) entry.value,
    ]);
    missingIngredients = List.unmodifiable([
      for (final entry in unique.entries)
        if (!owned.contains(entry.key)) entry.value,
    ]);
  }

  late final List<String> requiredIngredients;
  late final List<String> ownedIngredients;
  late final List<String> missingIngredients;

  // Unknown/empty requirements must not be advertised as ready to cook.
  bool get canMake =>
      requiredIngredients.isNotEmpty && missingIngredients.isEmpty;
  bool owns(String name) => ownedIngredients.any(
    (owned) => normalizeIngredientName(owned) == normalizeIngredientName(name),
  );
}
