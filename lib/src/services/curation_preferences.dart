import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CurationPreferences {
  const CurationPreferences({
    this.preferred = '',
    this.avoided = '',
    this.prioritizeExpiring = true,
  });
  final String preferred;
  final String avoided;
  final bool prioritizeExpiring;

  String encode() => jsonEncode({
    'version': 1,
    'preferred': preferred,
    'avoided': avoided,
    'prioritizeExpiring': prioritizeExpiring,
  });

  factory CurationPreferences.decode(String source) {
    final value = jsonDecode(source);
    if (value is! Map ||
        value['version'] != 1 ||
        value['preferred'] is! String ||
        value['avoided'] is! String ||
        value['prioritizeExpiring'] is! bool ||
        (value['preferred'] as String).runes.length > 120 ||
        (value['avoided'] as String).runes.length > 120) {
      throw const FormatException('Invalid local preferences');
    }
    return CurationPreferences(
      preferred: value['preferred'] as String,
      avoided: value['avoided'] as String,
      prioritizeExpiring: value['prioritizeExpiring'] as bool,
    );
  }
}

abstract class CurationIdentity {
  String? get account;
  Stream<void> get changes;
}

class AuthCurationIdentity implements CurationIdentity {
  AuthCurationIdentity(this.client);
  final SupabaseClient client;
  @override
  String? get account => client.auth.currentUser?.id;
  @override
  Stream<void> get changes {
    var observed = account;
    return client.auth.onAuthStateChange
        .where((event) {
          final changed = observed != account;
          observed = account;
          // Preserve edits on ordinary token refresh, but never miss an identity
          // change carried by a different auth event or a same-account re-login.
          return changed ||
              event.event == AuthChangeEvent.signedIn ||
              event.event == AuthChangeEvent.signedOut;
        })
        .map((_) {});
  }
}

final curationIdentityProvider = Provider<CurationIdentity>((ref) {
  return AuthCurationIdentity(ref.watch(supabaseProvider));
});

/// Each request carries the captured identity and session generation. Auth changes
/// invalidate pending Dart work and queued native requests, never retarget them.
class CurationPreferenceStore {
  CurationPreferenceStore(this.identity) {
    _sync();
    _subscription = identity.changes.listen((_) => _sync(force: true));
  }
  static const channel = MethodChannel('refrigerator/curation_preferences');
  final _changes = StreamController<void>.broadcast(sync: true);
  Stream<void> get changes => _changes.stream;
  static int _nextStore = 0;
  final int _storeId = ++_nextStore;
  final CurationIdentity identity;
  late final StreamSubscription<void> _subscription;
  String? _account;
  int _generation = 0;
  bool _disposed = false;
  late Future<void> _activation;
  String get _session => '$_storeId:$_generation';

  void _sync({bool force = false}) {
    if (_disposed) return;
    if (!force && _generation != 0 && _account == identity.account) return;
    _account = identity.account;
    _generation++;
    _changes.add(null);
    // Capture failures without an unhandled async error before a UI request.
    _activation = channel
        .invokeMethod<void>('activate', {
          'account': _account,
          'session': _session,
        })
        .then((_) {}, onError: (Object error, StackTrace stack) {});
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _subscription.cancel();
    _changes.close();
  }

  Future<T?> _request<T>(
    String method,
    String expectedAccount, [
    String? value,
  ]) async {
    _sync();
    final account = _account;
    final generation = _generation;
    final session = _session;
    void check() {
      if (_disposed ||
          account == null ||
          account != identity.account ||
          account != expectedAccount ||
          generation != _generation) {
        throw StateError('Account changed or signed out');
      }
    }

    check();
    await _activation;
    check();
    final result = await channel.invokeMethod<T>(method, {
      'account': account,
      'session': session,
      if (value != null) 'value': value,
    });
    check();
    return result;
  }

  Future<CurationPreferences> load({required String account}) async {
    final value = await _request<String>('read', account);
    return value == null
        ? const CurationPreferences()
        : CurationPreferences.decode(value);
  }

  Future<void> save(
    CurationPreferences value, {
    required String account,
  }) async {
    final encoded = value.encode();
    CurationPreferences.decode(encoded);
    await _request<void>('write', account, encoded);
    _changes.add(null);
  }

  Future<void> delete({required String account}) async {
    await _request<void>('delete', account);
    _changes.add(null);
  }

  Future<void> deleteLegacy({required String account}) =>
      _request<void>('deleteLegacy', account);
}

final curationPreferenceStoreProvider = Provider<CurationPreferenceStore>((
  ref,
) {
  final store = CurationPreferenceStore(ref.watch(curationIdentityProvider));
  ref.onDispose(store.dispose);
  return store;
});

final activeCurationPreferencesProvider =
    FutureProvider.autoDispose<CurationPreferences>((ref) async {
      final store = ref.watch(curationPreferenceStoreProvider);
      final subscription = store.changes.listen((_) => ref.invalidateSelf());
      ref.onDispose(subscription.cancel);
      final account = store.identity.account;
      if (account == null) return const CurationPreferences();
      return store.load(account: account);
    }, retry: (_, _) => null);
