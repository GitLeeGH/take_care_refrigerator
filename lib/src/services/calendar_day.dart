/// Difference between displayed calendar dates, independent of DST day length.
/// Rebuild UTC from fields; do NOT convert the instants with toUtc(), which could
/// change the date. No stored dates or timestamps are rewritten.
int calendarDayDifference(DateTime target, DateTime reference) =>
    DateTime.utc(target.year, target.month, target.day)
        .difference(
          DateTime.utc(reference.year, reference.month, reference.day),
        )
        .inDays;

int compareCalendarDates(DateTime a, DateTime b) => calendarDayDifference(a, b);

/// Next wall-clock occurrence. A timezone-aware constructor can be supplied
/// by tests; production uses the device's local DateTime constructor.
DateTime nextCalendarHour(
  DateTime now,
  int hour, {
  DateTime Function(int, int, int, int)? construct,
}) {
  final make =
      construct ?? (int y, int m, int d, int h) => DateTime(y, m, d, h);
  final today = make(now.year, now.month, now.day, hour);
  return now.isBefore(today)
      ? today
      : make(now.year, now.month, now.day + 1, hour);
}
