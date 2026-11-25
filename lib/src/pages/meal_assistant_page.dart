import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../widgets/app_presentation.dart';
import '../ingredient_matching.dart';
import '../models.dart';
import '../providers.dart';
import '../services/cooking_steps.dart';
import '../services/curation_preferences.dart';
import '../services/meal_assistant.dart';
import '../services/meal_conversation.dart';
import '../services/meal_conversation_provider.dart';
import 'meal_assistant_tools_page.dart';

/// Chat history lives only in this route and is erased on any account/session
/// change. Existing menu requests remain on their original consented path.
class MealAssistantPage extends ConsumerStatefulWidget {
  const MealAssistantPage({
    super.key,
    required this.recipes,
    this.menuMode = false,
  });
  final List<Recipe> recipes;
  final bool menuMode;
  @override
  ConsumerState<MealAssistantPage> createState() => _MealAssistantPageState();
}

class _MealAssistantPageState extends ConsumerState<MealAssistantPage> {
  late final CurationIdentity _identity;
  late final StreamSubscription<void> _subscription;
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _composerKey = GlobalKey();
  final _scroll = ScrollController();
  final _history = <MealConversationMessage>[];
  MealAssistantDraft? _context;
  String? _message, _pending;
  bool _busy = false, _invalidated = false;
  int _epoch = 0;
  ModalRoute<dynamic>? _reviewRoute;
  NavigatorState? _reviewNavigator;

  @override
  void initState() {
    super.initState();
    _identity = ref.read(curationIdentityProvider);
    _subscription = _identity.changes.listen((_) {
      if (!mounted) return;
      _closeReview();
      setState(() {
        _epoch++;
        _invalidated = true;
        _busy = false;
        _history.clear();
        _input.clear();
        _context = null;
        _pending = null;
        _message = null;
      });
    });
  }

  void _closeReview() {
    final route = _reviewRoute, navigator = _reviewNavigator;
    _reviewRoute = null;
    _reviewNavigator = null;
    if (route != null && route.isActive && navigator?.mounted == true) {
      navigator!.removeRoute(route);
    }
  }

  @override
  void dispose() {
    _epoch++;
    _subscription.cancel();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> _newConversation() async {
    if (_invalidated) return;
    if (_history.isEmpty && _input.text.isEmpty && !_busy) return;
    final epoch = _epoch;
    final reset = await showDialog<bool>(
      context: context,
      builder: (context) {
        _reviewRoute = ModalRoute.of(context);
        _reviewNavigator = Navigator.of(context);
        return AlertDialog(
          title: const Text('새 대화를 시작할까요?'),
          content: const Text(
            '이 화면의 대화와 입력을 지워요. 이미 보낸 요청은 취소할 수 없고 비용이 발생했을 수 있어요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('새 대화 시작'),
            ),
          ],
        );
      },
    );
    _reviewRoute = null;
    _reviewNavigator = null;
    if (!mounted || _invalidated || epoch != _epoch || reset != true) return;
    setState(() {
      _epoch++;
      _history.clear();
      _input.clear();
      _pending = null;
      _message = null;
      _busy = false;
    });
  }

  Future<void> _send() async {
    final gateway = ref.read(mealConversationGatewayProvider);
    final source = _context, owner = _identity.account;
    if (_busy || _invalidated || !gateway.enabled || source == null) return;
    if (owner == null) {
      setState(() => _message = '로그인한 뒤 이용해 주세요.');
      return;
    }
    final question = _input.text.trim(), epoch = _epoch;
    late final MealConversationDraft draft;
    try {
      draft = MealConversationDraft(
        context: source,
        history: _history,
        question: question,
      );
    } on MealAssistantFailure {
      setState(
        () => _message =
            '질문은 600자 이내로 적어 주세요. 연락처·링크·개인정보는 빼고, 내용이 너무 길면 새 대화를 시작해 주세요.',
      );
      return;
    }
    bool current() =>
        mounted &&
        !_invalidated &&
        epoch == _epoch &&
        _identity.account == owner &&
        _context?.revision == source.revision &&
        (ModalRoute.of(context)?.isCurrent == true ||
            _reviewRoute?.isCurrent == true);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final agreed = await showDialog<bool>(
        context: context,
        builder: (context) {
          _reviewRoute = ModalRoute.of(context);
          _reviewNavigator = Navigator.of(context);
          return AlertDialog(
            title: const Text('질문을 보낼까요?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '요리 답변을 위해 이번 질문과 최근 대화 최대 3쌍, 음식·재료·조리 정보를 앱 서버를 거쳐 OpenAI로 보내요.',
                  ),
                  const SizedBox(height: 12),
                  Text(question),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('함께 보내는 정보 보기'),
                    children: [
                      for (final item
                          in (draft.data['context'] as Map)['candidates']
                              as List)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item['name'] as String),
                          subtitle: Text(
                            [
                              '재료: ${(item['ingredients'] as List).join(', ')}',
                              if ((item['steps'] as List).isNotEmpty)
                                '조리법: ${(item['steps'] as List).join(' / ')}',
                            ].join('\n'),
                          ),
                        ),
                      Text(
                        '보유 재료: ${((draft.data['context'] as Map)['pantry'] as List).join(', ')}',
                      ),
                      for (final message
                          in (draft.data['messages'] as List).take(
                            (draft.data['messages'] as List).length - 1,
                          ))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(message['role'] == 'user' ? '나' : 'AI'),
                          subtitle: Text(message['text'] as String),
                        ),
                      const Text('개인정보·건강 정보는 입력하지 마세요. 취소하면 보내지 않아요.'),
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
                child: const Text('동의하고 보내기'),
              ),
            ],
          );
        },
      );
      _reviewRoute = null;
      _reviewNavigator = null;
      if (agreed != true || !current()) return;
      final consent = MealConversationConsent(
        owner: owner,
        session: '$epoch',
        draft: draft,
        grantedAt: DateTime.now(),
        requestId: newMealAssistantRequestId(),
      );
      setState(() {
        _pending = question;
        _input.clear();
      });
      _toEnd();
      final answer = await gateway.ask(consent, isCurrent: current);
      if (!current()) return;
      setState(() {
        _history.addAll([
          MealConversationMessage(MealConversationRole.user, question),
          MealConversationMessage(
            MealConversationRole.assistant,
            answer.contextText,
          ),
        ]);
        // Bound local memory independently of the smaller transmitted window.
        if (_history.length > 40) _history.removeRange(0, _history.length - 40);
        _pending = null;
      });
      _toEnd();
    } catch (error) {
      if (current()) {
        setState(() {
          _input.text = question;
          _message = error is MealAssistantFailure
              ? error.message
              : '답변을 받지 못했어요. 비용이 발생했을 수 있어 자동으로 다시 보내지 않아요.';
        });
      }
    } finally {
      if (mounted && epoch == _epoch && !_invalidated) {
        setState(() {
          _busy = false;
          _pending = null;
          // A changed inventory snapshot invalidates the reply, not the user's text.
          if (_context?.revision != source.revision && _input.text.isEmpty) {
            _input.text = question;
            _message = '재료 정보가 바뀌어 이전 답변을 표시하지 않았어요. 보낼 내용을 다시 확인해 주세요.';
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gateway = ref.watch(mealConversationGatewayProvider);
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
    _context = null;
    if (!_invalidated &&
        !inventory.isLoading &&
        !inventory.hasError &&
        recipes.isNotEmpty) {
      try {
        _context = MealAssistantDraft(
          task: widget.menuMode
              ? MealAssistantTask.menus
              : MealAssistantTask.steps,
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
        );
      } on MealAssistantFailure {
        /* Fail closed on oversized/unreviewable context. */
      }
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: pageToolbarHeight(context),
        title: const Text('AI에게 물어보기'),
        actions: [
          IconButton(
            tooltip: '새 대화',
            onPressed: _invalidated ? null : _newConversation,
            icon: const Icon(Icons.edit_square),
          ),
        ],
      ),
      body: SafeArea(
        child: _invalidated
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '계정이 바뀌어 이 화면의 입력과 대화를 지웠어요. 이전 화면에서 다시 열어 주세요.',
                    ),
                    TextButton(
                      onPressed: () => Navigator.maybePop(context),
                      child: const Text('돌아가기'),
                    ),
                  ],
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final scrollingComposer =
                      constraints.maxHeight < 600 ||
                      constraints.maxWidth < 350 ||
                      MediaQuery.textScalerOf(context).scale(14) > 19;
                  final content = <Widget>[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: coralSurface,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppSectionHeading(
                            gateway.enabled
                                ? '요리에 대해 이어서 물어보세요'
                                : '대화형 AI 연결 준비 중 · 입력은 전송되지 않아요',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.menuMode
                                ? '현재 메뉴 후보를 바탕으로 대화해요.'
                                : recipes.isEmpty
                                ? '레시피에 대해 함께 살펴봐요.'
                                : '${recipes.first.name}에 대해 함께 살펴봐요.',
                            style: const TextStyle(height: 1.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            gateway.enabled
                                ? '현재 승인된 계정만 이용할 수 있어요. 보낼 대화와 재료 정보는 매번 확인해요.'
                                : '채팅 화면을 준비했어요. 자유 질문과 이전 대화를 보내는 기능은 아직 연결하지 않았어요.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: darkGray,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MealAssistantToolsPage(
                                    recipes: widget.recipes,
                                    menuMode: widget.menuMode,
                                  ),
                                ),
                              ),
                        icon: const Icon(Icons.tune, size: 18),
                        label: Text(
                          widget.menuMode ? '기존 메뉴 제안 열기' : '조리 단계·재료 대체 도구',
                        ),
                      ),
                    ),
                    if (_history.isEmpty && _pending == null) ...[
                      const SizedBox(height: 24),
                      const AppSectionHeading('어떤 점이 궁금하세요?'),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final question
                              in widget.menuMode
                                  ? [
                                      '지금 있는 재료로 뭘 만들까요?',
                                      '추가 재료가 가장 적은 메뉴는요?',
                                      '그중 하나를 고르면 어떻게 만들어요?',
                                    ]
                                  : [
                                      '이 요리의 순서를 쉽게 설명해 주세요',
                                      '양파 대신 대파를 써도 될까요?',
                                      '더 간단하게 만드는 방법이 있나요?',
                                    ])
                            ActionChip(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: warmBorder),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              label: Text(question),
                              onPressed: _busy
                                  ? null
                                  : () {
                                      setState(() {
                                        _input.text = question;
                                        _message = null;
                                      });
                                    },
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                    for (final message in _history) _bubble(message),
                    if (_pending != null) ...[
                      _bubble(
                        MealConversationMessage(
                          MealConversationRole.user,
                          _pending!,
                        ),
                      ),
                      Semantics(
                        liveRegion: true,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('AI가 답변을 준비하고 있어요…'),
                        ),
                      ),
                    ],
                    if (inventory.isLoading) const Text('재료를 불러오는 중이에요.'),
                    if (inventory.hasError)
                      TextButton(
                        onPressed: () => ref.invalidate(ingredientsProvider),
                        child: const Text('재료 다시 불러오기'),
                      ),
                    if (!inventory.isLoading &&
                        !inventory.hasError &&
                        _context == null)
                      const Text('질문에 사용할 메뉴·재료 정보를 먼저 확인해 주세요.'),
                    if (_message != null)
                      Semantics(
                        liveRegion: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(_message!),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ];
                  final composer = KeyedSubtree(
                    key: _composerKey,
                    child: _composer(gateway),
                  );
                  if (scrollingComposer) {
                    return SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [...content, composer],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: ListView(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          children: content,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: composer,
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _composer(MealConversationGateway gateway) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: warmBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('meal-conversation-input'),
          controller: _input,
          focusNode: _focus,
          enabled: !_busy,
          minLines: 1,
          maxLines: 4,
          maxLength: mealConversationQuestionLimit,
          decoration: const InputDecoration(
            labelText: '요리에 대해 물어보세요',
            hintText: '예: 그럼 양파 대신 대파는 어때요?',
          ),
          onChanged: (_) => setState(() => _message = null),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('meal-conversation-send'),
          onPressed:
              gateway.enabled &&
                  !_busy &&
                  _context != null &&
                  _input.text.trim().isNotEmpty
              ? _send
              : null,
          icon: const Icon(Icons.arrow_upward),
          label: Text(
            _busy
                ? (_pending == null ? '전송 내용 확인 중' : '답변 기다리는 중')
                : gateway.enabled
                ? '보낼 대화 확인'
                : '대화형 AI 연결 후 전송 가능',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '대화는 이 화면에만 남아요. 전송할 때 최근 3번의 대화를 포함해 확인해요. 개인정보·건강 정보는 입력하지 마세요.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        Text(
          mealAssistantSafetyNotice,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );

  Widget _bubble(MealConversationMessage message) {
    final isUser = message.role == MealConversationRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUser ? coralSurface : Colors.white,
          border: isUser ? null : Border.all(color: warmBorder),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isUser ? '나' : 'AI 생성 답변 · 확인 필요',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: primaryGreen,
              ),
            ),
            const SizedBox(height: 6),
            SelectableText(message.text),
          ],
        ),
      ),
    );
  }
}
