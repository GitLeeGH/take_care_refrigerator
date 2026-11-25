import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'receipt_ai_gateway.dart';
import 'receipt_analysis.dart';
import 'receipt_image_payload.dart';
import 'ingredient_photo.dart';
import 'ingredient_recognition.dart';

const ingredientImageConsentVersion = 'ingredient-image-openai-owner-v1';

class ReviewedIngredientImage extends PreparedReceiptImage {
  ReviewedIngredientImage(PreparedReceiptImage image)
    : reviewedAt = DateTime.now().toUtc(),
      super(image.bytes, image.width, image.height);
  final DateTime reviewedAt;
  String get consentVersion => ingredientImageConsentVersion;
}

class SupabaseIngredientRecognizer implements IngredientRecognizer {
  SupabaseIngredientRecognizer({
    required this.endpoint,
    required this.publishableKey,
    required this.accessToken,
    required this.currentOwner,
    http.Client Function()? clientFactory,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 50),
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _clock = clock ?? DateTime.now;
  @override
  bool get available => true;
  @override
  Future<List<IngredientCandidate>> recognize(IngredientPhotoDraft photo) =>
      Future.error(const ReceiptAiFailure('consent_expired'));
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
    if (result['contract_version'] != 'ingredient-owner-v1' ||
        result['access_mode'] != 'single_owner' ||
        result['authenticated_owner_id'] != owner ||
        result['monthly_limit_usd'] != 10 ||
        result['monthly_limit_micro_usd'] != 10000000 ||
        result['reservation_micro_usd'] != 600000 ||
        result['daily_request_limit'] != 10 ||
        result['budget_scope'] != 'app_shared') {
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

  Future<List<IngredientCandidate>> recognizeReviewed({
    required ReviewedIngredientImage image,
    required ReceiptAiReviewContext context,
    required ReceiptAiReviewContext? Function() currentContext,
  }) async {
    if (!context.matches(currentContext())) {
      throw const ReceiptAnalysisDiscarded();
    }
    final age = _clock().toUtc().difference(image.reviewedAt);
    if (age.isNegative ||
        age > const Duration(minutes: 10) ||
        image.consentVersion != ingredientImageConsentVersion) {
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
        'consent_version': ingredientImageConsentVersion,
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
    final rows = result['candidates'];
    const categories = {
      '채소',
      '과일',
      '육류',
      '해산물',
      '유제품',
      '달걀',
      '곡류',
      '콩 가공품',
      '양념',
      '기타',
    };
    if (rows is! List || rows.length > 30)
      throw const ReceiptAiFailure('invalid_response');
    final candidates = <IngredientCandidate>[];
    for (final row in rows) {
      if (row is! Map ||
          row.length != 2 ||
          row['name'] is! String ||
          (row['name'] as String).trim().isEmpty ||
          (row['name'] as String).runes.length > 80 ||
          !categories.contains(row['category']))
        throw const ReceiptAiFailure('invalid_response');
      candidates.add(
        IngredientCandidate(
          name: row['name'] as String,
          category: row['category'] as String,
        ),
      );
    }
    return List.unmodifiable(candidates);
  }
}
