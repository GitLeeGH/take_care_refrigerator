import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import 'curation_preferences.dart';
import 'home_ai_selection.dart';
import 'meal_assistant.dart';
import 'meal_assistant_gateway.dart';
import 'home_meal_request_context.dart';

MealAssistantDraft homeAutomaticDraft(
  List<Recipe> recipes,
  List<String> pantry,
) => MealAssistantDraft(
  task: MealAssistantTask.menus,
  candidates: [
    for (final recipe
        in recipes.where((r) => r.eligibleForRecommendation).take(10))
      {
        'id': recipe.id,
        'name': recipe.name,
        'ingredients': recipe.requiredIngredients,
        'steps': <String>[],
      },
  ],
  pantry: pantry,
);

/// Consent is deliberately memory-only and must never be migrated from the
/// one-request consent or inferred from the existing account preferences.
class HomeAutomaticGrant {
  const HomeAutomaticGrant(
    this.owner,
    this.boundary,
    this.grantedAt, {
    this.mealPeriodConsent = false,
  });
  final bool mealPeriodConsent;
  final String owner;
  final int boundary;
  final DateTime grantedAt;
  bool valid(String? account, int epoch, DateTime now) =>
      owner == account &&
      boundary == epoch &&
      !now.isBefore(grantedAt) &&
      now.difference(grantedAt) < const Duration(hours: 24);
}

abstract interface class HomeAutomaticAttemptStore {
  /// Record BEFORE dispatch. Storage failure must block a paid request.
  Future<bool> reserve(String owner, String revision, DateTime now);
}

/// Hashes and timestamps only, never ingredient text or generated answers.
/// Persist attempts across app restarts and keep failed/uncertain attempts.
class PreferencesHomeAutomaticAttemptStore
    implements HomeAutomaticAttemptStore {
  @override
  Future<bool> reserve(String owner, String revision, DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final key =
        'home_automatic_attempt_v2_${sha256.convert(utf8.encode(owner))}';
    await prefs.reload();
    final source = prefs.getString(key);
    final utc = now.toUtc();
    final day = utc.toIso8601String().substring(0, 10);
    var revisions = <String>[];
    if (source != null) {
      final saved = jsonDecode(source);
      if (saved is! Map ||
          saved['version'] != 2 ||
          saved['day'] is! String ||
          saved['at'] is! String ||
          saved['revisions'] is! List ||
          !(saved['revisions'] as List).every((v) => v is String)) {
        throw const FormatException('Invalid automatic request journal');
      }
      final previous = DateTime.parse(saved['at'] as String).toUtc();
      // Clock rollback also blocks instead of resetting the allowance.
      if (utc.difference(previous) < const Duration(hours: 6)) return false;
      if (saved['day'] == day) {
        revisions = (saved['revisions'] as List).cast<String>();
        if (revisions.length >= 2 || revisions.contains(revision)) return false;
      }
    }
    return prefs.setString(
      key,
      jsonEncode({
        'version': 2,
        'day': day,
        'at': utc.toIso8601String(),
        'revisions': [...revisions, revision],
      }),
    );
  }
}

enum HomeAutomaticPhase { off, waiting, busy, cached, limited, paused }

class HomeAutomaticCurationController extends ChangeNotifier {
  HomeAutomaticCurationController({
    required this.identity,
    required this.gateway,
    required this.attempts,
    required this.readCache,
    required this.saveResult,
    this.restoreCache,
    this.clearCache,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    _subscription = identity.changes.listen((_) => revoke());
  }
  final CurationIdentity identity;
  final MealAssistantGateway gateway;
  final HomeAutomaticAttemptStore attempts;
  final HomeAiSelection? Function() readCache;
  final void Function(MealAssistantConsent, MealAssistantResult) saveResult;
  final Future<void> Function(String owner, MealAssistantDraft draft)?
  restoreCache;
  final void Function()? clearCache;
  final DateTime Function() now;
  late final StreamSubscription<void> _subscription;
  HomeAutomaticGrant? _grant;
  HomeAutomaticPhase phase = HomeAutomaticPhase.off;
  String? failureCode;
  int _boundary = 0, _generation = 0;
  String? _revision, _mealPeriod;
  DateTime? _limitedAt;
  bool _busy = false, _disposed = false, _paused = false;
  bool _inFlightDispatched = false, _loadingCache = false;
  int get boundary => _boundary;
  bool get enabled => _grant?.valid(identity.account, _boundary, now()) == true;
  bool get available => gateway.supports(MealAssistantTask.menus);

  bool grant({
    required String owner,
    required int reviewedBoundary,
    bool mealPeriodConsent = false,
  }) {
    if (_disposed ||
        owner != identity.account ||
        reviewedBoundary != _boundary ||
        !available) {
      return false;
    }
    _grant = HomeAutomaticGrant(
      owner,
      _boundary,
      now(),
      mealPeriodConsent: mealPeriodConsent,
    );
    _paused = false;
    failureCode = null;
    _setPhase(HomeAutomaticPhase.waiting);
    return true;
  }

  void revoke() {
    clearCache?.call();
    _boundary++;
    _generation++;
    _grant = null;
    _paused = false;
    failureCode = null;
    _setPhase(HomeAutomaticPhase.off);
  }

  void suspend() {
    // Leaving home stops unsent work, not an already consented server response.
    // Revocation, account changes and changed input still invalidate generation.
    if (!_inFlightDispatched) _generation++;
  }

  /// Explicit retry keeps the existing valid grant, never extends its lifetime.
  void retry() {
    if (!enabled || _busy || _disposed) return;
    _paused = false;
    failureCode = null;
    _setPhase(HomeAutomaticPhase.waiting);
  }

  void _setPhase(HomeAutomaticPhase value) {
    if (_disposed || phase == value) return;
    phase = value;
    notifyListeners();
  }

  Future<void> consider(
    MealAssistantDraft draft, {
    required bool Function() isVisible,
    String? mealPeriod,
  }) async {
    if (_disposed) return;
    final contextPeriod = _grant?.mealPeriodConsent == true ? mealPeriod : null;
    if (_grant?.mealPeriodConsent == true &&
        HomeMealRequestContext.parse(contextPeriod) == null) {
      return;
    }
    if (_mealPeriod != contextPeriod) {
      _mealPeriod = contextPeriod;
      _generation++;
    }
    if (_revision != draft.revision) {
      if (readCache() != null && readCache()!.revision != draft.revision) {
        clearCache?.call();
      }
      _revision = draft.revision;
      _generation++;
    }
    if (!enabled) {
      _setPhase(HomeAutomaticPhase.off);
      return;
    }
    if (!available || _paused || _busy || _loadingCache || !isVisible()) return;
    if (_limitedAt != null &&
        now().difference(_limitedAt!) < const Duration(minutes: 5)) {
      return;
    }
    final owner = identity.account!;
    if (readCache() == null && restoreCache != null) {
      _loadingCache = true;
      final epoch = _generation;
      try {
        await restoreCache!(owner, draft);
      } finally {
        _loadingCache = false;
      }
      if (_disposed ||
          !enabled ||
          identity.account != owner ||
          epoch != _generation ||
          !isVisible()) {
        return;
      }
    }
    if (readCache()?.matches(
          owner,
          draft.revision,
          now(),
          mealPeriod: contextPeriod,
        ) ==
        true) {
      _setPhase(HomeAutomaticPhase.cached);
      return;
    }
    final generation = _generation;
    var dispatched = false;
    bool current() =>
        !_disposed &&
        enabled &&
        !_paused &&
        (dispatched || isVisible()) &&
        identity.account == owner &&
        generation == _generation &&
        _revision == draft.revision;
    _busy = true;
    _setPhase(HomeAutomaticPhase.busy);
    try {
      Future<bool> reserve() async {
        if (!current()) return false;
        final allowed = await attempts.reserve(owner, draft.revision, now());
        if (!allowed || !current()) return false;
        dispatched = true;
        _inFlightDispatched = true;
        return true;
      }

      if (gateway is! AutomaticDispatchGateway && !await reserve()) {
        if (current()) {
          _limitedAt = now();
          _setPhase(HomeAutomaticPhase.limited);
        }
        return;
      }
      if (!current()) return;
      final consent = MealAssistantConsent(
        owner: owner,
        session: 'home-auto-$_boundary',
        draft: draft,
        grantedAt: now(),
        requestId: newMealAssistantRequestId(),
        consentVersion: _grant!.mealPeriodConsent
            ? automaticMealPeriodConsentVersion
            : automaticMealConsentVersion,
        mealPeriod: contextPeriod,
      );
      final result = gateway is AutomaticDispatchGateway
          ? await (gateway as AutomaticDispatchGateway).askAutomatic(
              consent,
              isCurrent: current,
              beforeDispatch: reserve,
            )
          : await gateway.ask(consent, isCurrent: current);
      if (!current()) return;
      saveResult(consent, result);
      _setPhase(HomeAutomaticPhase.cached);
    } catch (error) {
      if (current()) {
        // No timer, retry loop or automatic recovery after an uncertain call.
        failureCode = error is MealAssistantFailure
            ? error.code
            : 'storage_or_request';
        _paused = failureCode != 'automatic_rate_limited';
        if (!_paused) _limitedAt = now();
        _setPhase(
          failureCode == 'automatic_rate_limited'
              ? HomeAutomaticPhase.limited
              : HomeAutomaticPhase.paused,
        );
      }
    } finally {
      _busy = false;
      _inFlightDispatched = false;
      if (!_disposed && phase == HomeAutomaticPhase.busy) {
        _setPhase(HomeAutomaticPhase.waiting);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _subscription.cancel();
    super.dispose();
  }
}

final homeAutomaticAttemptStoreProvider = Provider<HomeAutomaticAttemptStore>(
  (ref) => PreferencesHomeAutomaticAttemptStore(),
);
final homeAutomaticCurationProvider = Provider<HomeAutomaticCurationController>(
  (ref) {
    final controller = HomeAutomaticCurationController(
      identity: ref.watch(curationIdentityProvider),
      gateway: ref.watch(mealAssistantGatewayProvider),
      attempts: ref.watch(homeAutomaticAttemptStoreProvider),
      readCache: () => ref.read(homeAiSelectionProvider),
      restoreCache: (owner, draft) =>
          ref.read(homeAiSelectionProvider.notifier).restore(owner, draft),
      clearCache: () => ref.read(homeAiSelectionProvider.notifier).clear(),
      saveResult: (consent, result) =>
          ref.read(homeAiSelectionProvider.notifier).save(consent, result),
    );
    ref.onDispose(controller.dispose);
    return controller;
  },
);
