import '../services/home_ai_selection.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models.dart';
import '../providers.dart';
import '../ingredient_matching.dart';
import '../services/cooking_steps.dart';
import '../services/curation_preferences.dart';
import '../services/meal_assistant.dart';
import '../services/meal_assistant_gateway.dart';

/// Uses a reviewed local shortlist. All output remains a separate suggestion;
/// opening this page never sends data, changes recipes or deducts inventory.
class MealAssistantToolsPage extends ConsumerStatefulWidget {
  const MealAssistantToolsPage({
    super.key,
    required this.recipes,
    this.menuMode = false,
  });
  final List<Recipe> recipes;
  final bool menuMode;
  @override
  ConsumerState<MealAssistantToolsPage> createState() =>
      _MealAssistantToolsPageState();
}

class _MealAssistantToolsPageState
    extends ConsumerState<MealAssistantToolsPage> {
  late final CurationIdentity _identity;
  late final StreamSubscription<void> _subscription;
  final _replacement = TextEditingController();
  late MealAssistantTask _task;
  int _epoch = 0, _sourceServings = 2, _targetServings = 1;
  String? _fromIngredient, _message, _resultRevision;
  bool _busy = false, _invalidated = false, _servingsConfirmed = false;
  MealAssistantDraft? _currentDraft;
  MealAssistantResult? _result;
  ModalRoute<dynamic>? _reviewRoute;
  NavigatorState? _reviewNavigator;
  @override
  void initState() {
    super.initState();
    _task = widget.menuMode ? MealAssistantTask.menus : MealAssistantTask.steps;
    _identity = ref.read(curationIdentityProvider);
    _subscription = _identity.changes.listen((_) {
      if (!mounted) return;
      setState(() {
        _epoch++;
        _invalidated = true;
        _currentDraft = null;
        _result = null;
        _replacement.clear();
      });
      // Remove this exact review route, never whichever screen is now on top.
      final route = _reviewRoute, navigator = _reviewNavigator;
      _reviewRoute = null;
      _reviewNavigator = null;
      if (route != null && route.isActive && navigator?.mounted == true) {
        navigator!.removeRoute(route);
      }
    });
  }

  @override
  void dispose() {
    _epoch++;
    _subscription.cancel();
    _replacement.dispose();
    super.dispose();
  }

  void _edit(VoidCallback change) => setState(() {
    change();
    _result = null;
    _message = null;
    _currentDraft = null;
  });

  MealAssistantDraft _draft(List<Recipe> recipes, List<String> pantry) =>
      MealAssistantDraft(
        task: _task,
        candidates: [
          for (final recipe in recipes)
            {
              'id': recipe.id,
              'name': recipe.name,
              'ingredients': recipe.requiredIngredients,
              'steps': widget.menuMode
                  ? <String>[]
                  : savedCookingSteps(
                      recipe.displayDescription,
                      unverified: recipe.hasUnverifiedSteps,
                    ),
            },
        ],
        pantry: pantry,
        fromIngredient: _task == MealAssistantTask.substitute
            ? (_fromIngredient ?? '')
            : '',
        toIngredient: _task == MealAssistantTask.substitute
            ? _replacement.text.trim()
            : '',
        sourceServings: _task == MealAssistantTask.portions
            ? _sourceServings
            : null,
        targetServings: _task == MealAssistantTask.portions
            ? _targetServings
            : null,
      );

  Future<void> _ask(MealAssistantDraft draft) async {
    final gateway = ref.read(mealAssistantGatewayProvider);
    if (_busy || _invalidated || !gateway.supports(_task)) return;
    final owner = _identity.account, epoch = _epoch;
    if (owner == null) {
      setState(() => _message = '로그인한 뒤 이용해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      _result = null;
    });
    bool current() =>
        mounted &&
        !_invalidated &&
        _identity.account == owner &&
        epoch == _epoch &&
        _currentDraft?.revision == draft.revision;
    try {
      final agreed = await showDialog<bool>(
        context: context,
        builder: (context) {
          _reviewRoute = ModalRoute.of(context);
          _reviewNavigator = Navigator.of(context);
          return AlertDialog(
            title: const Text('OpenAI로 보낼 내용 확인'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '아래 메뉴·재료·조리 정보와 선택한 요청을 OpenAI에 보내요. '
                    '사진, 연락처, 계정 정보, 알레르기·건강 정보는 보내지 마세요. '
                    '영수증 AI를 포함한 앱 전체 월 한도는 10달러예요. '
                    '요청 실패에도 비용이 발생할 수 있고 자동 재시도하지 않아요.',
                  ),
                  const SizedBox(height: 12),
                  const Text('전송 내용 전체'),
                  SelectableText(
                    const JsonEncoder.withIndent('  ').convert(draft.data),
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
                child: const Text('이번 내용 전송에 동의'),
              ),
            ],
          );
        },
      );
      _reviewRoute = null;
      _reviewNavigator = null;
      if (agreed != true || !current()) return;
      final consent = MealAssistantConsent(
        owner: owner,
        session: '$epoch',
        draft: draft,
        grantedAt: DateTime.now(),
        requestId: newMealAssistantRequestId(),
      );
      final result = await gateway.ask(consent, isCurrent: current);
      if (!current()) return;
      ref.read(homeAiSelectionProvider.notifier).save(consent, result);
      setState(() {
        _result = result;
        _resultRevision = draft.revision;
      });
    } on MealAssistantFailure catch (error) {
      if (current()) setState(() => _message = error.message);
    } catch (_) {
      if (current()) {
        setState(
          () =>
              _message = const MealAssistantFailure('invalid_response').message,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gateway = ref.watch(mealAssistantGatewayProvider);
    final inventory = ref.watch(ingredientsProvider);
    final pantry = ref.watch(usableIngredientNamesProvider);
    final recipes = widget.recipes
        .where(
          (r) =>
              r.eligibleForRecommendation &&
              (!widget.menuMode ||
                  IngredientAvailability(
                    r.requiredIngredients,
                    pantry,
                  ).ownedIngredients.isNotEmpty),
        )
        .take(widget.menuMode ? 10 : 1)
        .toList();
    final ready =
        !inventory.isLoading &&
        !inventory.hasError &&
        recipes.isNotEmpty &&
        !_invalidated;
    MealAssistantDraft? draft;
    if (ready && (_task != MealAssistantTask.portions || _servingsConfirmed)) {
      try {
        draft = _draft(recipes, pantry);
      } on MealAssistantFailure {
        /* Inline input guidance below. */
      }
    }
    _currentDraft = draft;
    final result = _resultRevision == draft?.revision ? _result : null;
    return Scaffold(
      appBar: AppBar(title: Text(widget.menuMode ? 'AI 메뉴 제안' : 'AI 요리 도우미')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_invalidated) ...[
              const Text('계정이 바뀌어 이 화면의 입력과 답변을 지웠어요. 이전 화면에서 다시 열어 주세요.'),
              TextButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text('돌아가기'),
              ),
            ] else ...[
              Text(
                gateway.supports(_task)
                    ? '전송 전 내용을 확인해요'
                    : 'AI 연결 준비 중 · 현재 외부 전송 없음',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(mealAssistantSafetyNotice),
              const SizedBox(height: 20),
              if (inventory.isLoading) const Text('재료를 불러오는 중이에요.'),
              if (inventory.hasError)
                TextButton(
                  onPressed: () => ref.invalidate(ingredientsProvider),
                  child: const Text('재료 다시 불러오기'),
                ),
              if (ready) ...[
                if (widget.menuMode) ...[
                  const Text(
                    '현재 불러온 후보 · 기기 내 재료 매칭',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    '기존 추천에서 넘어온 최대 10개 후보 중 먼저 3개를 보여줘요. 아래는 AI 결과가 아니에요.',
                  ),
                  for (final recipe in recipes.take(3))
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipe.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '보유 재료 ${IngredientAvailability(recipe.requiredIngredients, pantry).ownedIngredients.length}/${recipe.requiredIngredients.length}개',
                            ),
                            Text(
                              '추가 확인: ${IngredientAvailability(recipe.requiredIngredients, pantry).missingIngredients.join(', ')}',
                            ),
                          ],
                        ),
                      ),
                    ),
                ] else ...[
                  Text(
                    recipes.single.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final pair in [
                        (MealAssistantTask.steps, '조리 단계'),
                        (MealAssistantTask.substitute, '재료 대체'),
                        (MealAssistantTask.portions, '인분 변경'),
                      ])
                        ChoiceChip(
                          label: Text(pair.$2),
                          selected: _task == pair.$1,
                          onSelected: _busy
                              ? null
                              : (_) => _edit(() => _task = pair.$1),
                        ),
                    ],
                  ),
                  if (_task == MealAssistantTask.substitute) ...[
                    const SizedBox(height: 12),
                    const Text('바꿀 재료를 골라 주세요'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final name in recipes.single.requiredIngredients)
                          ChoiceChip(
                            label: Text(name),
                            selected: _fromIngredient == name,
                            onSelected: _busy
                                ? null
                                : (_) => _edit(() => _fromIngredient = name),
                          ),
                      ],
                    ),
                    TextField(
                      controller: _replacement,
                      enabled: !_busy,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: '대신 사용할 재료 이름',
                        hintText: '예: 양파',
                      ),
                      onChanged: (_) => _edit(() {}),
                    ),
                    const Text(
                      '알레르기나 건강 정보는 입력하지 마세요. 대체 가능 여부와 맛·질감 차이를 물어봐요.',
                    ),
                  ],
                  if (_task == MealAssistantTask.portions) ...[
                    const Text(
                      '원래 인분은 저장된 원문을 확인해 직접 선택하세요. 분량이 없는 재료는 임의로 만들지 않아요.',
                    ),
                    _servings('원래 인분', _sourceServings, (v) {
                      _sourceServings = v;
                      _servingsConfirmed = false;
                    }),
                    _servings(
                      '원하는 인분',
                      _targetServings,
                      (v) => _targetServings = v,
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('원문에서 원래 인분을 확인했어요'),
                      value: _servingsConfirmed,
                      onChanged: _busy
                          ? null
                          : (value) =>
                                _edit(() => _servingsConfirmed = value == true),
                    ),
                    Text(
                      '단순 분량 배율: ${(_targetServings / _sourceServings).toStringAsFixed(2)}배. '
                      '조리 시간·온도와 간은 이 비율로 자동 변경하지 마세요.',
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    '저장된 조리 정보',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (savedCookingSteps(
                    recipes.single.displayDescription,
                    unverified: recipes.single.hasUnverifiedSteps,
                  ).isEmpty)
                    const Text(
                      '확인된 조리 단계가 없어요. AI를 연결한 뒤에는 별도의 생성 제안으로 구분해 보여줘요.',
                    )
                  else
                    for (final step in savedCookingSteps(
                      recipes.single.displayDescription,
                      unverified: recipes.single.hasUnverifiedSteps,
                    ))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(step),
                      ),
                ],
              ] else if (!inventory.isLoading && !inventory.hasError)
                const Text('현재 추천할 수 있는 메뉴가 없어요. 재료와 메뉴 목록을 먼저 확인해 주세요.'),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed:
                    ready && draft != null && gateway.supports(_task) && !_busy
                    ? () => _ask(draft!)
                    : null,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(
                  _busy
                      ? '답변 기다리는 중'
                      : gateway.supports(_task)
                      ? '보낼 내용 확인'
                      : 'AI 연결 후 사용 가능',
                ),
              ),
              if (gateway.supports(_task) && ready && draft == null)
                const Text('선택한 재료와 입력을 확인해 주세요. 너무 긴 조리 정보는 전송하지 않아요.'),
              if (_message != null)
                Semantics(liveRegion: true, child: Text(_message!)),
              if (result != null) ...[
                const SizedBox(height: 20),
                const Text(
                  'AI 생성 제안 · 확인 필요',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                for (final menu in result.menus)
                  ListTile(
                    title: Text(
                      recipes.firstWhere((r) => r.id == menu.id).name,
                    ),
                    subtitle: Text(menu.reason),
                  ),
                if (result.answer.isNotEmpty) Text(result.answer),
                for (var i = 0; i < result.steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('${i + 1}. ${result.steps[i]}'),
                  ),
                for (final warning in result.warnings) Text('주의: $warning'),
                const Text(mealAssistantSafetyNotice),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _servings(String label, int value, void Function(int) change) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text('$label: $value인분'),
            IconButton(
              tooltip: '$label 줄이기',
              onPressed: _busy || value <= 1
                  ? null
                  : () => _edit(() => change(value - 1)),
              icon: const Icon(Icons.remove),
            ),
            IconButton(
              tooltip: '$label 늘리기',
              onPressed: _busy || value >= 20
                  ? null
                  : () => _edit(() => change(value + 1)),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      );
}
