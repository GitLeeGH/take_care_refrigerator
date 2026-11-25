import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models.dart';
import 'inventory_quantity.dart';

/// Only calendar dates leave this layer. No names, quantities, IDs or credentials.
List<String> localExpiryDates(List<Ingredient> inventory) {
  if (inventory.length > 500)
    throw const FormatException('Inventory too large');
  final dates = <String>{};
  for (final item in inventory) {
    if (isExplicitlyEmptyQuantity(item.quantity)) continue;
    final d = item.expiryDate;
    dates.add(
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
    );
  }
  return dates.toList()..sort();
}

List<String> localExpiryDatesFromRows(
  List<Map<String, dynamic>> rows,
  String owner,
) {
  if (rows.length > 500) throw const FormatException('Incomplete inventory');
  final dates = <String>{}, ids = <String>{};
  for (final row in rows) {
    if (row['user_id'] != owner ||
        row['id'] is! String ||
        !ids.add(row['id'] as String) ||
        row['quantity'] is! String ||
        !row.containsKey('expiry_date'))
      throw const FormatException('Invalid inventory');
    if (isExplicitlyEmptyQuantity(row['quantity'] as String)) continue;
    final raw = row['expiry_date'];
    if (raw == null) continue;
    if (raw is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw))
      throw const FormatException('Invalid expiry');
    final d = DateTime.tryParse(raw);
    if (d == null ||
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}' !=
            raw)
      throw const FormatException('Invalid expiry');
    dates.add(raw);
  }
  return dates.toList()..sort();
}

abstract class LocalExpiryPlatform {
  bool get supported;
  Future<bool> requestPermission();
  Future<dynamic> call(String method, Map<String, dynamic> arguments);
}

class NativeLocalExpiryPlatform implements LocalExpiryPlatform {
  static const channel = MethodChannel('refrigerator/local_expiry_v1');
  @override
  bool get supported => !kIsWeb && Platform.isAndroid;
  @override
  Future<dynamic> call(String method, Map<String, dynamic> arguments) => channel
      .invokeMethod<dynamic>(method, arguments)
      .timeout(const Duration(seconds: 8));
  @override
  Future<bool> requestPermission() async {
    if (!supported) return false;
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return android != null &&
        (await android.areNotificationsEnabled() == true ||
            await android.requestNotificationsPermission() == true);
  }
}

Future<void> invalidateLocalExpiryReminders() async {
  final platform = NativeLocalExpiryPlatform();
  if (platform.supported) await platform.call('invalidate', {});
}

/// Called before changing existing inventory. Consent survives, stale dates do not.
Future<void> suspendLocalExpiryReminders(String owner) async {
  final platform = NativeLocalExpiryPlatform();
  if (platform.supported) await platform.call('suspend', {'owner': owner});
}

final localExpiryMutationEvents = ValueNotifier<int>(0);
final _mutationEpochs = <String, int>{};
final _mutationCounts = <String, int>{};
int localExpiryMutationEpoch(String owner) => _mutationEpochs[owner] ?? 0;
bool localExpiryMutationInProgress(String owner) =>
    (_mutationCounts[owner] ?? 0) > 0;

Future<T> guardLocalExpiryInventoryMutation<T>(
  String owner,
  Future<T> Function() mutation,
) async {
  _mutationEpochs[owner] = localExpiryMutationEpoch(owner) + 1;
  _mutationCounts[owner] = (_mutationCounts[owner] ?? 0) + 1;
  try {
    await suspendLocalExpiryReminders(owner);
    return await mutation();
  } finally {
    _mutationEpochs[owner] = localExpiryMutationEpoch(owner) + 1;
    _mutationCounts[owner] = (_mutationCounts[owner] ?? 1) - 1;
    localExpiryMutationEvents.value++;
  }
}

class LocalExpiryState {
  const LocalExpiryState({
    this.enabled = false,
    this.days = 3,
    this.revision = '',
    this.generation,
    this.nextAt,
    this.updatedAt,
    this.permission = false,
  });
  final bool enabled, permission;
  final int days;
  final String revision;
  final String? generation;
  final DateTime? nextAt, updatedAt;
  factory LocalExpiryState.fromMap(dynamic value) {
    if (value is! Map ||
        value['enabled'] is! bool ||
        value['revision'] is! String ||
        ![1, 3, 7].contains(value['days']))
      throw const FormatException('Invalid reminder state');
    DateTime? date(String key) => value[key] is int
        ? DateTime.fromMillisecondsSinceEpoch(value[key] as int)
        : null;
    return LocalExpiryState(
      enabled: value['enabled'] as bool,
      days: value['days'] as int,
      revision: value['revision'] as String,
      generation: value['generation'] as String?,
      nextAt: date('nextAt'),
      updatedAt: date('updatedAt'),
      permission: value['permission'] == true,
    );
  }
}

class LocalExpiryController extends ChangeNotifier {
  LocalExpiryController(this.platform);
  final LocalExpiryPlatform platform;
  LocalExpiryState state = const LocalExpiryState();
  bool loaded = false, busy = false, _disposed = false;
  String? error;
  DateTime? testDue;
  String? _owner, _lastDates;
  Future<void> _tail = Future.value();
  int _sequence = 0;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _queue(Future<void> Function() work) {
    if (_disposed || !platform.supported) {
      loaded = true;
      return Future.value();
    }
    final job = _tail.then((_) async {
      if (_disposed) return;
      busy = true;
      error = null;
      _notify();
      try {
        await work();
      } catch (_) {
        error = '알림 상태를 확인하지 못했어요. 다시 확인해 주세요.';
      } finally {
        busy = false;
        _notify();
      }
    });
    _tail = job.catchError((Object _) {});
    return job;
  }

  void _accept(dynamic value, String owner) {
    if (_disposed) return;
    state = LocalExpiryState.fromMap(value);
    loaded = true;
    _owner = owner;
  }

  void reportFailure() {
    error = '최신 재료를 확인하지 못했어요. 연결을 확인하고 다시 시도해 주세요.';
    _notify();
  }

  Future<void> refresh(String owner) => _queue(() async {
    _accept(await platform.call('read', {'owner': owner}), owner);
  });
  Future<void> sync({
    required String owner,
    required List<String> dates,
    required bool Function() current,
  }) {
    final sequence = ++_sequence;
    return _queue(() async {
      if (!current() || sequence != _sequence) return;
      // Refresh the durable lease: an edit may have suspended its snapshot.
      _accept(await platform.call('read', {'owner': owner}), owner);
      if (!current() ||
          sequence != _sequence ||
          !state.enabled ||
          state.generation == null)
        return;
      final identity = '${state.generation}:${dates.join(',')}';
      if (_lastDates == identity && state.updatedAt != null) return;
      _accept(
        await platform.call('sync', {
          'owner': owner,
          'generation': state.generation,
          'dates': dates,
          'expectedRevision': state.revision,
        }),
        owner,
      );
      if (current() && sequence == _sequence) _lastDates = identity;
    });
  }

  Future<void> reconcile({
    required String owner,
    required Future<List<String>> Function() query,
    required bool Function() current,
  }) => _queue(() async {
    if (!current()) return;
    _accept(await platform.call('read', {'owner': owner}), owner);
    if (!current() || !state.enabled || state.generation == null) return;
    final revision = state.revision, generation = state.generation;
    final dates = await query();
    if (!current()) return;
    final identity = '$generation:${dates.join(',')}';
    if (_lastDates == identity && state.updatedAt != null) return;
    _accept(
      await platform.call('sync', {
        'owner': owner,
        'generation': generation,
        'dates': dates,
        'expectedRevision': revision,
      }),
      owner,
    );
    if (current()) _lastDates = identity;
  });
  Future<void> enable({
    required String owner,
    required String project,
    required int days,
    required List<String> dates,
    required bool Function() current,
  }) => _queue(() async {
    if (!current()) return;
    // CAS is captured before the permission prompt, preventing late reactivation.
    _accept(await platform.call('read', {'owner': owner}), owner);
    final revision = state.revision;
    if (!await platform.requestPermission()) {
      error = '휴대폰 알림 권한이 꺼져 있어요. 설정에서 허용해 주세요.';
      return;
    }
    if (!current()) return;
    _accept(
      await platform.call('enable', {
        'owner': owner,
        'project': project,
        'days': days,
        'dates': dates,
        'expectedRevision': revision,
      }),
      owner,
    );
    _lastDates = null;
  });
  Future<void> disable(String owner) => _queue(() async {
    ++_sequence;
    _accept(await platform.call('disable', {'owner': owner}), owner);
    _lastDates = null;
    testDue = null;
  });
  Future<void> test(String owner) => _queue(() async {
    if (!kDebugMode ||
        !state.enabled ||
        state.generation == null ||
        _owner != owner)
      return;
    final value = await platform.call('test', {
      'owner': owner,
      'generation': state.generation,
    });
    if (value is int)
      testDue = DateTime.fromMillisecondsSinceEpoch(value);
    else if (value is Map && value['dueAt'] is int)
      testDue = DateTime.fromMillisecondsSinceEpoch(value['dueAt'] as int);
    else
      throw const FormatException('Invalid test reservation');
  });
  @override
  void dispose() {
    _disposed = true;
    ++_sequence;
    super.dispose();
  }
}
