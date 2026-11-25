import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models.dart';
import '../ingredient_matching.dart';
import 'inventory_day.dart';

enum HomeMealPeriod { breakfast, lunch, dinner }

HomeMealPeriod mealPeriodAt(DateTime local) =>
    local.hour >= 5 && local.hour < 11
    ? HomeMealPeriod.breakfast
    : local.hour >= 11 && local.hour < 17
    ? HomeMealPeriod.lunch
    : HomeMealPeriod.dinner;
String mealPeriodLabel(HomeMealPeriod period) => switch (period) {
  HomeMealPeriod.breakfast => '아침',
  HomeMealPeriod.lunch => '점심',
  HomeMealPeriod.dinner => '저녁',
};

// Keep the strongest pantry/expiry/preference match first. Meal cues only
// reorder the remaining already-approved candidates, never create recipes.
List<Recipe> mealPeriodCandidates(List<Recipe> ranked, HomeMealPeriod period, {List<String> pantry = const []}) {
  if (ranked.length < 3) return List.of(ranked);
  final cues = switch (period) {
    HomeMealPeriod.breakfast => ['죽', '토스트', '샌드위치', '오트밀', '달걀', '계란'],
    HomeMealPeriod.lunch => ['덮밥', '볶음밥', '비빔밥', '면', '파스타', '돈까스'],
    HomeMealPeriod.dinner => ['찌개', '전골', '구이', '찜', '국', '볶음'],
  };
  final rest = ranked.skip(1).toList();
  final order = {for (var i = 0; i < rest.length; i++) rest[i].id: i};
  int score(Recipe r) => cues.any(r.name.contains) ? 1 : 0;
  rest.sort((a, b) {
    final aReady = IngredientAvailability(a.requiredIngredients, pantry).missingIngredients.isEmpty;
    final bReady = IngredientAvailability(b.requiredIngredients, pantry).missingIngredients.isEmpty;
    if(aReady != bReady) return aReady ? -1 : 1;
    final c = score(b).compareTo(score(a));
    return c != 0 ? c : order[a.id]!.compareTo(order[b.id]!);
  });
  return [ranked.first, ...rest];
}

final homeMealMomentProvider =
    NotifierProvider.autoDispose<HomeMealMoment, DateTime>(HomeMealMoment.new);

class HomeMealMoment extends Notifier<DateTime> with WidgetsBindingObserver {
  Timer? _timer;
  late DateTime Function() _clock;
  @override
  DateTime build() {
    _clock = ref.watch(inventoryClockProvider);
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _timer?.cancel();
      WidgetsBinding.instance.removeObserver(this);
    });
    final now = _clock();
    _schedule(now);
    return now;
  }

  void _schedule(DateTime now) {
    _timer?.cancel();
    final next = [
      DateTime(now.year, now.month, now.day, 5),
      DateTime(now.year, now.month, now.day, 11),
      DateTime(now.year, now.month, now.day, 17),
      DateTime(now.year, now.month, now.day + 1),
    ].firstWhere((d) => d.isAfter(now));
    _timer = Timer(next.difference(now), refresh);
  }

  void refresh() {
    if (!ref.mounted) return;
    final now = _clock();
    state = now;
    _schedule(now);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      refresh();
    } else {
      _timer?.cancel();
    }
  }
}
