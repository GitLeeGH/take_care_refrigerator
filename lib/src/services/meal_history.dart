import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'curation_foundation.dart';
import 'curation_preferences.dart';

abstract class MealStorage {
  Future<void> activate(String? owner, String session) async {}
  Future<String?> read(String owner);
  Future<void> write(String owner, String value);
}

/// Android app-private AtomicFile, excluded from backup/transfer. No cloud sync.
/// Other platforms fail explicitly; there is no fallback to a shared account file.
class DeviceMealStorage extends MealStorage {
  static const channel = MethodChannel('refrigerator/meal_history');
  String? _owner;
  String? _session;
  @override
  Future<void> activate(String? owner, String session) async {
    _owner = owner;
    _session = session;
    await channel.invokeMethod<void>('activate', {
      'account': owner,
      'session': session,
    });
  }

  Map<String, Object?> args(String owner) {
    if (owner != _owner) throw StateError('Session changed');
    return {'account': owner, 'session': _session};
  }

  @override
  Future<String?> read(String owner) =>
      channel.invokeMethod<String>('read', args(owner));
  @override
  Future<void> write(String owner, String value) =>
      channel.invokeMethod<void>('write', {...args(owner), 'value': value});
}

class MealSnapshot {
  MealSnapshot(this.revision, Iterable<MealRecord> records)
    : records = List.unmodifiable(records);
  final int revision;
  final List<MealRecord> records;
  static MealSnapshot decode(String? raw, String owner) {
    if (raw == null) return MealSnapshot(0, []);
    if (raw.length > 512000) throw const FormatException('History too large');
    final data = jsonDecode(raw);
    if (data is! Map ||
        data['version'] != 1 ||
        data['owner'] != owner ||
        data['revision'] is! int ||
        data['revision'] < 0 ||
        data['records'] is! List ||
        data['records'].length > 1000) {
      throw const FormatException('Invalid history');
    }
    final ids = <String>{};
    final records = <MealRecord>[];
    for (final item in data['records']) {
      if (item is! Map ||
          item['id'] is! String ||
          item['name'] is! String ||
          item['year'] is! int ||
          item['month'] is! int ||
          item['day'] is! int ||
          !ids.add(item['id']) ||
          item['year'] < 1900 ||
          item['year'] > 9999) {
        throw const FormatException('Invalid meal');
      }
      records.add(
        MealRecord(
          id: item['id'],
          owner: owner,
          name: item['name'],
          day: MealDay(item['year'], item['month'], item['day']),
        ),
      );
    }
    return MealSnapshot(data['revision'], records);
  }

  String encode(String owner) => jsonEncode({
    'version': 1,
    'owner': owner,
    'revision': revision,
    'records': records
        .map(
          (r) => {
            'id': r.id,
            'name': r.name,
            'year': r.day.value.year,
            'month': r.day.value.month,
            'day': r.day.value.day,
          },
        )
        .toList(),
  });
}

class MealHistoryStore extends ChangeNotifier {
  MealHistoryStore(this.identity, this.storage) {
    _subscription = identity.changes.listen((_) => _reset());
    _reset();
  }
  final CurationIdentity identity;
  final MealStorage storage;
  late final StreamSubscription<void> _subscription;
  // Serialize every supported writer, including duplicate provider containers.
  static Future<void>? _tail;
  static int _nextStore = 0;
  final int _storeId = ++_nextStore;
  Future<bool> _activation = Future.value(false);
  int generation = 0;
  String? owner;
  MealSnapshot? snapshot;
  bool busy = false, failed = false, _disposed = false;
  void _reset() {
    generation++;
    owner = identity.account;
    _activation = storage
        .activate(owner, '$_storeId:$generation')
        .then((_) => true, onError: (Object _, StackTrace _) => false);
    snapshot = null;
    failed = false;
    busy = false;
    notifyListeners();
    if (owner != null) unawaited(load());
  }

  bool _current(String account, int epoch) =>
      !_disposed &&
      generation == epoch &&
      owner == account &&
      identity.account == account;
  void _check(String account, int epoch) {
    if (!_current(account, epoch)) throw StateError('Session changed');
  }

  Future<void> load() async {
    final account = owner;
    final epoch = generation;
    if (account == null || busy) return;
    busy = true;
    notifyListeners();
    try {
      if (!await _activation) throw StateError('Storage unavailable');
      if (_tail != null) await _tail;
      _check(account, epoch);
      final raw = await storage.read(account);
      _check(account, epoch);
      snapshot = MealSnapshot.decode(raw, account);
      failed = false;
    } catch (_) {
      if (_current(account, epoch)) {
        failed = true;
        snapshot = null;
      }
    } finally {
      if (_current(account, epoch)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> save({
    required String account,
    required int epoch,
    required int revision,
    required String name,
    required MealDay day,
    required MealDay today,
    String? id,
    bool delete = false,
  }) async {
    _check(account, epoch);
    if (busy || snapshot == null || failed) {
      throw StateError('History unavailable');
    }
    if (!delete && (day.compareTo(today) > 0 || day.value.year < 1900)) {
      throw const FormatException('Invalid meal date');
    }
    busy = true;
    notifyListeners();
    final before = _tail;
    final completion = Completer<void>();
    _tail = completion.future;
    try {
      if (before != null) await before;
      _check(account, epoch);
      final latest = MealSnapshot.decode(await storage.read(account), account);
      _check(account, epoch);
      if (latest.revision != revision) throw StateError('History conflict');
      final records = latest.records.toList();
      final index = id == null ? -1 : records.indexWhere((r) => r.id == id);
      if (id != null && index < 0) throw StateError('Record changed');
      if (delete) {
        if (index < 0) throw StateError('Missing record');
        records.removeAt(index);
      } else {
        final record = MealRecord(
          id:
              id ??
              List.generate(
                16,
                (_) => Random.secure()
                    .nextInt(256)
                    .toRadixString(16)
                    .padLeft(2, '0'),
              ).join(),
          owner: account,
          name: name.trim(),
          day: day,
        );
        if (index < 0) {
          records.add(record);
        } else {
          records[index] = record;
        }
      }
      final next = MealSnapshot(latest.revision + 1, records);
      final encoded = next.encode(account);
      MealSnapshot.decode(encoded, account);
      _check(account, epoch);
      await storage.write(account, encoded);
      _check(account, epoch);
      snapshot = next;
    } catch (_) {
      if (_current(account, epoch)) {
        failed = true;
        snapshot = null;
      }
      rethrow;
    } finally {
      if (identical(_tail, completion.future)) _tail = null;
      completion.complete();
      if (_current(account, epoch)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    generation++;
    _subscription.cancel();
    super.dispose();
  }
}

final mealHistoryProvider = Provider<MealHistoryStore>((ref) {
  final store = MealHistoryStore(
    ref.watch(curationIdentityProvider),
    DeviceMealStorage(),
  );
  ref.onDispose(store.dispose);
  return store;
});

/// Read-only same-account history for ranking. Loading/unavailable history is
/// neutral. An existing confirmed snapshot stays usable during refresh/save.
class MealRecommendationHistory {
  const MealRecommendationHistory([this.owner, this.snapshot]);
  final String? owner;
  final MealSnapshot? snapshot;
  List<MealRecord> get records => snapshot?.records ?? const [];

  @override
  bool operator ==(Object other) =>
      other is MealRecommendationHistory &&
      other.owner == owner &&
      identical(other.snapshot, snapshot);
  @override
  int get hashCode => Object.hash(owner, snapshot);
}

final mealRecommendationHistoryProvider =
    Provider.autoDispose<MealRecommendationHistory>((ref) {
      final store = ref.watch(mealHistoryProvider);
      void changed() => ref.invalidateSelf();
      store.addListener(changed);
      ref.onDispose(() => store.removeListener(changed));
      if (store.failed ||
          store.snapshot == null ||
          store.owner == null ||
          store.owner != store.identity.account) {
        return const MealRecommendationHistory();
      }
      return MealRecommendationHistory(store.owner, store.snapshot);
    });
