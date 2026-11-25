import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers.dart';
import 'receipt_analysis.dart';
import 'receipt_image_payload.dart';

// Rollout is explicit. A client flag is never the server's spend/auth gate.
final receiptAiEnabledProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('RECEIPT_AI_ENABLED'),
);

class ReceiptAiFailure implements Exception {
  const ReceiptAiFailure(this.code);
  final String code;
  String get message => switch (code) {
    'unauthenticated' => 'AI 분석을 시작한 계정으로 로그인해 주세요.',
    'owner_not_allowed' =>
      '이 계정은 영수증 AI 사용이 허용되지 않았습니다. 기기 인식이나 직접 입력을 이용해 주세요.',
    'rate_limited' => '하루 AI 요청 한도 10회에 도달했습니다. 기기 인식이나 직접 입력을 이용해 주세요.',
    'budget_exhausted' => '이번 달 AI 사용 한도에 도달했습니다. 기기 인식이나 직접 입력을 이용해 주세요.',
    'duplicate_request' => '이미 제출한 요청입니다. 중복 비용을 막기 위해 다시 보내지 않았습니다.',
    'timeout' =>
      'AI 응답을 받지 못했습니다. 기존 입력은 유지했습니다. 비용이 발생하거나 최대 US\$0.60 예약액이 유지될 수 있어 자동 재시도하지 않습니다. 사진을 다시 선택해 보내면 새 유료 요청이 됩니다.',
    'invalid_image' => '전송 사진의 크기나 형식을 확인해 주세요.',
    'consent_expired' => '전송 사진 확인 후 시간이 지났습니다. 사진을 다시 확인해 주세요.',
    'not_ready' => 'AI 서버 연결이 아직 준비되지 않았습니다. 기기 인식이나 직접 입력을 이용해 주세요.',
    _ =>
      'AI 분석을 완료하지 못했습니다. 기존 입력은 유지했습니다. 전송 후 실패라면 비용이 발생하거나 최대 US\$0.60 예약액이 유지될 수 있습니다. 자동 재시도하지 않으며 사진을 다시 보내면 새 유료 요청이 됩니다.',
  };
  @override
  String toString() => 'ReceiptAiFailure($code)';
}

/// No tokens are retained in this guard. The provider observes auth boundaries
/// so signing out and back into the same account invalidates pending work.
class ReceiptAiSessionGuard extends ChangeNotifier {
  ReceiptAiSessionGuard(this.currentOwner) : _observedOwner = currentOwner();
  final String? Function() currentOwner;
  String? _observedOwner;
  int _revision = 0;
  void invalidate() {
    _revision++;
    notifyListeners();
  }

  void observeAuthChange(AuthChangeEvent event, String? nextOwner) {
    // A normal same-owner token refresh is not a new consent boundary.
    if (_observedOwner != nextOwner ||
        !const {
          AuthChangeEvent.initialSession,
          AuthChangeEvent.tokenRefreshed,
        }.contains(event)) {
      invalidate();
    }
    _observedOwner = nextOwner;
  }

  ReceiptAiReviewContext capture({
    required String inputRevision,
    required String requestId,
  }) {
    final owner = currentOwner();
    if (owner == null || owner.isEmpty) {
      throw const ReceiptAiFailure('unauthenticated');
    }
    return ReceiptAiReviewContext(
      owner: owner,
      sessionRevision: '$_revision',
      inputRevision: inputRevision,
      requestId: requestId,
    );
  }

  ReceiptAiReviewContext? current(ReceiptAiReviewContext request) {
    final owner = currentOwner();
    if (owner == null || owner.isEmpty) return null;
    return ReceiptAiReviewContext(
      owner: owner,
      sessionRevision: '$_revision',
      inputRevision: request.inputRevision,
      requestId: request.requestId,
    );
  }
}

final receiptAiSessionProvider = Provider<ReceiptAiSessionGuard>((ref) {
  final client = ref.watch(supabaseProvider);
  final guard = ReceiptAiSessionGuard(() => _sessionOwner(client));
  final subscription = client.auth.onAuthStateChange.listen((state) {
    final session = state.session;
    final next =
        session == null || session.user.isAnonymous || session.isExpired
        ? null
        : session.user.id;
    guard.observeAuthChange(state.event, next);
  });
  ref.onDispose(() {
    subscription.cancel();
    guard.dispose();
  });
  return guard;
});

// This local check improves UX only. The server must independently validate the
// live session and its operator-configured owner allowlist for every request.
String? _sessionOwner(SupabaseClient client) {
  final session = client.auth.currentSession;
  if (session == null || session.user.isAnonymous || session.isExpired) {
    return null;
  }
  return session.user.id;
}

abstract interface class ReceiptAiGateway {
  Future<void> checkReady();
  Future<ReceiptAnalysis> analyze({
    required ReviewedReceiptImage image,
    required ReceiptAiReviewContext context,
    required ReceiptAiReviewContext? Function() currentContext,
  });
}

final receiptAiGatewayProvider = Provider<ReceiptAiGateway>((ref) {
  final client = ref.watch(supabaseProvider);
  final url = Uri.parse(dotenv.env['SUPABASE_URL'] ?? '');
  // This is the app's verified backend, never a model-supplied URL or redirect.
  if (url.scheme != 'https' ||
      url.host != 'brghwnwkfhbhamrrrqnr.supabase.co' ||
      url.hasQuery ||
      url.hasFragment) {
    throw const ReceiptAiFailure('not_ready');
  }
  return SupabaseReceiptAiGateway(
    endpoint: url.replace(path: '/functions/v1/receipt-analyze'),
    publishableKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    accessToken: () => client.auth.currentSession?.accessToken,
    currentOwner: () => _sessionOwner(client),
  );
});

class SupabaseReceiptAiGateway implements ReceiptAiGateway {
  SupabaseReceiptAiGateway({
    required this.endpoint,
    required this.publishableKey,
    required this.accessToken,
    required this.currentOwner,
    http.Client Function()? clientFactory,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 50),
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _clock = clock ?? DateTime.now;
  final Uri endpoint;
  final String publishableKey;
  final String? Function() accessToken;
  final String? Function() currentOwner;
  final http.Client Function() _clientFactory;
  final DateTime Function() _clock;
  final Duration timeout;
  final _attempted = <String>{};

  // Deliberately avoids SDK request logging and automatic retry. Redirects are
  // rejected so image/auth cannot be forwarded to another destination.
  Future<Map<String, dynamic>> _call(String method, {Object? body}) async {
    final token = accessToken();
    if (token == null || token.isEmpty) {
      throw const ReceiptAiFailure('unauthenticated');
    }
    final client = _clientFactory();
    final elapsed = Stopwatch()..start();
    try {
      final request = http.Request(method, endpoint)
        ..followRedirects = false
        ..maxRedirects = 0
        ..headers.addAll({
          'Authorization': 'Bearer $token',
          'apikey': publishableKey,
          'Accept': 'application/json',
        });
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final response = await client.send(request).timeout(timeout);
      final bytes = <int>[];
      final remaining = timeout - elapsed.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException('receipt deadline');
      }
      await (() async {
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 128 * 1024) {
            throw const ReceiptAiFailure('invalid_response');
          }
          bytes.addAll(chunk);
        }
      })().timeout(remaining);
      Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(bytes));
      } catch (_) {
        throw const ReceiptAiFailure('invalid_response');
      }
      if (decoded is! Map<String, dynamic>) {
        throw const ReceiptAiFailure('invalid_response');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        const codes = {
          'unauthenticated',
          'owner_not_allowed',
          'rate_limited',
          'budget_exhausted',
          'duplicate_request',
          'invalid_image',
          'not_ready',
        };
        final code = decoded['error'];
        throw ReceiptAiFailure(
          codes.contains(code) ? code as String : 'provider_unavailable',
        );
      }
      return decoded;
    } on TimeoutException {
      throw ReceiptAiFailure(method == 'POST' ? 'timeout' : 'not_ready');
    } on ReceiptAiFailure {
      rethrow;
    } catch (_) {
      throw const ReceiptAiFailure('provider_unavailable');
    } finally {
      elapsed.stop();
      client.close();
    }
  }

  @override
  Future<void> checkReady() async {
    final owner = currentOwner();
    if (owner == null || owner.isEmpty) {
      throw const ReceiptAiFailure('unauthenticated');
    }
    await _checkReadyFor(owner);
  }

  Future<void> _checkReadyFor(String owner) async {
    final result = await _call('GET');
    if (currentOwner() != owner) {
      throw const ReceiptAnalysisDiscarded();
    }
    final expiryText = result['price_review_expires_at'];
    final expiry = expiryText is String ? DateTime.tryParse(expiryText) : null;
    // Fail closed for older/public/pilot endpoints or missing safety fields.
    // These attest the server contract, never replace its enforcement.
    if (result['contract_version'] != 'receipt-owner-v1' ||
        result['access_mode'] != 'single_owner' ||
        result['authenticated_owner_id'] != owner ||
        result['monthly_limit_usd'] != 10 ||
        result['monthly_limit_micro_usd'] != 10000000 ||
        result['reservation_micro_usd'] != 600000 ||
        result['daily_request_limit'] != 10 ||
        result['cooking_enabled'] != false) {
      throw const ReceiptAiFailure('not_ready');
    }
    if (result['ready'] != true ||
        result['reason'] != 'ready' ||
        result['owner_eligible'] != true ||
        expiry == null ||
        !expiry.isUtc ||
        !expiry.isAfter(_clock().toUtc())) {
      const reasons = {
        'budget_exhausted',
        'rate_limited',
        'owner_not_allowed',
        'unauthenticated',
      };
      final reason = result['reason'];
      throw ReceiptAiFailure(
        reasons.contains(reason) ? reason as String : 'not_ready',
      );
    }
  }

  @override
  Future<ReceiptAnalysis> analyze({
    required ReviewedReceiptImage image,
    required ReceiptAiReviewContext context,
    required ReceiptAiReviewContext? Function() currentContext,
  }) async {
    if (!context.matches(currentContext())) {
      throw const ReceiptAnalysisDiscarded();
    }
    final age = _clock().toUtc().difference(image.reviewedAt);
    if (age.isNegative ||
        age > const Duration(minutes: 10) ||
        image.consentVersion != receiptImageConsentVersion) {
      throw const ReceiptAiFailure('consent_expired');
    }
    final bytes = image.bytes;
    if (bytes.isEmpty ||
        bytes.length > 2 * 1024 * 1024 ||
        image.width < 1 ||
        image.height < 1 ||
        image.width > 1536 ||
        image.height > 1536 ||
        image.mimeType != 'image/png' ||
        context.inputRevision != image.sha256Hex) {
      throw const ReceiptAiFailure('invalid_image');
    }
    if (!_attempted.add(context.requestId)) {
      throw const ReceiptAiFailure('duplicate_request');
    }
    if (currentOwner() != context.owner) {
      throw const ReceiptAnalysisDiscarded();
    }
    // Readiness from before camera/editing is not sufficient authorization.
    // This body-free GET happens once immediately before the paid POST.
    await _checkReadyFor(context.owner);
    if (!context.matches(currentContext())) {
      throw const ReceiptAnalysisDiscarded();
    }
    final finalAge = _clock().toUtc().difference(image.reviewedAt);
    if (finalAge.isNegative || finalAge > const Duration(minutes: 10)) {
      throw const ReceiptAiFailure('consent_expired');
    }
    final result = await _call(
      'POST',
      body: {
        'request_id': context.requestId,
        'input_revision': context.inputRevision,
        'image_base64': base64Encode(bytes),
        'consent': true,
      },
    );
    if (!context.matches(currentContext())) {
      throw const ReceiptAnalysisDiscarded();
    }
    if (result['request_id'] != context.requestId ||
        result['input_revision'] != context.inputRevision ||
        result['owner_id'] != context.owner ||
        result['needs_review'] != true) {
      throw const ReceiptAiFailure('invalid_response');
    }
    return ReceiptAnalysis.aiReview(
      response: {'items': result['items']},
      context: context,
      currentContext: currentContext,
    );
  }
}
