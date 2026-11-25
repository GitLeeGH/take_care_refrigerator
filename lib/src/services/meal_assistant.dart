import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

// Client rollout only. Server account and budget gates remain authoritative.
const mealAssistantRolloutEnabled = bool.fromEnvironment(
  'MEAL_ASSISTANT_ENABLED',
);
const mealAssistantConsentVersion = 'meal-text-openai-v1';
const automaticMealConsentVersion = 'meal-home-automatic-openai-v2';
const automaticMealPeriodConsentVersion = 'meal-home-automatic-openai-v3';
const manualMealPeriodConsentVersion = 'meal-manual-openai-v2';
const homeManualMealAiEnabled = bool.fromEnvironment(
  'HOME_MANUAL_MEAL_AI_ENABLED',
);
// Remains off until the reviewed server contract and renewal manifest are deployed.
const homeMealPeriodAiEnabled = bool.fromEnvironment(
  'HOME_MEAL_PERIOD_AI_ENABLED',
);
const mealAssistantSafetyNotice =
    'AI 제안은 틀릴 수 있어요. 알레르기·소비기한·식품 안전을 보장하지 않아요. '
    '재료의 상태와 제품 표시를 직접 확인하세요. 재고는 자동으로 바뀌지 않아요.';

enum MealAssistantTask { menus, steps, substitute, portions }

class MealAssistantFailure implements Exception {
  const MealAssistantFailure(this.code);
  final String code;
  String get message => switch (code) {
    'not_ready' => '외부 AI는 아직 연결하지 않았어요. 현재 화면은 저장된 정보로 안내해요.',
    'consent_required' => '보낼 내용을 다시 확인하고 이번 요청의 전송에 동의해 주세요.',
    'stale' => '계정이나 입력이 바뀌어 이전 요청을 폐기했어요.',
    'duplicate_request' => '이미 보낸 요청이에요. 중복 과금을 막기 위해 다시 보내지 않았어요.',
    'budget_exhausted' => '이번 달 앱 전체 AI 사용 한도에 도달했어요.',
    'timeout' => '응답을 기다리다 중단했어요. 비용이 발생했을 수 있어 자동 재시도하지 않아요.',
    'invalid_request' => '재료와 메뉴 입력의 길이 또는 형식을 확인해 주세요.',
    _ => 'AI 답변을 확인하지 못했어요. 저장된 조리 정보는 그대로 사용할 수 있어요.',
  };
  @override
  String toString() => 'MealAssistantFailure($code)';
}

bool _text(Object? value, int max, {bool empty = false}) =>
    value is String &&
    (empty || value.trim().isNotEmpty) &&
    value.runes.length <= max &&
    !RegExp(
      r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]|https?:|www\.|@',
      caseSensitive: false,
    ).hasMatch(value);
bool _keys(Map value, List<String> keys) =>
    value.length == keys.length && keys.every(value.containsKey);
void _require(bool condition, [String code = 'invalid_request']) {
  if (!condition) throw MealAssistantFailure(code);
}

/// A copied, immutable JSON snapshot. No photos, account details, expiry dates,
/// medical preferences, meal history or credentials belong in this payload.
class MealAssistantDraft {
  MealAssistantDraft({
    required MealAssistantTask task,
    required List<Map<String, Object?>> candidates,
    required List<String> pantry,
    String fromIngredient = '',
    String toIngredient = '',
    int? sourceServings,
    int? targetServings,
  }) {
    final value = <String, Object?>{
      'task': task.name,
      'candidates': candidates,
      'pantry': pantry,
      'from_ingredient': fromIngredient,
      'to_ingredient': toIngredient,
      'source_servings': sourceServings,
      'target_servings': targetServings,
    };
    _require(
      candidates.isNotEmpty && candidates.length <= 10 && pantry.length <= 60,
    );
    final ids = <String>{};
    for (final row in candidates) {
      _require(
        _keys(row, ['id', 'name', 'ingredients', 'steps']) &&
            _text(row['id'], 80) &&
            ids.add(row['id'] as String) &&
            _text(row['name'], 120),
      );
      for (final entry in [('ingredients', 40, 120), ('steps', 20, 800)]) {
        final list = row[entry.$1];
        _require(
          list is List &&
              list.length <= entry.$2 &&
              (entry.$1 != 'ingredients' || list.isNotEmpty) &&
              list.every((v) => _text(v, entry.$3)),
        );
      }
    }
    _require(pantry.every((v) => _text(v, 120)));
    _require(task == MealAssistantTask.menus || candidates.length == 1);
    if (task == MealAssistantTask.substitute) {
      _require(
        _text(fromIngredient, 120) &&
            _text(toIngredient, 120) &&
            fromIngredient != toIngredient &&
            (candidates.single['ingredients'] as List).contains(fromIngredient),
      );
    } else {
      _require(fromIngredient.isEmpty && toIngredient.isEmpty);
    }
    if (task == MealAssistantTask.portions) {
      _require(
        sourceServings != null &&
            targetServings != null &&
            sourceServings >= 1 &&
            sourceServings <= 20 &&
            targetServings >= 1 &&
            targetServings <= 20,
      );
    } else {
      _require(sourceServings == null && targetServings == null);
    }
    encoded = jsonEncode(value);
    _require(utf8.encode(encoded).length <= 24000);
    revision = sha256.convert(utf8.encode(encoded)).toString();
  }
  late final String encoded, revision;
  Map<String, dynamic> get data => jsonDecode(encoded) as Map<String, dynamic>;
  Set<String> get candidateIds => {
    for (final row in data['candidates'] as List) row['id'] as String,
  };
}

String newMealAssistantRequestId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class MealAssistantConsent {
  MealAssistantConsent({
    required this.owner,
    required this.session,
    required this.draft,
    required this.grantedAt,
    required this.requestId,
    this.consentVersion = mealAssistantConsentVersion,
    this.mealPeriod,
  });
  final String owner, session, requestId, consentVersion;
  final String? mealPeriod;
  final MealAssistantDraft draft;
  final DateTime grantedAt;
  bool current({
    required String? owner,
    required String session,
    required String revision,
    required DateTime now,
  }) {
    final age = now.toUtc().difference(grantedAt.toUtc());
    return this.owner.isNotEmpty &&
        this.owner == owner &&
        this.session == session &&
        draft.revision == revision &&
        !age.isNegative &&
        age <= const Duration(minutes: 10);
  }
}

/// Provider output is plain text only. IDs are restricted to the reviewed input.
/// There is intentionally no save, inventory, URL, executable or tool-call field.
class MealAssistantResult {
  MealAssistantResult._(this.menus, this.answer, this.steps, this.warnings);
  final List<({String id, String reason})> menus;
  final String answer;
  final List<String> steps, warnings;
  factory MealAssistantResult.parse(Object? raw, MealAssistantDraft draft) {
    const code = 'invalid_response';
    _require(
      raw is Map && _keys(raw, ['menus', 'answer', 'steps', 'warnings']),
      code,
    );
    final map = raw as Map;
    _require(
      map['menus'] is List &&
          (map['menus'] as List).length <= 3 &&
          _text(map['answer'], 1600, empty: true),
      code,
    );
    final ids = <String>{};
    final menus = <({String id, String reason})>[];
    for (final row in map['menus'] as List) {
      _require(
        row is Map &&
            _keys(row, ['id', 'reason']) &&
            row['id'] is String &&
            draft.candidateIds.contains(row['id']) &&
            ids.add(row['id'] as String) &&
            _text(row['reason'], 400),
        code,
      );
      menus.add((id: row['id'] as String, reason: row['reason'] as String));
    }
    List<String> list(String key, int max, int length) {
      final value = map[key];
      _require(
        value is List &&
            value.length <= max &&
            value.every((v) => _text(v, length)),
        code,
      );
      return List.unmodifiable((value as List).cast<String>());
    }

    final steps = list('steps', 12, 800), warnings = list('warnings', 5, 400);
    if (draft.data['task'] == 'menus') {
      _require(menus.isNotEmpty && steps.isEmpty, code);
    } else {
      _require(
        menus.isEmpty && (map['answer'] as String).trim().isNotEmpty,
        code,
      );
    }
    return MealAssistantResult._(
      List.unmodifiable(menus),
      map['answer'] as String,
      steps,
      warnings,
    );
  }
}
