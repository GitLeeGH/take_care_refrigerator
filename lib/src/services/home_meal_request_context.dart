import 'home_meal_period.dart';

/// Coarse local meal context only. Never contributes to the pantry revision or
/// request allowance, and contains no precise time, date, location or timezone.
class HomeMealRequestContext {
  const HomeMealRequestContext(this.period);
  factory HomeMealRequestContext.at(DateTime local) =>
      HomeMealRequestContext(mealPeriodAt(local));
  final HomeMealPeriod period;
  String get wireValue => period.name;
  static HomeMealRequestContext? parse(Object? value) => switch (value) {
    'breakfast' => const HomeMealRequestContext(HomeMealPeriod.breakfast),
    'lunch' => const HomeMealRequestContext(HomeMealPeriod.lunch),
    'dinner' => const HomeMealRequestContext(HomeMealPeriod.dinner),
    _ => null,
  };
}
