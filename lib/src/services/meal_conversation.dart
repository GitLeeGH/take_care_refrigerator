import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'meal_assistant.dart';

const mealConversationConsentVersion = 'meal-conversation-openai-v1';
const mealConversationRecentExchanges = 3;
const mealConversationQuestionLimit = 600;

enum MealConversationRole { user, assistant }

class MealConversationMessage {
  const MealConversationMessage(this.role, this.text);
  final MealConversationRole role;
  final String text;
  Map<String, String> get data => {'role': role.name, 'text': text};
}

bool _validText(String text, int max) =>
    text.trim().isNotEmpty &&
    text.runes.length <= max &&
    !RegExp(
      r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]|https?:|www\.|@|\b01[016789][- ]?\d{3,4}[- ]?\d{4}\b',
      caseSensitive: false,
    ).hasMatch(text);

/// Immutable review snapshot. Only completed exchanges enter context; no account,
/// expiry, meal history, photos, device IDs or implicit preference data is added.
class MealConversationDraft {
  MealConversationDraft({
    required MealAssistantDraft context,
    required List<MealConversationMessage> history,
    required String question,
  }) {
    if (!_validText(question, mealConversationQuestionLimit) ||
        history.length.isOdd ||
        history.asMap().entries.any(
          (entry) =>
              entry.value.role !=
                  (entry.key.isEven
                      ? MealConversationRole.user
                      : MealConversationRole.assistant) ||
              !_validText(
                entry.value.text,
                entry.key.isEven ? mealConversationQuestionLimit : 4000,
              ),
        )) {
      throw const MealAssistantFailure('invalid_request');
    }
    final recent = history.length > mealConversationRecentExchanges * 2
        ? history.sublist(history.length - mealConversationRecentExchanges * 2)
        : history;
    encoded = jsonEncode({
      'task': 'conversation',
      'context': context.data,
      'messages': [
        for (final message in recent) message.data,
        {'role': 'user', 'text': question.trim()},
      ],
    });
    if (utf8.encode(encoded).length > 24000) {
      throw const MealAssistantFailure('invalid_request');
    }
    revision = sha256.convert(utf8.encode(encoded)).toString();
  }
  late final String encoded, revision;
  Map<String, dynamic> get data => jsonDecode(encoded) as Map<String, dynamic>;
}

class MealConversationConsent {
  const MealConversationConsent({
    required this.owner,
    required this.session,
    required this.draft,
    required this.grantedAt,
    required this.requestId,
  });
  final String owner, session, requestId;
  final MealConversationDraft draft;
  final DateTime grantedAt;
  String get version => mealConversationConsentVersion;
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

class MealConversationAnswer {
  MealConversationAnswer._(this.answer, this.warnings);
  final String answer;
  final List<String> warnings;
  String get contextText =>
      [answer, for (final warning in warnings) '주의: $warning'].join('\n');
  factory MealConversationAnswer.parse(Object? raw) {
    if (raw is! Map ||
        raw.length != 2 ||
        raw['answer'] is! String ||
        !_validText(raw['answer'] as String, 1600) ||
        raw['warnings'] is! List ||
        (raw['warnings'] as List).length > 5 ||
        !(raw['warnings'] as List).every(
          (v) => v is String && _validText(v, 400),
        )) {
      throw const MealAssistantFailure('invalid_response');
    }
    return MealConversationAnswer._(
      raw['answer'] as String,
      List.unmodifiable((raw['warnings'] as List).cast<String>()),
    );
  }
}

abstract interface class MealConversationGateway {
  bool get enabled;
  Future<MealConversationAnswer> ask(
    MealConversationConsent consent, {
    required bool Function() isCurrent,
  });
}

class DisabledMealConversationGateway implements MealConversationGateway {
  const DisabledMealConversationGateway();
  @override
  bool get enabled => false;
  @override
  Future<MealConversationAnswer> ask(
    MealConversationConsent consent, {
    required bool Function() isCurrent,
  }) async => throw const MealAssistantFailure('not_ready');
}
