import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_variant.dart';
import '../providers.dart';
import 'receipt_ai_review.dart';
import 'receipt_import.dart';
import 'receipt_synthetic_pilot_fixture.dart';

// A local implementation, not authorization to enable or deploy this pilot.
// The normal receipt route and its feature flag are independent and unchanged.
const receiptSyntheticPilotRequestId = 'ffe859ee-d2d2-4f72-8ff8-cf3fea0ef3c1';
const receiptSyntheticPilotImageHash =
    'da7a9c033d1637a32df71656a3ef32fcac5b2dcc93e72a92a43bb5cd8525b589';
const receiptSyntheticPilotEndpoint =
    'https://brghwnwkfhbhamrrrqnr.supabase.co/functions/v1/receipt-single-pilot';

final receiptSyntheticPilotEnabledProvider = Provider<bool>(
  (_) =>
      isDevelopmentApp &&
      const bool.fromEnvironment('RECEIPT_SYNTHETIC_PILOT_ENABLED'),
);

class ReceiptPilotFailure implements Exception {
  const ReceiptPilotFailure(this.code);
  final String code;
  String get message => switch (code) {
    'disabled' => '합성 영수증 시험은 꺼져 있습니다.',
    'unauthenticated' => '유효한 로그인 상태에서 시험을 준비해 주세요.',
    'session_changed' => '로그인 상태가 바뀌어 준비와 동의를 취소했습니다.',
    'expired' => '시험 준비 시간이 만료되어 전송하지 않았습니다.',
    'attempted' => '이 시험의 전송 시도는 이미 사용되었습니다. 다시 보내지 않습니다.',
    'local_state' => '중복 방지 상태를 확인하거나 저장하지 못해 전송하지 않았습니다.',
    'invalid_fixture' => '고정 합성 사진을 확인하지 못해 시험을 중단했습니다.',
    'invalid_response' => '시험 응답을 확인하지 못했습니다. 다시 보내지 않습니다.',
    'consent_required' => '고정 합성 사진과 전송·비용 안내를 먼저 확인해 주세요.',
    'uncertain' => '응답을 확인하지 못했습니다. 비용이 발생했을 수 있어 다시 보내지 않습니다.',
    _ => '허용된 시험 준비를 확인하지 못했습니다. 전송하지 않았습니다.',
  };
  @override
  String toString() => 'ReceiptPilotFailure($code)';
}

/// Only these exact, already-sanitized synthetic bytes can enter this route.
/// This is not a photo picker or a general-purpose image review constructor.
final class ReceiptSyntheticPilotImage {
  ReceiptSyntheticPilotImage.fromBytes(Uint8List bytes)
    : _bytes = Uint8List.fromList(bytes) {
    if (_bytes.length != 26668 ||
        sha256.convert(_bytes).toString() != receiptSyntheticPilotImageHash) {
      throw const ReceiptPilotFailure('invalid_fixture');
    }
  }
  factory ReceiptSyntheticPilotImage.embedded() =>
      ReceiptSyntheticPilotImage.fromBytes(
        base64Decode(receiptSyntheticPilotPngBase64),
      );
  final Uint8List _bytes;
  Uint8List get bytes => Uint8List.fromList(_bytes);
  @override
  String toString() => 'ReceiptSyntheticPilotImage(pinned synthetic PNG)';
}

final receiptSyntheticPilotImageLoaderProvider =
    Provider<ReceiptSyntheticPilotImage Function()>(
      (_) => ReceiptSyntheticPilotImage.embedded,
    );

/// Local session identity only. No token is copied, decoded, printed or persisted
/// by this guard. The server's opaque readiness binding supplies server identity.
class ReceiptPilotSessionGuard extends ChangeNotifier {
  ReceiptPilotSessionGuard({
    required this.currentOwner,
    required this.currentSessionMarker,
    required this.sessionUsable,
  });
  final String? Function() currentOwner;
  final Object? Function() currentSessionMarker;
  final bool Function() sessionUsable;
  int _revision = 0;
  bool _disposed = false;
  void invalidate() {
    if (_disposed) return;
    _revision++;
    notifyListeners();
  }

  ReceiptPilotSessionSnapshot capture() {
    final owner = currentOwner();
    final marker = currentSessionMarker();
    if (_disposed ||
        owner == null ||
        owner.isEmpty ||
        marker == null ||
        !sessionUsable()) {
      throw const ReceiptPilotFailure('unauthenticated');
    }
    return ReceiptPilotSessionSnapshot._(owner, marker, _revision);
  }

  bool matches(ReceiptPilotSessionSnapshot snapshot) =>
      !_disposed &&
      sessionUsable() &&
      snapshot.owner == currentOwner() &&
      identical(snapshot._marker, currentSessionMarker()) &&
      snapshot._revision == _revision;

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    super.dispose();
  }
}

final class ReceiptPilotSessionSnapshot {
  ReceiptPilotSessionSnapshot._(this.owner, this._marker, this._revision);
  final String owner;
  final Object _marker;
  final int _revision;
  @override
  String toString() => 'ReceiptPilotSessionSnapshot(redacted)';
}

final receiptPilotSessionGuardProvider = Provider<ReceiptPilotSessionGuard>((
  ref,
) {
  final client = ref.watch(supabaseProvider);
  final guard = ReceiptPilotSessionGuard(
    currentOwner: () => client.auth.currentSession?.user.id,
    currentSessionMarker: () => client.auth.currentSession,
    sessionUsable: () {
      final expiry = client.auth.currentSession?.expiresAt;
      return expiry != null &&
          expiry > DateTime.now().millisecondsSinceEpoch ~/ 1000;
    },
  );
  // Even a same-owner refresh requires fresh readiness and consent for this
  // narrow pilot. Object identity also catches changes before async delivery.
  final subscription = client.auth.onAuthStateChange.listen((_) {
    guard.invalidate();
  }, onError: (Object _) => guard.invalidate());
  ref.onDispose(() {
    subscription.cancel();
    guard.dispose();
  });
  return guard;
});

/// This local latch improves UI safety. The server's atomic fixed-UUID grant is
/// still authoritative across devices, reinstall, restored backups and races.
abstract interface class ReceiptPilotAttemptStore {
  Future<bool> wasAttempted();
  Future<void> claim();
}

class SharedPreferencesReceiptPilotAttemptStore
    implements ReceiptPilotAttemptStore {
  static const key =
      'receipt.synthetic.pilot.$receiptSyntheticPilotRequestId.attempted';
  static bool _processClaimed = false;
  @override
  Future<bool> wasAttempted() async {
    if (_processClaimed) return true;
    try {
      final preferences = await SharedPreferences.getInstance();
      final attempted = preferences.getBool(key) ?? false;
      if (attempted) _processClaimed = true;
      return _processClaimed;
    } catch (_) {
      throw const ReceiptPilotFailure('local_state');
    }
  }

  @override
  Future<void> claim() async {
    if (_processClaimed) throw const ReceiptPilotFailure('attempted');
    // Set before the first await. Never release an uncertain/failed write.
    _processClaimed = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getBool(key) == true) {
        throw const ReceiptPilotFailure('attempted');
      }
      if (!await preferences.setBool(key, true)) {
        throw const ReceiptPilotFailure('local_state');
      }
    } on ReceiptPilotFailure {
      rethrow;
    } catch (_) {
      throw const ReceiptPilotFailure('local_state');
    }
  }
}

final receiptPilotAttemptStoreProvider = Provider<ReceiptPilotAttemptStore>(
  (_) => SharedPreferencesReceiptPilotAttemptStore(),
);

final class ReceiptPilotAdmission {
  ReceiptPilotAdmission._(this._owner, this._binding, this.expiresAt);
  final String _owner, _binding;
  final DateTime expiresAt;

  factory ReceiptPilotAdmission.fromResponse(
    Map<String, dynamic> value, {
    required String expectedOwner,
    required DateTime now,
  }) {
    const fields = {
      'ready',
      'reason',
      'monthly_limit_usd',
      'reservation_usd',
      'synthetic_only',
      'request_id',
      'input_revision',
      'owner_id',
      'binding',
      'expires_at',
    };
    final rawExpiry = value['expires_at'];
    final expiry = rawExpiry is String ? DateTime.tryParse(rawExpiry) : null;
    final binding = value['binding'];
    if (value.length != fields.length ||
        !value.keys.every(fields.contains) ||
        value['ready'] != true ||
        value['reason'] != 'ready' ||
        value['monthly_limit_usd'] != 10 ||
        value['reservation_usd'] != 0.6 ||
        value['synthetic_only'] != true ||
        value['request_id'] != receiptSyntheticPilotRequestId ||
        value['input_revision'] != receiptSyntheticPilotImageHash ||
        value['owner_id'] != expectedOwner ||
        expectedOwner.isEmpty ||
        binding is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(binding) ||
        rawExpiry is! String ||
        !rawExpiry.endsWith('Z') ||
        expiry == null ||
        !expiry.isUtc ||
        !expiry.isAfter(now.toUtc()) ||
        expiry.difference(now.toUtc()) > const Duration(minutes: 10)) {
      throw const ReceiptPilotFailure('invalid_response');
    }
    return ReceiptPilotAdmission._(expectedOwner, binding, expiry);
  }

  bool validFor(ReceiptPilotSessionSnapshot session, DateTime now) =>
      session.owner == _owner && now.toUtc().isBefore(expiresAt);
  @override
  String toString() => 'ReceiptPilotAdmission(redacted)';
}

final class ReceiptPilotDispatch {
  ReceiptPilotDispatch._({
    required this.image,
    required this.admission,
    required this.session,
    required this.stillCurrent,
    required this.consentedAt,
  });
  final ReceiptSyntheticPilotImage image;
  final ReceiptPilotAdmission admission;
  final ReceiptPilotSessionSnapshot session;
  final bool Function() stillCurrent;
  final DateTime consentedAt;
  @override
  String toString() => 'ReceiptPilotDispatch(redacted)';
}

abstract interface class ReceiptPilotGateway {
  Future<ReceiptPilotAdmission> checkReady({
    required ReceiptPilotSessionSnapshot session,
    required bool Function() stillCurrent,
  });
  Future<ReceiptParseResult> dispatch(ReceiptPilotDispatch request);
}

final receiptPilotGatewayProvider = Provider<ReceiptPilotGateway>((ref) {
  if (!ref.read(receiptSyntheticPilotEnabledProvider)) {
    throw const ReceiptPilotFailure('disabled');
  }
  final client = ref.watch(supabaseProvider);
  final url = Uri.tryParse(dotenv.env['SUPABASE_URL'] ?? '');
  if (url == null ||
      url.scheme != 'https' ||
      url.host != 'brghwnwkfhbhamrrrqnr.supabase.co' ||
      url.hasQuery ||
      url.hasFragment ||
      url.userInfo.isNotEmpty ||
      (url.path.isNotEmpty && url.path != '/') ||
      url.hasPort) {
    throw const ReceiptPilotFailure('not_ready');
  }
  return SupabaseReceiptPilotGateway(
    publishableKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    accessToken: () => client.auth.currentSession?.accessToken,
  );
});

class SupabaseReceiptPilotGateway implements ReceiptPilotGateway {
  SupabaseReceiptPilotGateway({
    required this.publishableKey,
    required this.accessToken,
    http.Client Function()? clientFactory,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 50),
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _clock = clock ?? DateTime.now;
  final String publishableKey;
  final String? Function() accessToken;
  final http.Client Function() _clientFactory;
  final DateTime Function() _clock;
  final Duration timeout;
  bool _dispatched = false;

  Future<Map<String, dynamic>> _call(
    String method, {
    required bool Function() stillCurrent,
    Map<String, Object?>? body,
    String? binding,
  }) async {
    http.Client? client;
    final elapsed = Stopwatch()..start();
    try {
      if (!stillCurrent()) throw const ReceiptPilotFailure('session_changed');
      final token = accessToken();
      if (token == null || token.isEmpty || publishableKey.isEmpty) {
        throw const ReceiptPilotFailure('unauthenticated');
      }
      if (!stillCurrent()) throw const ReceiptPilotFailure('session_changed');
      final request =
          http.Request(method, Uri.parse(receiptSyntheticPilotEndpoint))
            ..followRedirects = false
            ..maxRedirects = 0
            ..headers.addAll({
              'Authorization': 'Bearer $token',
              'apikey': publishableKey,
              'Accept': 'application/json',
              if (binding != null) 'X-Receipt-Pilot-Binding': binding,
            });
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      client = _clientFactory();
      final response = await client.send(request).timeout(timeout);
      final remaining = timeout - elapsed.elapsed;
      if (remaining <= Duration.zero) throw TimeoutException('pilot deadline');
      final bytes = <int>[];
      await (() async {
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 128 * 1024) {
            throw const ReceiptPilotFailure('invalid_response');
          }
          bytes.addAll(chunk);
        }
      })().timeout(remaining);
      if (!stillCurrent()) throw const ReceiptPilotFailure('session_changed');
      Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(bytes));
      } catch (_) {
        throw const ReceiptPilotFailure('invalid_response');
      }
      if (decoded is! Map<String, dynamic>) {
        throw const ReceiptPilotFailure('invalid_response');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ReceiptPilotFailure(method == 'POST' ? 'uncertain' : 'not_ready');
      }
      return decoded;
    } on ReceiptPilotFailure {
      rethrow;
    } catch (_) {
      throw ReceiptPilotFailure(method == 'POST' ? 'uncertain' : 'not_ready');
    } finally {
      elapsed.stop();
      client?.close();
    }
  }

  @override
  Future<ReceiptPilotAdmission> checkReady({
    required ReceiptPilotSessionSnapshot session,
    required bool Function() stillCurrent,
  }) async {
    final response = await _call('GET', stillCurrent: stillCurrent);
    if (response['ready'] == false &&
        response.length == 3 &&
        response.keys.every(
          {'ready', 'reason', 'monthly_limit_usd'}.contains,
        ) &&
        response['reason'] is String &&
        response['monthly_limit_usd'] == 10) {
      throw const ReceiptPilotFailure('not_ready');
    }
    return ReceiptPilotAdmission.fromResponse(
      response,
      expectedOwner: session.owner,
      now: _clock(),
    );
  }

  @override
  Future<ReceiptParseResult> dispatch(ReceiptPilotDispatch request) async {
    if (_dispatched) throw const ReceiptPilotFailure('attempted');
    if (!request.stillCurrent()) {
      throw const ReceiptPilotFailure('session_changed');
    }
    final now = _clock().toUtc();
    final consentAge = now.difference(request.consentedAt);
    if (!request.admission.validFor(request.session, now) ||
        consentAge.isNegative ||
        consentAge > const Duration(minutes: 10)) {
      throw const ReceiptPilotFailure('expired');
    }
    // This constructor verifies the copy immediately before serialization.
    final bytes = ReceiptSyntheticPilotImage.fromBytes(
      request.image.bytes,
    ).bytes;
    _dispatched = true;
    final response = await _call(
      'POST',
      stillCurrent: () =>
          request.stillCurrent() &&
          request.admission.validFor(request.session, _clock()),
      binding: request.admission._binding,
      body: {
        'request_id': receiptSyntheticPilotRequestId,
        'input_revision': receiptSyntheticPilotImageHash,
        'image_base64': base64Encode(bytes),
        'consent': true,
      },
    );
    const fields = {
      'request_id',
      'input_revision',
      'owner_id',
      'needs_review',
      'items',
    };
    if (response.length != fields.length ||
        !response.keys.every(fields.contains) ||
        response['request_id'] != receiptSyntheticPilotRequestId ||
        response['input_revision'] != receiptSyntheticPilotImageHash ||
        response['owner_id'] != request.session.owner ||
        response['needs_review'] != true) {
      throw const ReceiptPilotFailure('invalid_response');
    }
    try {
      return reviewAiReceiptResponse({'items': response['items']});
    } catch (_) {
      throw const ReceiptPilotFailure('invalid_response');
    }
  }
}

enum ReceiptPilotPhase {
  disabled,
  loading,
  idle,
  checking,
  ready,
  committing,
  sending,
  succeeded,
  blocked,
  attempted,
}

class ReceiptSyntheticPilotController extends ChangeNotifier {
  ReceiptSyntheticPilotController.disabled()
    : _guard = null,
      _gatewayFactory = null,
      _attempts = null,
      _loadImage = null,
      _clock = DateTime.now,
      _phase = ReceiptPilotPhase.disabled;
  ReceiptSyntheticPilotController({
    required ReceiptPilotSessionGuard guard,
    required ReceiptPilotGateway Function() gatewayFactory,
    required ReceiptPilotAttemptStore attempts,
    ReceiptSyntheticPilotImage Function()? loadImage,
    DateTime Function()? clock,
  }) : _guard = guard,
       _gatewayFactory = gatewayFactory,
       _attempts = attempts,
       _loadImage = loadImage ?? ReceiptSyntheticPilotImage.embedded,
       _clock = clock ?? DateTime.now,
       _phase = ReceiptPilotPhase.loading {
    guard.addListener(_onSessionChanged);
  }
  final ReceiptPilotSessionGuard? _guard;
  final ReceiptPilotGateway Function()? _gatewayFactory;
  final ReceiptPilotAttemptStore? _attempts;
  final ReceiptSyntheticPilotImage Function()? _loadImage;
  final DateTime Function() _clock;
  ReceiptPilotGateway? _gateway;
  ReceiptPilotSessionSnapshot? _session;
  ReceiptPilotAdmission? _admission;
  ReceiptSyntheticPilotImage? _image;
  ReceiptParseResult? _result;
  ReceiptPilotPhase _phase;
  String? _message;
  bool _initialized = false,
      _disposed = false,
      _consented = false,
      _claimed = false,
      _dispatchStarted = false;
  int _generation = 0;
  Timer? _expiryTimer;
  DateTime? _consentedAt;

  ReceiptPilotPhase get phase => _phase;
  String? get message => _message;
  Uint8List? get previewBytes => _image?.bytes;
  ReceiptParseResult? get result => _result;
  bool get consented => _consented;
  bool get canSend =>
      _phase == ReceiptPilotPhase.ready && _consented && _valid();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int generation) => !_disposed && generation == _generation;
  bool _valid() =>
      _session != null &&
      _admission != null &&
      _guard!.matches(_session!) &&
      _admission!.validFor(_session!, _clock());

  void _block(String code) {
    if (_disposed) return;
    _generation++;
    _expiryTimer?.cancel();
    _consented = false;
    _consentedAt = null;
    _admission = null;
    _result = null;
    _phase = _claimed ? ReceiptPilotPhase.attempted : ReceiptPilotPhase.blocked;
    _message = _dispatchStarted && {'expired', 'session_changed'}.contains(code)
        ? '시험 상태가 바뀌어 결과를 적용하지 않았습니다. 시작된 요청은 비용이 발생했을 수 있어 다시 보내지 않습니다.'
        : ReceiptPilotFailure(code).message;
    _notify();
  }

  void _onSessionChanged() {
    if (_session != null) _block('session_changed');
  }

  Future<void> initialize() async {
    if (_initialized || _disposed || _phase == ReceiptPilotPhase.disabled) {
      return;
    }
    _initialized = true;
    final generation = _generation;
    try {
      if (await _attempts!.wasAttempted()) {
        if (!_current(generation)) return;
        _claimed = true;
        _block('attempted');
        return;
      }
      if (!_current(generation)) return;
      _image = _loadImage!();
      _phase = ReceiptPilotPhase.idle;
      _notify();
    } on ReceiptPilotFailure catch (error) {
      if (_current(generation)) _block(error.code);
    } catch (_) {
      if (_current(generation)) _block('local_state');
    }
  }

  Future<void> prepare() async {
    if (_disposed || _phase != ReceiptPilotPhase.idle || _claimed) return;
    final generation = ++_generation;
    _phase = ReceiptPilotPhase.checking;
    _consented = false;
    _message = null;
    _notify();
    try {
      final session = _guard!.capture();
      _session = session;
      _gateway ??= _gatewayFactory!();
      final admission = await _gateway!.checkReady(
        session: session,
        stillCurrent: () => _current(generation) && _guard.matches(session),
      );
      if (!_current(generation)) return;
      if (!_guard.matches(session)) {
        throw const ReceiptPilotFailure('session_changed');
      }
      if (!admission.validFor(session, _clock())) {
        throw const ReceiptPilotFailure('expired');
      }
      _admission = admission;
      _phase = ReceiptPilotPhase.ready;
      _expiryTimer = Timer(
        admission.expiresAt.difference(_clock().toUtc()),
        () {
          if (_current(generation)) _block('expired');
        },
      );
      _notify();
    } on ReceiptPilotFailure catch (error) {
      if (_current(generation)) _block(error.code);
    } catch (_) {
      if (_current(generation)) _block('not_ready');
    }
  }

  void confirm(bool value) {
    if (_disposed || _phase != ReceiptPilotPhase.ready) return;
    if (!_valid()) {
      _block('expired');
      return;
    }
    _consented = value;
    _consentedAt = value ? _clock().toUtc() : null;
    _notify();
  }

  Future<void> submit() async {
    if (_disposed || _phase != ReceiptPilotPhase.ready || _claimed) return;
    if (!_valid()) {
      _block('expired');
      return;
    }
    if (!_consented || _consentedAt == null) {
      _message = const ReceiptPilotFailure('consent_required').message;
      _notify();
      return;
    }
    final generation = _generation;
    final admission = _admission!, session = _session!, image = _image!;
    final consentedAt = _consentedAt!;
    _claimed = true;
    _consented = false;
    _phase = ReceiptPilotPhase.committing;
    _notify();
    try {
      await _attempts!.claim();
      if (!_current(generation)) return;
      if (!_guard!.matches(session)) {
        throw const ReceiptPilotFailure('session_changed');
      }
      if (!admission.validFor(session, _clock())) {
        throw const ReceiptPilotFailure('expired');
      }
      _dispatchStarted = true;
      _phase = ReceiptPilotPhase.sending;
      _notify();
      final result = await _gateway!.dispatch(
        ReceiptPilotDispatch._(
          image: image,
          admission: admission,
          session: session,
          consentedAt: consentedAt,
          stillCurrent: () => _current(generation) && _guard.matches(session),
        ),
      );
      if (!_current(generation)) return;
      if (!_guard.matches(session)) {
        throw const ReceiptPilotFailure('session_changed');
      }
      if (!admission.validFor(session, _clock())) {
        throw const ReceiptPilotFailure('expired');
      }
      _expiryTimer?.cancel();
      _result = result;
      _phase = ReceiptPilotPhase.succeeded;
      _message = '합성 시험 결과입니다. 식재료에 저장하지 않았습니다.';
      _notify();
    } on ReceiptPilotFailure catch (error) {
      if (_current(generation)) _block(error.code);
    } catch (_) {
      if (_current(generation)) _block('uncertain');
    }
  }

  void closeReview() {
    if (_disposed || _phase == ReceiptPilotPhase.disabled || !_initialized) {
      return;
    }
    _generation++;
    _expiryTimer?.cancel();
    _consented = false;
    _consentedAt = null;
    _session = null;
    _admission = null;
    _result = null;
    // An interrupted read-only initialization may be repeated only on explicit
    // re-entry. Never reset an attempt or any dispatch state.
    if (_image == null && !_claimed && !_dispatchStarted) {
      _initialized = false;
    }
    _message = _claimed ? const ReceiptPilotFailure('attempted').message : null;
    _phase = _claimed
        ? ReceiptPilotPhase.attempted
        : (_image == null ? ReceiptPilotPhase.blocked : ReceiptPilotPhase.idle);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _expiryTimer?.cancel();
    _guard?.removeListener(_onSessionChanged);
    _session = null;
    _admission = null;
    _image = null;
    _result = null;
    super.dispose();
  }
}

final receiptSyntheticPilotControllerProvider =
    Provider<ReceiptSyntheticPilotController>((ref) {
      if (!ref.watch(receiptSyntheticPilotEnabledProvider)) {
        final controller = ReceiptSyntheticPilotController.disabled();
        ref.onDispose(controller.dispose);
        return controller;
      }
      final controller = ReceiptSyntheticPilotController(
        guard: ref.watch(receiptPilotSessionGuardProvider),
        gatewayFactory: () => ref.read(receiptPilotGatewayProvider),
        attempts: ref.watch(receiptPilotAttemptStoreProvider),
        loadImage: ref.watch(receiptSyntheticPilotImageLoaderProvider),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });
