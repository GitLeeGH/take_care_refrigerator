import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'meal_assistant.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../providers.dart';

abstract interface class MealAssistantGateway {
  bool get enabled;
  bool supports(MealAssistantTask task);
  Future<MealAssistantResult> ask(
    MealAssistantConsent consent, {
    required bool Function() isCurrent,
  });
}

/// A read-only readiness check must succeed before an automatic attempt is reserved.
abstract interface class AutomaticDispatchGateway {
  Future<MealAssistantResult> askAutomatic(
    MealAssistantConsent consent, {
    required bool Function() isCurrent,
    required Future<bool> Function() beforeDispatch,
  });
}

final mealAssistantGatewayProvider = Provider<MealAssistantGateway>((ref) {
  if (!mealAssistantRolloutEnabled) return const DisabledMealAssistantGateway();
  final client = ref.watch(supabaseProvider);
  return configuredMealAssistantGateway(
    baseUrl: dotenv.env['SUPABASE_URL'] ?? '',
    publishableKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    accessToken: () {
      final session = client.auth.currentSession;
      if (session == null || session.isExpired || session.user.isAnonymous) {
        return null;
      }
      return session.accessToken;
    },
  );
});

/// Only the reviewed project and menu task are enabled by this rollout.
MealAssistantGateway configuredMealAssistantGateway({
  required String baseUrl,
  required String publishableKey,
  required String? Function() accessToken,
  http.Client Function()? clientFactory,
}) {
  final url = Uri.tryParse(baseUrl);
  if (url == null ||
      url.scheme != 'https' ||
      url.host != 'brghwnwkfhbhamrrrqnr.supabase.co' ||
      url.port != 443 ||
      url.userInfo.isNotEmpty ||
      url.hasQuery ||
      url.hasFragment ||
      (url.path.isNotEmpty && url.path != '/') ||
      publishableKey.isEmpty) {
    return const DisabledMealAssistantGateway();
  }
  return HttpMealAssistantGateway(
    endpoint: url.replace(path: '/functions/v1/cooking-assist'),
    publishableKey: publishableKey,
    accessToken: accessToken,
    clientFactory: clientFactory ?? http.Client.new,
    allowedTasks: const {MealAssistantTask.menus},
    requireOwnerContract: true,
  );
}

class DisabledMealAssistantGateway implements MealAssistantGateway {
  const DisabledMealAssistantGateway();
  @override
  bool get enabled => false;
  @override
  bool supports(MealAssistantTask task) => false;
  @override
  Future<MealAssistantResult> ask(
    MealAssistantConsent consent, {
    required bool Function() isCurrent,
  }) async => throw const MealAssistantFailure('not_ready');
}

/// Ready for injection only after rollout approval. A fixed backend receives the
/// app auth token; OpenAI never receives that token, owner or session identifiers.
class HttpMealAssistantGateway
    implements MealAssistantGateway, AutomaticDispatchGateway {
  HttpMealAssistantGateway({
    required this.endpoint,
    required this.publishableKey,
    required this.accessToken,
    required this.clientFactory,
    this.timeout = const Duration(seconds: 50),
    this.requireOwnerContract = false,
    Set<MealAssistantTask> allowedTasks = const {...MealAssistantTask.values},
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       _allowedTasks = Set.unmodifiable(allowedTasks);
  final Uri endpoint;
  final String publishableKey;
  final String? Function() accessToken;
  final http.Client Function() clientFactory;
  final DateTime Function() now;
  final Duration timeout;
  final bool requireOwnerContract;
  final Set<MealAssistantTask> _allowedTasks;
  final _attempted = <String>{};
  @override
  bool get enabled => true;
  @override
  bool supports(MealAssistantTask task) => _allowedTasks.contains(task);

  Future<Map<String, dynamic>> _call(String method, {Object? body}) async {
    final token = accessToken();
    if (endpoint.scheme != 'https' ||
        endpoint.host != 'brghwnwkfhbhamrrrqnr.supabase.co' ||
        endpoint.path != '/functions/v1/cooking-assist' ||
        endpoint.port != 443 ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment ||
        token == null ||
        token.isEmpty) {
      throw const MealAssistantFailure('not_ready');
    }
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
        throw const MealAssistantFailure('invalid_response');
      }
      final remaining = timeout - elapsed.elapsed;
      if (remaining <= Duration.zero) throw TimeoutException('deadline');
      final bytes = <int>[];
      await (() async {
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 65536) {
            throw const MealAssistantFailure('invalid_response');
          }
          bytes.addAll(chunk);
        }
      })().timeout(remaining);
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map<String, dynamic>) {
        throw const MealAssistantFailure('invalid_response');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final code = value['error'];
        throw MealAssistantFailure(
          const {
                'not_ready',
                'budget_exhausted',
                'duplicate_request',
                'rate_limited',
                'stale',
                'invalid_request',
              }.contains(code)
              ? code as String
              : 'invalid_response',
        );
      }
      return value;
    } on TimeoutException {
      throw MealAssistantFailure(method == 'POST' ? 'timeout' : 'not_ready');
    } on MealAssistantFailure {
      rethrow;
    } catch (_) {
      throw const MealAssistantFailure('invalid_response');
    } finally {
      elapsed.stop();
      client.close();
    }
  }

  void _current(MealAssistantConsent consent, bool Function() isCurrent) {
    if (!isCurrent()) throw const MealAssistantFailure('stale');
    if (!{
          mealAssistantConsentVersion,
          automaticMealConsentVersion,
          automaticMealPeriodConsentVersion,
          manualMealPeriodConsentVersion,
        }.contains(consent.consentVersion) ||
        ({
              automaticMealConsentVersion,
              automaticMealPeriodConsentVersion,
              manualMealPeriodConsentVersion,
            }.contains(consent.consentVersion) &&
            consent.draft.data['task'] != 'menus') ||
        ({
              automaticMealPeriodConsentVersion,
              manualMealPeriodConsentVersion,
            }.contains(consent.consentVersion)
            ? !const {
                'breakfast',
                'lunch',
                'dinner',
              }.contains(consent.mealPeriod)
            : consent.mealPeriod != null) ||
        consent.owner.isEmpty ||
        consent.session.isEmpty ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(consent.requestId)) {
      throw const MealAssistantFailure('consent_required');
    }
    final age = now().toUtc().difference(consent.grantedAt.toUtc());
    if (age.isNegative || age > const Duration(minutes: 10)) {
      throw const MealAssistantFailure('consent_required');
    }
  }

  @override
  Future<MealAssistantResult> ask(
    MealAssistantConsent consent, {
    required bool Function() isCurrent,
  }) => _ask(consent, isCurrent: isCurrent);

  @override
  Future<MealAssistantResult> askAutomatic(
    MealAssistantConsent consent, {
    required bool Function() isCurrent,
    required Future<bool> Function() beforeDispatch,
  }) => _ask(consent, isCurrent: isCurrent, beforeDispatch: beforeDispatch);

  Future<MealAssistantResult> _ask(
    MealAssistantConsent consent, {
    required bool Function() isCurrent,
    Future<bool> Function()? beforeDispatch,
  }) async {
    if (!_allowedTasks.any((task) => task.name == consent.draft.data['task'])) {
      throw const MealAssistantFailure('not_ready');
    }
    _current(consent, isCurrent);
    if (!_attempted.add(consent.requestId)) {
      throw const MealAssistantFailure('duplicate_request');
    }
    final status = await _call('GET');
    _current(consent, isCurrent);
    if (status['ready'] != true ||
        status['monthly_limit_usd'] != 10 ||
        status['budget_scope'] != 'app-ai-shared-v1') {
      throw MealAssistantFailure(
        status['reason'] == 'budget_exhausted'
            ? 'budget_exhausted'
            : 'not_ready',
      );
    }
    if (requireOwnerContract) {
      final expiry = status['price_review_expires_at'];
      final deadline = expiry is String ? DateTime.tryParse(expiry) : null;
      final tasks = status['allowed_tasks'];
      if (status['contract_version'] != 'cooking-owner-v1' ||
          status['access_mode'] != 'single_owner' ||
          status['owner_eligible'] != true ||
          status['authenticated_owner_id'] != consent.owner ||
          status['daily_request_limit'] != 10 ||
          status['reservation_micro_usd'] != 600000 ||
          tasks is! List ||
          tasks.length != 1 ||
          tasks.single != 'menus' ||
          deadline == null ||
          !deadline.isAfter(now().toUtc())) {
        throw const MealAssistantFailure('not_ready');
      }
    }
    // Automatic grants are distinct from one-request consent. Old servers must
    // stop before receiving ingredient text; never silently downgrade consent.
    if (consent.consentVersion == automaticMealConsentVersion &&
        status['automatic_consent_version'] != automaticMealConsentVersion) {
      throw const MealAssistantFailure('automatic_not_ready');
    }
    if (consent.consentVersion == automaticMealPeriodConsentVersion &&
        (status['automatic_meal_period_version'] != 'meal-period-v1' ||
            status['automatic_meal_period_consent_version'] !=
                automaticMealPeriodConsentVersion)) {
      throw const MealAssistantFailure('automatic_not_ready');
    }
    if (consent.consentVersion == manualMealPeriodConsentVersion &&
        (status['manual_meal_period_version'] != 'meal-period-v1' ||
            status['manual_meal_period_consent_version'] !=
                manualMealPeriodConsentVersion)) {
      throw const MealAssistantFailure('manual_not_ready');
    }
    if (beforeDispatch != null) {
      if (!await beforeDispatch()) {
        throw const MealAssistantFailure('automatic_rate_limited');
      }
      _current(consent, isCurrent);
    }
    final response = await _call(
      'POST',
      body: {
        'request_id': consent.requestId,
        'input_revision': consent.draft.revision,
        'input_json': consent.draft.encoded,
        'consent_version': consent.consentVersion,
        if ({
          automaticMealPeriodConsentVersion,
          manualMealPeriodConsentVersion,
        }.contains(consent.consentVersion))
          'meal_period': consent.mealPeriod,
      },
    );
    _current(consent, isCurrent);
    if (response['request_id'] != consent.requestId ||
        response['input_revision'] != consent.draft.revision ||
        response['owner_id'] != consent.owner ||
        response['needs_review'] != true) {
      throw const MealAssistantFailure('invalid_response');
    }
    return MealAssistantResult.parse(response['result'], consent.draft);
  }
}
