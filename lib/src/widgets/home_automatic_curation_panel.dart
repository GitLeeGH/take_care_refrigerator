import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models.dart';
import '../pages/meal_assistant_page.dart';
import '../services/home_automatic_curation.dart';
import '../services/meal_assistant.dart';
import '../services/home_meal_request_context.dart';
import '../services/home_meal_period.dart';

class _SetupState extends Notifier<bool> {
  @override
  bool build() => false;
  void configured() => state = true;
}

final _setupProvider = NotifierProvider<_SetupState, bool>(_SetupState.new);

/// Local home rendering does not initialize auth, storage or the AI gateway.
/// An explicit opt-in is required before this widget can schedule network work.
class HomeAutomaticCurationPanel extends ConsumerStatefulWidget {
  const HomeAutomaticCurationPanel({
    super.key,
    required this.recipes,
    required this.pantry,
    this.active = true,
    this.onRecommendationReady,
    this.mealLabel = '오늘',
  });
  final List<Recipe> recipes;
  final List<String> pantry;
  final bool active;
  final String mealLabel;
  final VoidCallback? onRecommendationReady;
  @override
  ConsumerState<HomeAutomaticCurationPanel> createState() => _PanelState();
}

class _PanelState extends ConsumerState<HomeAutomaticCurationPanel>
    with WidgetsBindingObserver {
  HomeAutomaticCurationController? _controller;
  bool _scheduled = false, _reviewing = false, _revealResult = false;
  bool get _visible =>
      mounted &&
      widget.active &&
      !_reviewing &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) &&
      ModalRoute.of(context)?.isCurrent == true;
  MealAssistantDraft? _draft() {
    try {
      return homeAutomaticDraft(widget.recipes, widget.pantry);
    } on MealAssistantFailure {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(HomeAutomaticCurationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) _controller?.suspend();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() {});
    } else {
      _controller?.suspend();
    }
  }

  @override
  void dispose() {
    _controller?.suspend();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _schedule() {
    if (_scheduled || _controller == null) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_visible) return;
      final draft = _draft();
      if (draft != null) {
        unawaited(
          _controller!.consider(
            draft,
            mealPeriod: homeMealPeriodAiEnabled
                ? HomeMealRequestContext.at(
                    ref.read(homeMealMomentProvider),
                  ).wireValue
                : null,
            isVisible: () => _visible && _draft()?.revision == draft.revision,
          ),
        );
      }
    });
  }

  Future<void> _review() async {
    if (_reviewing) return;
    final controller = ref.read(homeAutomaticCurationProvider);
    final owner = controller.identity.account;
    final draft = _draft();
    if (owner == null || draft == null || !controller.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            owner == null
                ? '로그인한 뒤 이용해 주세요.'
                : '자동 AI 연결 준비 중이에요. 지금은 기기 내 추천을 보여드려요.',
          ),
        ),
      );
      return;
    }
    final boundary = controller.boundary;
    _reviewing = true;
    controller.suspend();
    try {
      final agreed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('홈 자동 AI 추천에 동의할까요?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('홈을 열면 냉장고 재료에 맞는 메뉴를 AI가 골라드려요.'),
                const SizedBox(height: 12),
                const Text(
                  '보유 재료 이름과 후보 음식의 이름·재료를 앱 서버를 거쳐 OpenAI로 보내요. 재료가 바뀌면 변경된 목록도 같은 범위에서 전송해요. 사진·위치·건강 정보는 보내지 않아요.',
                ),
                if (homeMealPeriodAiEnabled)
                  const Text(
                    '현재 아침·점심·저녁 구분도 OpenAI에 보내 지금 식사에 맞춰 추천해요. 정확한 시각이나 위치는 보내지 않아요.',
                  ),
                const SizedBox(height: 12),
                const Text(
                  '현재 로그인 상태에서 최대 24시간, 앱을 완전히 종료하기 전까지 유지돼요. 홈의 자동 추천 끄기로 언제든 철회할 수 있어요. 추천 결과는 이 기기에 저장해 최대 6시간만 다시 보여드려요. 추천을 끄거나 로그아웃하면 재사용하지 않아요.',
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('보내는 정보와 이용 안내'),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '보유 재료: ${widget.pantry.join(', ')}\n후보 음식: ${widget.recipes.take(10).map((r) => r.name).join(', ')}',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '각 후보 음식의 재료 목록도 함께 보내요. 연락처·로그인 정보·기피/알레르기·식사 이력은 AI에 보내지 않아요. 최소 6시간 간격, UTC 하루 최대 2회이며 기존 앱 AI 공유 한도를 따릅니다.',
                    ),
                    const SizedBox(height: 8),
                    const Text(mealAssistantSafetyNotice),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('동의하고 추천 켜기'),
            ),
          ],
        ),
      );
      if (!mounted ||
          agreed != true ||
          !widget.active ||
          !controller.grant(
            owner: owner,
            reviewedBoundary: boundary,
            mealPeriodConsent: homeMealPeriodAiEnabled,
          )) {
        return;
      }
      _controller = controller;
      _revealResult = true;
      ref.read(_setupProvider.notifier).configured();
    } finally {
      _reviewing = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(_setupProvider)) {
      _controller = ref.watch(homeAutomaticCurationProvider);
    }
    final controller = _controller;
    if (controller == null) return _content(null);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        _schedule();
        if (_revealResult && controller.phase == HomeAutomaticPhase.cached) {
          _revealResult = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_visible) widget.onRecommendationReady?.call();
          });
        }
        return _content(controller);
      },
    );
  }

  Widget _content(HomeAutomaticCurationController? controller) {
    final enabled = controller?.enabled == true;
    final message = enabled && _draft() == null
        ? '추천 준비가 어려워 내 재료 기준 메뉴를 보여드려요.'
        : switch (controller?.phase) {
            HomeAutomaticPhase.busy => '${widget.mealLabel} 메뉴를 고르고 있어요…',
            HomeAutomaticPhase.cached =>
              '${widget.mealLabel} AI 추천을 아래에서 확인하세요.',
            HomeAutomaticPhase.limited =>
              '지금은 새 AI 추천을 받을 수 없어요. 같은 재료·메뉴 조합은 UTC 하루 한 번, 전체는 하루 2회·최소 6시간 간격이에요. 아래는 내 재료 기반 추천이에요.',
            HomeAutomaticPhase.paused =>
              'AI 추천을 불러오지 못했어요. 내 재료 추천은 계속 볼 수 있어요.',
            _ =>
              enabled
                  ? '${widget.mealLabel} 추천 준비 중'
                  : '내 재료에 맞는 AI 추천을 받아보세요.',
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (controller?.phase == HomeAutomaticPhase.busy) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              icon: Icon(
                enabled
                    ? Icons.pause_circle_outline
                    : Icons.auto_awesome_outlined,
                size: 18,
              ),
              label: Text(enabled ? '자동 추천 끄기' : 'AI 추천 허용'),
              onPressed: _reviewing
                  ? null
                  : enabled
                  ? () {
                      controller!.revoke();
                    }
                  : _review,
            ),
            if (enabled && controller?.phase == HomeAutomaticPhase.paused)
              TextButton(
                onPressed: () => controller!.retry(),
                child: const Text('다시 확인'),
              ),
            TextButton(
              onPressed: () {
                controller?.suspend();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MealAssistantPage(
                      recipes: widget.recipes,
                      menuMode: true,
                    ),
                  ),
                );
              },
              child: const Text('AI에게 물어보기'),
            ),
          ],
        ),
      ],
    );
  }
}
