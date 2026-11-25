import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../app_variant.dart';
import '../providers.dart';
import 'ingredient_photo.dart' show newIngredientUuid;
import 'receipt_synthetic_pilot.dart'
    show
        ReceiptPilotSessionGuard,
        ReceiptPilotSessionSnapshot,
        receiptPilotSessionGuardProvider,
        receiptSyntheticPilotRequestId,
        receiptSyntheticPilotImageHash;

// Independent of the paid pilot gate. Merely preparing never authorizes spend.
const receiptPilotPreparationEndpoint =
    'https://brghwnwkfhbhamrrrqnr.supabase.co/functions/v1/receipt-pilot-prepare';
const receiptPilotPreparationConsentVersion = 'receipt-pilot-preparation-v1';
const receiptPilotPreparationCooldown = Duration(seconds: 30);

final receiptPilotPreparationEnabledProvider = Provider<bool>(
  (_) =>
      isDevelopmentApp &&
      const bool.fromEnvironment('RECEIPT_PILOT_PREPARATION_ENABLED'),
);

class ReceiptPilotPreparationFailure implements Exception {
  const ReceiptPilotPreparationFailure(this.code);
  final String code;
  String get message => switch (code) {
    'disabled' => '현재 계정의 시험 준비 기능은 꺼져 있습니다.',
    'identity' => '현재 로그인 계정을 표시할 수 없어 준비하지 않았습니다. 로그인 상태를 확인해 주세요.',
    'changed' => '현재 계정이나 로그인 상태가 바뀌어 동의와 준비 코드를 지웠습니다.',
    'expired' => '준비 코드가 만료되어 지웠습니다. 이 코드로 시험을 승인할 수 없습니다.',
    'consent' => '화면에 표시된 현재 계정과 준비 단계 안내를 확인해 주세요.',
    'rate_limited' => '준비 요청이 너무 잦습니다. 잠시 후 별도로 새 준비를 확인해 주세요.',
    'uncertain' =>
      '준비 응답을 확인하지 못했습니다. 자동으로 다시 요청하지 않습니다. 사진 전송·금액 예약·AI 호출은 하지 않는 준비 단계입니다.',
    'invalid_response' => '준비 응답을 확인하지 못해 코드를 표시하지 않습니다.',
    _ => '현재 계정의 시험 준비가 허용되었는지 확인하지 못했습니다.',
  };
  @override
  String toString() => 'ReceiptPilotPreparationFailure($code)';
}

String? _validLabel(Object? value) {
  if (value is! String) return null;
  final label = value.trim();
  if (label.isEmpty ||
      label.runes.length > 160 ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(label)) {
    return null;
  }
  return label;
}

/// Only already-available human-readable SDK account data. Never an ID fallback,
/// local-account search, auth-record enumeration or token-derived identity.
final receiptPilotCurrentAccountLabelProvider = Provider<String? Function()>((
  ref,
) {
  final client = ref.watch(supabaseProvider);
  return () {
    final user = client.auth.currentSession?.user;
    if (user == null) return null;
    final email = _validLabel(user.email);
    if (email != null && email != user.id) return email;
    for (final key in ['display_name', 'full_name', 'name']) {
      final name = _validLabel(user.userMetadata?[key]);
      if (name != null && name != user.id) return name;
    }
    return null;
  };
});

bool validPreparationUuid(String value) => RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
).hasMatch(value);

final class ReceiptPilotPreparationReceipt {
  ReceiptPilotPreparationReceipt._(this.code, this.expiresAt);

  /// Intentionally displayed as a NON-authorizing operator lookup code.
  final String code;
  final DateTime expiresAt;
  factory ReceiptPilotPreparationReceipt.fromResponse(
    Map<String, dynamic> value, {
    required String preparationId,
    required DateTime now,
  }) {
    const fields = {
      'prepared',
      'preparation_id',
      'request_id',
      'input_revision',
      'preparation_code',
      'expires_at',
      'no_spend',
    };
    final rawExpiry = value['expires_at'];
    final expiry = rawExpiry is String ? DateTime.tryParse(rawExpiry) : null;
    final code = value['preparation_code'];
    if (!validPreparationUuid(preparationId) ||
        value.length != fields.length ||
        !value.keys.every(fields.contains) ||
        value['prepared'] != true ||
        value['no_spend'] != true ||
        value['preparation_id'] != preparationId ||
        value['request_id'] != receiptSyntheticPilotRequestId ||
        value['input_revision'] != receiptSyntheticPilotImageHash ||
        code is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(code) ||
        rawExpiry is! String ||
        !rawExpiry.endsWith('Z') ||
        expiry == null ||
        !expiry.isUtc ||
        !expiry.isAfter(now.toUtc()) ||
        expiry.difference(now.toUtc()) > const Duration(minutes: 5)) {
      throw const ReceiptPilotPreparationFailure('invalid_response');
    }
    return ReceiptPilotPreparationReceipt._(code, expiry);
  }
  @override
  String toString() => 'ReceiptPilotPreparationReceipt(redacted)';
}

abstract interface class ReceiptPilotPreparationGateway {
  Future<ReceiptPilotPreparationReceipt> prepare({
    required String preparationId,
    required bool Function() stillCurrent,
  });
}

final receiptPilotPreparationGatewayProvider =
    Provider<ReceiptPilotPreparationGateway>((ref) {
      if (!ref.read(receiptPilotPreparationEnabledProvider)) {
        throw const ReceiptPilotPreparationFailure('disabled');
      }
      final client = ref.watch(supabaseProvider);
      final url = Uri.tryParse(dotenv.env['SUPABASE_URL'] ?? '');
      if (url == null ||
          url.scheme != 'https' ||
          url.host != 'brghwnwkfhbhamrrrqnr.supabase.co' ||
          url.hasQuery ||
          url.hasFragment ||
          url.userInfo.isNotEmpty ||
          url.hasPort ||
          (url.path.isNotEmpty && url.path != '/')) {
        throw const ReceiptPilotPreparationFailure('not_ready');
      }
      return SupabaseReceiptPilotPreparationGateway(
        publishableKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
        accessToken: () => client.auth.currentSession?.accessToken,
      );
    });

class SupabaseReceiptPilotPreparationGateway
    implements ReceiptPilotPreparationGateway {
  SupabaseReceiptPilotPreparationGateway({
    required this.publishableKey,
    required this.accessToken,
    http.Client Function()? clientFactory,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 20),
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _clock = clock ?? DateTime.now;
  final String publishableKey;
  final String? Function() accessToken;
  final http.Client Function() _clientFactory;
  final DateTime Function() _clock;
  final Duration timeout;
  final Set<String> _attempted = {};

  @override
  Future<ReceiptPilotPreparationReceipt> prepare({
    required String preparationId,
    required bool Function() stillCurrent,
  }) async {
    if (!validPreparationUuid(preparationId) ||
        !_attempted.add(preparationId)) {
      throw const ReceiptPilotPreparationFailure('invalid_response');
    }
    http.Client? client;
    final elapsed = Stopwatch()..start();
    try {
      if (!stillCurrent()) {
        throw const ReceiptPilotPreparationFailure('changed');
      }
      final token = accessToken();
      if (token == null || token.isEmpty || publishableKey.isEmpty) {
        throw const ReceiptPilotPreparationFailure('identity');
      }
      if (!stillCurrent()) {
        throw const ReceiptPilotPreparationFailure('changed');
      }
      final request =
          http.Request('POST', Uri.parse(receiptPilotPreparationEndpoint))
            ..followRedirects = false
            ..maxRedirects = 0
            ..headers.addAll({
              'Authorization': 'Bearer $token',
              'apikey': publishableKey,
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            })
            ..body = jsonEncode({
              'preparation_id': preparationId,
              'request_id': receiptSyntheticPilotRequestId,
              'input_revision': receiptSyntheticPilotImageHash,
              'consent_version': receiptPilotPreparationConsentVersion,
              'consent': true,
            });
      client = _clientFactory();
      final response = await client.send(request).timeout(timeout);
      final remaining = timeout - elapsed.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException('preparation deadline');
      }
      final bytes = <int>[];
      await (() async {
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 16 * 1024) {
            throw const ReceiptPilotPreparationFailure('invalid_response');
          }
          bytes.addAll(chunk);
        }
      })().timeout(remaining);
      if (!stillCurrent()) {
        throw const ReceiptPilotPreparationFailure('changed');
      }
      if (response.statusCode == 429) {
        throw const ReceiptPilotPreparationFailure('rate_limited');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const ReceiptPilotPreparationFailure('not_ready');
      }
      Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(bytes));
      } catch (_) {
        throw const ReceiptPilotPreparationFailure('invalid_response');
      }
      if (decoded is! Map<String, dynamic>) {
        throw const ReceiptPilotPreparationFailure('invalid_response');
      }
      return ReceiptPilotPreparationReceipt.fromResponse(
        decoded,
        preparationId: preparationId,
        now: _clock(),
      );
    } on ReceiptPilotPreparationFailure {
      rethrow;
    } catch (_) {
      throw const ReceiptPilotPreparationFailure('uncertain');
    } finally {
      elapsed.stop();
      client?.close();
    }
  }
}

enum ReceiptPilotPreparationPhase {
  disabled,
  unavailable,
  ready,
  preparing,
  prepared,
  failed,
}

class ReceiptPilotPreparationController extends ChangeNotifier {
  ReceiptPilotPreparationController.disabled()
    : _guard = null,
      _accountLabel = null,
      _gatewayFactory = null,
      _newUuid = newIngredientUuid,
      _clock = DateTime.now,
      _phase = ReceiptPilotPreparationPhase.disabled;
  ReceiptPilotPreparationController({
    required ReceiptPilotSessionGuard guard,
    required String? Function() accountLabel,
    required ReceiptPilotPreparationGateway Function() gatewayFactory,
    String Function()? newUuid,
    DateTime Function()? clock,
  }) : _guard = guard,
       _accountLabel = accountLabel,
       _gatewayFactory = gatewayFactory,
       _newUuid = newUuid ?? newIngredientUuid,
       _clock = clock ?? DateTime.now,
       _phase = ReceiptPilotPreparationPhase.unavailable {
    guard.addListener(_onIdentityChanged);
  }
  final ReceiptPilotSessionGuard? _guard;
  final String? Function()? _accountLabel;
  final ReceiptPilotPreparationGateway Function()? _gatewayFactory;
  final String Function() _newUuid;
  final DateTime Function() _clock;
  ReceiptPilotPreparationGateway? _gateway;
  ReceiptPilotSessionSnapshot? _session;
  ReceiptPilotPreparationReceipt? _receipt;
  String? _label, _message;
  bool _consented = false, _disposed = false;
  int _generation = 0;
  DateTime? _lastAttempt;
  Timer? _expiryTimer, _cooldownTimer;
  final Set<String> _generatedIds = {};
  ReceiptPilotPreparationPhase _phase;

  ReceiptPilotPreparationPhase get phase => _phase;
  String? get message => _message;
  bool get consented => _consented;
  String? get accountLabel => _identityCurrent() ? _label : null;
  String? get preparationCode =>
      _identityCurrent() &&
          _receipt != null &&
          _clock().toUtc().isBefore(_receipt!.expiresAt)
      ? _receipt!.code
      : null;
  bool get cooldownComplete =>
      _lastAttempt == null ||
      _clock().toUtc().difference(_lastAttempt!) >=
          receiptPilotPreparationCooldown;
  bool get canPrepare =>
      _phase == ReceiptPilotPreparationPhase.ready &&
      _consented &&
      _identityCurrent() &&
      cooldownComplete;
  bool get canStartNew =>
      !_disposed &&
      {
        ReceiptPilotPreparationPhase.prepared,
        ReceiptPilotPreparationPhase.failed,
        ReceiptPilotPreparationPhase.unavailable,
      }.contains(_phase) &&
      cooldownComplete;

  bool _identityCurrent() {
    try {
      return !_disposed &&
          _session != null &&
          _label != null &&
          _guard!.matches(_session!) &&
          _validLabel(_accountLabel!()) == _label;
    } catch (_) {
      return false;
    }
  }

  bool _current(int generation) => !_disposed && generation == _generation;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _scheduleCooldown() {
    _cooldownTimer?.cancel();
    if (_lastAttempt == null) return;
    final remaining =
        receiptPilotPreparationCooldown -
        _clock().toUtc().difference(_lastAttempt!);
    if (remaining > Duration.zero) {
      _cooldownTimer = Timer(remaining, _notify);
    }
  }

  /// UI clock refresh only. Does not recover identity, code, consent or send.
  void resumeView() {
    if (_disposed || _phase == ReceiptPilotPreparationPhase.disabled) return;
    _scheduleCooldown();
    _notify();
  }

  void _clear(String? code, ReceiptPilotPreparationPhase phase) {
    if (_disposed) return;
    _generation++;
    _expiryTimer?.cancel();
    _receipt = null;
    _consented = false;
    _session = null;
    _label = null;
    _phase = phase;
    _message = code == null
        ? null
        : ReceiptPilotPreparationFailure(code).message;
    _notify();
  }

  void _onIdentityChanged() {
    _clear('changed', ReceiptPilotPreparationPhase.unavailable);
  }

  /// Local SDK data only. No readiness request, storage read or photo decoding.
  void initialize() {
    if (_disposed ||
        _phase == ReceiptPilotPreparationPhase.disabled ||
        _phase == ReceiptPilotPreparationPhase.preparing ||
        _phase == ReceiptPilotPreparationPhase.prepared) {
      return;
    }
    _scheduleCooldown();
    _captureIdentity();
  }

  void _captureIdentity() {
    _clear(null, ReceiptPilotPreparationPhase.unavailable);
    try {
      final session = _guard!.capture();
      final label = _validLabel(_accountLabel!());
      if (label == null || !_guard.matches(session)) {
        throw const ReceiptPilotPreparationFailure('identity');
      }
      _session = session;
      _label = label;
      _phase = ReceiptPilotPreparationPhase.ready;
      _message = cooldownComplete
          ? null
          : const ReceiptPilotPreparationFailure('rate_limited').message;
      _notify();
    } catch (_) {
      _clear('identity', ReceiptPilotPreparationPhase.unavailable);
    }
  }

  void startNewPreparation() {
    if (!canStartNew) return;
    _captureIdentity();
  }

  void confirmCurrentAccount(bool value) {
    if (_phase != ReceiptPilotPreparationPhase.ready || _disposed) return;
    if (!_identityCurrent()) {
      _onIdentityChanged();
      return;
    }
    _consented = value;
    _notify();
  }

  Future<void> prepare() async {
    if (_disposed || _phase != ReceiptPilotPreparationPhase.ready) return;
    if (!_identityCurrent()) {
      _onIdentityChanged();
      return;
    }
    if (!cooldownComplete) {
      _message = const ReceiptPilotPreparationFailure('rate_limited').message;
      _notify();
      return;
    }
    if (!_consented) {
      _message = const ReceiptPilotPreparationFailure('consent').message;
      _notify();
      return;
    }
    final generation = ++_generation;
    _consented = false;
    _receipt = null;
    _message = null;
    _phase = ReceiptPilotPreparationPhase.preparing;
    _lastAttempt = _clock().toUtc();
    _scheduleCooldown();
    _notify();
    try {
      final id = _newUuid();
      if (!validPreparationUuid(id) || !_generatedIds.add(id)) {
        throw const ReceiptPilotPreparationFailure('invalid_response');
      }
      _gateway ??= _gatewayFactory!();
      final receipt = await _gateway!.prepare(
        preparationId: id,
        stillCurrent: () => _current(generation) && _identityCurrent(),
      );
      if (!_current(generation)) return;
      if (!_identityCurrent()) {
        throw const ReceiptPilotPreparationFailure('changed');
      }
      if (!_clock().toUtc().isBefore(receipt.expiresAt)) {
        throw const ReceiptPilotPreparationFailure('expired');
      }
      _receipt = receipt;
      _phase = ReceiptPilotPreparationPhase.prepared;
      _expiryTimer = Timer(receipt.expiresAt.difference(_clock().toUtc()), () {
        if (_current(generation)) {
          _clear('expired', ReceiptPilotPreparationPhase.unavailable);
        }
      });
      _notify();
    } on ReceiptPilotPreparationFailure catch (error) {
      if (_current(generation)) {
        _clear(error.code, ReceiptPilotPreparationPhase.failed);
      }
    } catch (_) {
      if (_current(generation)) {
        _clear('uncertain', ReceiptPilotPreparationPhase.failed);
      }
    }
  }

  /// Keeps the cooldown and generated-ID history, but no code or identity.
  void closeReview() {
    if (_disposed || _phase == ReceiptPilotPreparationPhase.disabled) return;
    _cooldownTimer?.cancel();
    _clear(null, ReceiptPilotPreparationPhase.unavailable);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _expiryTimer?.cancel();
    _cooldownTimer?.cancel();
    _guard?.removeListener(_onIdentityChanged);
    _receipt = null;
    _session = null;
    _label = null;
    super.dispose();
  }
}

final receiptPilotPreparationControllerProvider =
    Provider<ReceiptPilotPreparationController>((ref) {
      if (!ref.watch(receiptPilotPreparationEnabledProvider)) {
        final controller = ReceiptPilotPreparationController.disabled();
        ref.onDispose(controller.dispose);
        return controller;
      }
      final controller = ReceiptPilotPreparationController(
        guard: ref.watch(receiptPilotSessionGuardProvider),
        accountLabel: ref.watch(receiptPilotCurrentAccountLabelProvider),
        gatewayFactory: () => ref.read(receiptPilotPreparationGatewayProvider),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });
