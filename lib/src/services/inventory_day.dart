import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final inventoryClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Shared local calendar day; no inventory records or dates are rewritten.
final inventoryDayProvider =
    NotifierProvider.autoDispose<InventoryDay, DateTime>(InventoryDay.new);

class InventoryDay extends Notifier<DateTime> with WidgetsBindingObserver {
  Timer? _timer;
  late DateTime Function() _now;

  DateTime _day(DateTime now) => DateTime(now.year, now.month, now.day);

  @override
  DateTime build() {
    _now = ref.watch(inventoryClockProvider);
    final now = _now();
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _timer?.cancel();
      WidgetsBinding.instance.removeObserver(this);
    });
    _schedule(now);
    return _day(now);
  }

  void _schedule(DateTime now) {
    _timer?.cancel();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _timer = Timer(tomorrow.difference(now), refresh);
  }

  void refresh() {
    if (!ref.mounted) return;
    final now = _now();
    final today = _day(now);
    if (today != state) state = today;
    _schedule(now);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Background timers can be suspended; also handles clock/timezone changes.
      refresh();
    } else {
      _timer?.cancel();
    }
  }
}
