/// Independent food curation domain. No video extraction, storage or networking.
/// Integrators must supply reviewed food data, never derive it from video metadata.
enum FoodDataPermission { unverified, independentlyAuthored, permitted }

class FoodCurationEvidence {
  const FoodCurationEvidence(
    this.permission,
    this.source,
    this.reviewReference,
  );
  final FoodDataPermission permission;
  final String source;
  final String reviewReference;
  bool get usable =>
      permission != FoodDataPermission.unverified &&
      source.trim().isNotEmpty &&
      reviewReference.trim().isNotEmpty;
}

/// Calendar date selected by the user; never shifted by a later time-zone change.
class MealDay implements Comparable<MealDay> {
  MealDay(int year, int month, int day)
    : value = DateTime.utc(year, month, day) {
    if (value.year != year || value.month != month || value.day != day) {
      throw const FormatException('Invalid meal date');
    }
  }
  final DateTime value;
  @override
  int compareTo(MealDay other) => value.compareTo(other.value);
  bool inWeekOf(MealDay today) {
    final monday = today.value.subtract(
      Duration(days: today.value.weekday - 1),
    );
    return !value.isBefore(monday) &&
        value.isBefore(monday.add(const Duration(days: 7)));
  }
}

String _mealName(String input) =>
    input.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// IDs refer to independently curated dishes, not recipe/video IDs.
/// Do not use ingredient aliases or substring matches for dish equivalence.
class MealRecord {
  MealRecord({
    required this.id,
    required this.owner,
    required this.name,
    required this.day,
    this.dishId,
  }) {
    if (id.trim().isEmpty ||
        owner.trim().isEmpty ||
        _mealName(name).isEmpty ||
        name.runes.length > 120 ||
        (dishId != null && dishId!.trim().isEmpty)) {
      throw const FormatException('Invalid meal record');
    }
  }
  final String id, owner, name;
  final String? dishId;
  final MealDay day;
}

/// Pure read projection. Empty history means no repetition information, not proof
/// that a meal has not been eaten. No auto-recording on video open or like.
bool eatenThisWeek({
  required String owner,
  required String name,
  String? dishId,
  required MealDay today,
  required Iterable<MealRecord> records,
}) {
  if (owner.trim().isEmpty || _mealName(name).isEmpty) return false;
  return records.any((record) {
    if (record.owner != owner ||
        record.day.compareTo(today) > 0 ||
        !record.day.inWeekOf(today)) {
      return false;
    }
    if (dishId != null && record.dishId != null) return dishId == record.dishId;
    return _mealName(name) == _mealName(record.name);
  });
}

/// Stable partition after existing safety/ingredient filtering. Previously eaten
/// dishes remain available explicitly, rather than returning a fake empty result.
class MealVariety<T> {
  MealVariety(Iterable<T> ranked, bool Function(T) repeated) {
    final fresh = <T>[], eaten = <T>[];
    for (final item in ranked) {
      (repeated(item) ? eaten : fresh).add(item);
    }
    suggestions = List.unmodifiable(fresh);
    eatenAgain = List.unmodifiable(eaten);
  }
  late final List<T> suggestions;
  late final List<T> eatenAgain;
}
