import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'meal_assistant.dart';
import 'meal_conversation.dart';

const mealConversationContractVersion = 'cooking-conversation-owner-v1';

class MealConversationFailure extends MealAssistantFailure {
  const MealConversationFailure(super.code);
  @override
  String get message => switch (code) {
    'unauthenticated' => '로그인 상태를 다시 확인해 주세요. 대화는 자동으로 다시 보내지 않아요.',
    'owner_not_allowed' => '이 계정에서는 아직 대화형 AI를 이용할 수 없어요.',
    'rate_limited' => '오늘의 AI 요청 한도에 도달했어요. 자동으로 다시 보내지 않아요.',
    'provider_unavailable' => 'AI 답변을 받지 못했어요. 비용이 발생했을 수 있어 자동으로 다시 보내지 않아요.',
    'invalid_response' => 'AI 답변을 확인하지 못했어요. 비용이 발생했을 수 있어 자동으로 다시 보내지 않아요.',
    _ => super.message,
  };
}

bool _approvedBase(Uri? url) =>
    url != null &&
    url.scheme == 'https' &&
    url.host == 'brghwnwkfhbhamrrrqnr.supabase.co' &&
    url.port == 443 &&
    url.userInfo.isEmpty &&
    !url.hasQuery &&
    !url.hasFragment;

/// Adapter factory. The app provider supplies the approved rollout flag. Callers
/// must explicitly opt in; constructing it never makes a network request.
MealConversationGateway configuredMealConversationGateway({
  bool rolloutEnabled = false,
  required String baseUrl,
  required String publishableKey,
  required String? Function() accessToken,
  http.Client Function()? clientFactory,
}) {
  final url = Uri.tryParse(baseUrl);
  if (!rolloutEnabled ||
      !_approvedBase(url) ||
      (url!.path.isNotEmpty && url.path != '/') ||
      publishableKey.trim().isEmpty) {
    return const DisabledMealConversationGateway();
  }
  return HttpMealConversationGateway(
    endpoint: url.replace(path: '/functions/v1/cooking-conversation'),
    publishableKey: publishableKey,
    accessToken: accessToken,
    clientFactory: clientFactory ?? http.Client.new,
  );
}

/// A new endpoint/consent contract, never a fallback to menus or automatic grants.
/// Auth is sent only to the pinned app backend, not inside the inference input.
class HttpMealConversationGateway implements MealConversationGateway {
  HttpMealConversationGateway({
    required this.endpoint,
    required this.publishableKey,
    required this.accessToken,
    required this.clientFactory,
    this.timeout = const Duration(seconds: 50),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final Uri endpoint;
  final String publishableKey;
  final String? Function() accessToken;
  final http.Client Function() clientFactory;
  final Duration timeout;
  final DateTime Function() now;
  final _attempted = <String>{};
  @override
  bool get enabled => true;

  void _current(
    MealConversationConsent consent,
    bool Function() isCurrent, {
    String? token,
  }) {
    if (!isCurrent()) throw const MealConversationFailure('stale');
    if (token != null && accessToken() != token) {
      throw const MealConversationFailure('stale');
    }
    final age = now().toUtc().difference(consent.grantedAt.toUtc());
    if (consent.version != mealConversationConsentVersion ||
        consent.owner.isEmpty ||
        consent.session.isEmpty ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(consent.requestId) ||
        age.isNegative ||
        age > const Duration(minutes: 10)) {
      throw const MealConversationFailure('consent_required');
    }
  }

  Future<Map<String, dynamic>> _call(
    String method,
    String token, {
    Object? body,
  }) async {
    final client = clientFactory();
    final elapsed = Stopwatch()..start();
    try {
      final request = http.Request(method, endpoint)
        ..followRedirects = false
        ..maxRedirects = 0
        ..headers.addAll({
          'Authorization': 'Bearer $token',
          'apikey': publishableKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        });
      if (body != null) request.body = jsonEncode(body);
      final response = await client.send(request).timeout(timeout);
      if (response.statusCode >= 300 && response.statusCode < 400) {
        throw const MealConversationFailure('invalid_response');
      }
      if ((response.contentLength ?? 0) > 65536) {
        throw const MealConversationFailure('invalid_response');
      }
      final remaining = timeout - elapsed.elapsed;
      if (remaining <= Duration.zero) throw TimeoutException('deadline');
      final bytes = <int>[];
      await (() async {
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 65536) {
            throw const MealConversationFailure('invalid_response');
          }
          bytes.addAll(chunk);
        }
      })().timeout(remaining);
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map<String, dynamic>) {
        throw const MealConversationFailure('invalid_response');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final raw = value['error'];
        final code = raw == 'bad_request' ? 'invalid_request' : raw;
        throw MealConversationFailure(
          const {
                'unauthenticated',
                'owner_not_allowed',
                'not_ready',
                'budget_exhausted',
                'rate_limited',
                'duplicate_request',
                'invalid_request',
                'provider_unavailable',
                'stale',
              }.contains(code)
              ? code as String
              : 'invalid_response',
        );
      }
      return value;
    } on TimeoutException {
      throw MealConversationFailure(method == 'POST' ? 'timeout' : 'not_ready');
    } on MealAssistantFailure {
      rethrow;
    } catch (_) {
      throw const MealConversationFailure('invalid_response');
    } finally {
      elapsed.stop();
      client.close();
    }
  }

  void _ready(Map<String, dynamic> status, MealConversationConsent consent) {
    if (status['ready'] != true) {
      throw MealConversationFailure(
        const {
              'budget_exhausted',
              'rate_limited',
              'owner_not_allowed',
            }.contains(status['reason'])
            ? status['reason'] as String
            : 'not_ready',
      );
    }
    final expiry = status['price_review_expires_at'];
    final deadline = expiry is String ? DateTime.tryParse(expiry) : null;
    final tasks = status['allowed_tasks'];
    if (status['contract_version'] != mealConversationContractVersion ||
        status['consent_version'] != mealConversationConsentVersion ||
        status['access_mode'] != 'single_owner' ||
        status['owner_eligible'] != true ||
        status['authenticated_owner_id'] != consent.owner ||
        status['monthly_limit_usd'] != 10 ||
        status['monthly_limit_micro_usd'] != 10000000 ||
        status['reservation_micro_usd'] != 600000 ||
        status['daily_request_limit'] != 10 ||
        status['budget_scope'] != 'app-ai-shared-v1' ||
        status['max_recent_exchanges'] != mealConversationRecentExchanges ||
        status['max_question_chars'] != mealConversationQuestionLimit ||
        tasks is! List ||
        tasks.length != 1 ||
        tasks.single != 'conversation' ||
        deadline == null ||
        !deadline.isUtc ||
        !deadline.isAfter(now().toUtc())) {
      throw const MealConversationFailure('not_ready');
    }
  }

  @override
  Future<MealConversationAnswer> ask(
    MealConversationConsent consent, {
    required bool Function() isCurrent,
  }) async {
    _current(consent, isCurrent);
    if (!_approvedBase(endpoint) ||
        endpoint.path != '/functions/v1/cooking-conversation' ||
        publishableKey.trim().isEmpty) {
      throw const MealConversationFailure('not_ready');
    }
    final token = accessToken();
    if (token == null || token.isEmpty) {
      throw const MealConversationFailure('unauthenticated');
    }
    // Consume the ID before any network step. Unknown outcomes never auto-retry.
    if (!_attempted.add(consent.requestId)) {
      throw const MealConversationFailure('duplicate_request');
    }
    _current(consent, isCurrent, token: token);
    final status = await _call('GET', token);
    _current(consent, isCurrent, token: token);
    _ready(status, consent);
    final response = await _call(
      'POST',
      token,
      body: {
        'request_id': consent.requestId,
        'input_revision': consent.draft.revision,
        'input_json': consent.draft.encoded,
        'consent_version': consent.version,
      },
    );
    _current(consent, isCurrent, token: token);
    if (response.length != 5 ||
        response['request_id'] != consent.requestId ||
        response['input_revision'] != consent.draft.revision ||
        response['owner_id'] != consent.owner ||
        response['needs_review'] != true ||
        !response.containsKey('result')) {
      throw const MealConversationFailure('invalid_response');
    }
    try {
      return MealConversationAnswer.parse(response['result']);
    } on MealAssistantFailure {
      throw const MealConversationFailure('invalid_response');
    }
  }
}
