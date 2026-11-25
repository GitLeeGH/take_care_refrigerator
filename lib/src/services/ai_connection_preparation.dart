/// Preparation only: no transport, API keys, endpoints or external model exist.
const externalAiConnectionEnabled = false;

/// Attestations for a FUTURE review screen, not an implemented sanitizer.
/// Only opaque local revision identifiers are accepted, never image bytes/URLs.
class AiPhotoReviewDraft {
  const AiPhotoReviewDraft({
    required this.account,
    required this.revision,
    required this.recipient,
    required this.purpose,
    this.metadataRemoved = false,
    this.sensitiveRegionsRemoved = false,
    this.userReviewedSanitizedPreview = false,
  });
  final String account, revision, recipient, purpose;
  final bool metadataRemoved,
      sensitiveRegionsRemoved,
      userReviewedSanitizedPreview;
}

class AiPhotoConsentDraft {
  const AiPhotoConsentDraft({
    required this.account,
    required this.revision,
    required this.recipient,
    required this.purpose,
    required this.expiresAt,
    this.explicitlyGranted = false,
    this.revoked = false,
  });
  final String account, revision, recipient, purpose;
  final DateTime expiresAt;
  final bool explicitlyGranted, revoked;
}

List<String> aiPhotoPreparationGaps(
  AiPhotoReviewDraft photo,
  AiPhotoConsentDraft? consent, {
  required String? currentAccount,
  required DateTime now,
}) => [
  if (currentAccount == null || photo.account != currentAccount) 'account',
  if (photo.revision.isEmpty ||
      photo.recipient.isEmpty ||
      photo.purpose.isEmpty)
    'disclosure',
  if (!photo.metadataRemoved) 'metadata-removal',
  if (!photo.sensitiveRegionsRemoved) 'sensitive-region-removal',
  if (!photo.userReviewedSanitizedPreview) 'sanitized-preview-review',
  if (consent == null ||
      !consent.explicitlyGranted ||
      consent.revoked ||
      !consent.expiresAt.isAfter(now) ||
      consent.account != currentAccount ||
      consent.revision != photo.revision ||
      consent.recipient != photo.recipient ||
      consent.purpose != photo.purpose)
    'explicit-current-consent',
];

/// No checklist result can enable transport in this preparation build.
bool canSendExternalAiPhoto(
  AiPhotoReviewDraft photo,
  AiPhotoConsentDraft? consent, {
  required String? currentAccount,
  required DateTime now,
}) =>
    externalAiConnectionEnabled &&
    aiPhotoPreparationGaps(
      photo,
      consent,
      currentAccount: currentAccount,
      now: now,
    ).isEmpty;

/// Synthetic cost units only. No provider prices or currency promises.
/// Zero defaults prohibit even a hypothetical request until limits are decided.
class AiBudgetDraft {
  const AiBudgetDraft({
    this.perRequest = 0,
    this.perDay = 0,
    this.perMonth = 0,
    this.callsPerDay = 0,
    this.maxImages = 0,
    this.maxInputTokens = 0,
    this.maxOutputTokens = 0,
  });
  final int perRequest,
      perDay,
      perMonth,
      callsPerDay,
      maxImages,
      maxInputTokens,
      maxOutputTokens;
}

/// In-memory feasibility simulation, NOT billing enforcement. A future trusted
/// server must reserve worst-case cost atomically across devices and restarts.
class AiBudgetDryRun {
  AiBudgetDryRun(this.limits);
  final AiBudgetDraft limits;
  final _ids = <String>{};
  final _daily = <String, int>{},
      _monthly = <String, int>{},
      _calls = <String, int>{};
  bool reserve({
    required String requestId,
    required DateTime now,
    required int worstCaseCost,
    required int images,
    required int inputTokens,
    required int outputTokens,
  }) {
    if (requestId.isEmpty ||
        _ids.contains(requestId) ||
        worstCaseCost <= 0 ||
        images < 0 ||
        inputTokens < 0 ||
        outputTokens <= 0 ||
        images > limits.maxImages ||
        inputTokens > limits.maxInputTokens ||
        outputTokens > limits.maxOutputTokens ||
        worstCaseCost > limits.perRequest) {
      return false;
    }
    final utc = now.toUtc();
    final month = '${utc.year}-${utc.month}', day = '$month-${utc.day}';
    if ((_daily[day] ?? 0) + worstCaseCost > limits.perDay ||
        (_monthly[month] ?? 0) + worstCaseCost > limits.perMonth ||
        (_calls[day] ?? 0) + 1 > limits.callsPerDay) {
      return false;
    }
    _ids.add(requestId);
    _daily[day] = (_daily[day] ?? 0) + worstCaseCost;
    _monthly[month] = (_monthly[month] ?? 0) + worstCaseCost;
    _calls[day] = (_calls[day] ?? 0) + 1;
    // No automatic refund/retry: timeout may still have incurred provider cost.
    return true;
  }
}

/// Future model ranking can only refer to supplied saved recipe IDs. This
/// adapter cannot invent recipe contents, safety claims, dates or medical advice.
List<String> reviewAiRecipeIds(
  Iterable<String> proposed,
  Set<String> suppliedIds,
) {
  final seen = <String>{};
  return [
    for (final id in proposed)
      if (suppliedIds.contains(id) && seen.add(id)) id,
  ];
}
