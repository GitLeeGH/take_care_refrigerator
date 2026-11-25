import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models.dart';
import '../services/curation_preferences.dart';
import '../services/home_ai_selection.dart';
import '../services/home_automatic_curation.dart';
import '../services/home_meal_period.dart';
import '../services/meal_assistant.dart';
import '../services/meal_assistant_gateway.dart';

class HomeManualCurationPanel extends ConsumerStatefulWidget {
  const HomeManualCurationPanel({
    super.key,
    required this.recipes,
    required this.pantry,
    required this.active,
    required this.mealLabel,
  });
  final List<Recipe> recipes;
  final List<String> pantry;
  final bool active;
  final String mealLabel;
  @override
  ConsumerState<HomeManualCurationPanel> createState() => _ManualState();
}

class _ManualState extends ConsumerState<HomeManualCurationPanel> {
  bool _busy = false, _hasRequested = false;
  String? _message;
  int _epoch = 0;
  StreamSubscription<void>? _identityEvents;
  String? _restored;
  MealAssistantDraft get _draft =>
      homeAutomaticDraft(widget.recipes, widget.pantry);
  @override
  void didUpdateWidget(HomeManualCurationPanel old) {
    super.didUpdateWidget(old);
    if (homeAutomaticDraft(old.recipes, old.pantry).revision !=
        _draft.revision) {
      _epoch++;
    }
  }

  @override
  void dispose() {
    _identityEvents?.cancel();
    super.dispose();
  }

  // Only this explicit button callback can send; never init, timer or fallback.
  Future<void> _request() async {
    if (_busy || !widget.active) return;
    final identity = ref.read(curationIdentityProvider),
        gateway = ref.read(mealAssistantGatewayProvider);
    final owner = identity.account;
    if (owner == null) {
      setState(() => _message = '로그인 후 추천받을 수 있어요.');
      return;
    }
    _identityEvents ??= identity.changes.listen((_) {
      _epoch++;
    });
    final epoch = _epoch, draft = _draft;
    final period = mealPeriodAt(ref.read(homeMealMomentProvider));
    final session = identity is AuthCurationIdentity
        ? identity.client.auth.currentUser?.lastSignInAt ?? ''
        : 'current';
    final notifier = ref.read(homeAiSelectionProvider.notifier);
    bool current() =>
        identity.account == owner &&
        epoch == _epoch &&
        (identity is! AuthCurationIdentity ||
            (identity.client.auth.currentUser?.lastSignInAt ?? '') == session);
    final consent = MealAssistantConsent(
      owner: owner,
      session: session.isEmpty ? 'current' : session,
      draft: draft,
      grantedAt: DateTime.now(),
      requestId: newMealAssistantRequestId(),
      consentVersion: manualMealPeriodConsentVersion,
      mealPeriod: period.name,
    );
    setState(() {
      _busy = true;
      _hasRequested = true;
      _message = null;
    });
    try {
      final result = await gateway.ask(consent, isCurrent: current);
      if (!current()) return;
      notifier.save(consent, result);
      if (mounted) setState(() => _message = '추천이 준비됐어요. 아래 메뉴를 확인하세요.');
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = switch (error is MealAssistantFailure
              ? error.code
              : 'unknown') {
            'budget_exhausted' => '이번 달 AI 이용 한도 10달러에 도달했어요.',
            'rate_limited' => '오늘 AI 이용 한도 10회에 도달했어요. UTC 기준이에요.',
            'manual_not_ready' => '추천 연결을 준비하고 있어요. 잠시 후 다시 눌러 주세요.',
            'timeout' => '응답을 확인하지 못했어요. 자동으로 다시 보내지 않아요.',
            'stale' => '계정이나 재료가 바뀌어 결과를 표시하지 않았어요.',
            _ => '추천을 받아오지 못했어요. 아래 기본 추천은 계속 볼 수 있어요.',
          },
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.read(curationIdentityProvider),
        owner = identity.account;
    if (owner != null) {
      final draft = _draft, key = '$owner:${_draft.revision}';
      if (_restored != key) {
        _restored = key;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(
              ref.read(homeAiSelectionProvider.notifier).restore(owner, draft),
            );
          }
        });
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '버튼을 누르면 보유 재료·후보 메뉴·현재 식사 구분을 OpenAI로 보내 한 번 추천받아요.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy || !widget.active ? null : _request,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(
            _busy
                ? '${widget.mealLabel} 메뉴 고르는 중…'
                : _hasRequested
                ? '다시 추천받기'
                : '동의하고 AI 추천받기',
          ),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_message!, semanticsLabel: _message),
          ),
      ],
    );
  }
}
