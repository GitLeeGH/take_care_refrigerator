import 'meal_assistant_page.dart';
import '../services/meal_assistant.dart';
import '../services/meal_history.dart';
import '../services/curation_foundation.dart';
import '../widgets/meal_history_card.dart';
import 'dart:async';
import '../services/curation_preferences.dart';
import '../widgets/app_presentation.dart';
import '../services/inventory_day.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models.dart';
import '../providers.dart';
import '../services/local_recipe_curation.dart';
import '../theme.dart';
import 'recipes_page.dart';

class LocalCurationPage extends ConsumerStatefulWidget {
  const LocalCurationPage({super.key});
  @override
  ConsumerState<LocalCurationPage> createState() => _LocalCurationPageState();
}

class _LocalCurationPageState extends ConsumerState<LocalCurationPage> {
  final preferred = TextEditingController();
  final avoided = TextEditingController();
  bool prioritizeExpiring = true;
  bool avoidWeeklyMeals = true, showRepeatedMeals = false;
  late final MealHistoryStore _meals;
  void _mealChanged() {
    if (mounted) setState(() {});
  }

  bool _busy = true;
  String? _storageMessage;
  bool _loadFailed = false;

  late final CurationIdentity _identity;
  late final StreamSubscription<void> _identitySubscription;
  String? _account;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    _identity = ref.read(curationIdentityProvider);
    _meals = ref.read(mealHistoryProvider);
    _meals.addListener(_mealChanged);
    // Store observes auth before this screen starts its new-account load.
    ref.read(curationPreferenceStoreProvider);
    _identitySubscription = _identity.changes.listen(
      (_) => _accountChanged(force: true),
    );
    _accountChanged(force: true);
  }

  void _accountChanged({bool force = false}) {
    if (!mounted || (!force && _account == _identity.account)) return;
    _epoch++;
    setState(() {
      _account = _identity.account;
      avoidWeeklyMeals = true;
      showRepeatedMeals = false;
      preferred.clear();
      avoided.clear();
      prioritizeExpiring = true;
      _storageMessage = null;
      _loadFailed = false;
      _busy = _account != null;
    });
    if (_account != null) _loadPreferences();
  }

  bool _current(int epoch, String? account) =>
      mounted &&
      epoch == _epoch &&
      account == _account &&
      account == _identity.account;

  Future<void> _loadPreferences() async {
    final account = _account;
    final epoch = _epoch;
    if (account == null || account != _identity.account) return;
    setState(() => _busy = true);
    try {
      final value = await ref
          .read(curationPreferenceStoreProvider)
          .load(account: account);
      if (!_current(epoch, account)) return;
      setState(() {
        preferred.text = value.preferred;
        avoided.text = value.avoided;
        prioritizeExpiring = value.prioritizeExpiring;
        _storageMessage = null;
        _loadFailed = false;
      });
    } catch (_) {
      if (!_current(epoch, account)) return;
      setState(() {
        _loadFailed = true;
        _storageMessage = '기기 설정을 불러오지 못했어요. 현재 입력은 이 화면에서만 적용돼요.';
      });
    } finally {
      if (_current(epoch, account)) setState(() => _busy = false);
    }
  }

  void _edited() => setState(() {
    _storageMessage = '변경 사항은 아직 저장하지 않았어요.';
  });

  Future<void> _persistPreferences({
    bool delete = false,
    bool legacy = false,
  }) async {
    if (_account != _identity.account) {
      _accountChanged();
      return;
    }
    final account = _account;
    final epoch = _epoch;
    if (_busy || account == null) return;
    final store = ref.read(curationPreferenceStoreProvider);
    final value = CurationPreferences(
      preferred: preferred.text,
      avoided: avoided.text,
      prioritizeExpiring: prioritizeExpiring,
    );
    setState(() {
      _busy = true;
      if (delete) {
        preferred.clear();
        avoided.clear();
        prioritizeExpiring = true;
      }
    });
    try {
      if (legacy) {
        await store.deleteLegacy(account: account);
      } else if (delete) {
        await store.delete(account: account);
      } else {
        await store.save(value, account: account);
      }
      if (!_current(epoch, account)) return;
      setState(() {
        _loadFailed = false;
        _storageMessage = legacy
            ? '이전 공용 설정을 삭제했어요.'
            : delete
            ? '이 기기에 저장한 현재 계정 설정을 삭제했어요.'
            : '현재 계정 설정을 이 기기에 저장했어요.';
      });
    } catch (_) {
      if (!_current(epoch, account)) return;
      setState(
        () => _storageMessage = legacy
            ? '이전 공용 설정을 삭제하지 못했어요. 다시 시도해 주세요.'
            : delete
            ? '화면은 초기화했지만 기기 설정을 삭제하지 못했어요. 다시 지워 주세요.'
            : '기기에 저장하지 못했어요. 입력은 이 화면에서만 적용돼요.',
      );
    } finally {
      if (_current(epoch, account)) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _epoch++;
    _identitySubscription.cancel();
    _meals.removeListener(_mealChanged);
    preferred.dispose();
    avoided.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(inventoryDayProvider);
    final recipes = ref.watch(allRecipesListProvider);
    final inventory = ref.watch(ingredientsProvider);
    final ready =
        _account != null &&
        _account == _identity.account &&
        !recipes.isLoading &&
        !inventory.isLoading &&
        !recipes.hasError &&
        !inventory.hasError;
    final matches = ready
        ? curateLocalRecipes(
            recipes: recipes.asData?.value ?? <Recipe>[],
            inventory: inventory.asData?.value ?? <Ingredient>[],
            now: today,
            preferred: localPreferenceNames(preferred.text),
            avoided: localPreferenceNames(avoided.text),
            prioritizeExpiring: prioritizeExpiring,
          )
        : <LocalRecipeMatch>[];
    final mealToday = MealDay(today.year, today.month, today.day);
    final historyReady =
        _meals.snapshot != null &&
        !_meals.failed &&
        // Retain confirmed same-account history during a refresh or save.
        _meals.owner == _account;
    final variety = MealVariety(
      matches,
      (match) =>
          avoidWeeklyMeals &&
          historyReady &&
          eatenThisWeek(
            owner: _account ?? '',
            name: match.recipe.name,
            today: mealToday,
            records: _meals.snapshot!.records,
          ),
    );
    final visibleMatches = showRepeatedMeals
        ? [...variety.suggestions, ...variety.eatenAgain]
        : variety.suggestions;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: pageToolbarHeight(context),
        title: const Text('내 재료로 추천'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(pageGutter),
          children: [
            const Text(
              '한 끼를 골라요',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              '규칙 기반 추천 · 외부 AI 사용 안 함',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              '불러온 실제 레시피를 기기 안에서 정렬해요. 저장을 누르면 선호 설정을 이 기기에만 보관해요. 서버로 보내지 않으며, 로그인한 계정별로 따로 보관해요.',
            ),
            if (_account == null) const Text('로그인하면 계정별 추천 설정을 사용할 수 있어요.'),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text(
                mealAssistantRolloutEnabled ? 'AI 메뉴 큐레이션' : 'AI 메뉴 제안 · 연결 준비',
              ),
              onPressed: visibleMatches.isEmpty || _busy
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MealAssistantPage(
                          recipes: visibleMatches
                              .map((match) => match.recipe)
                              .take(10)
                              .toList(),
                          menuMode: true,
                        ),
                      ),
                    ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      key: const ValueKey('curation-preferred'),
                      controller: preferred,
                      maxLength: 120,
                      enabled: !_busy && _account != null,
                      onChanged: (_) => _edited(),
                      decoration: const InputDecoration(
                        labelText: '선호 재료 (선택)',
                        hintText: '예: 두부, 양파',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: avoided,
                      maxLength: 120,
                      enabled: !_busy && _account != null,
                      onChanged: (_) => _edited(),
                      decoration: const InputDecoration(
                        labelText: '피할 재료 (선택)',
                        hintText: '쉼표로 구분해 주세요',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('3일 이내 재료 우선'),
                      value: prioritizeExpiring,
                      onChanged: (_busy || _account == null)
                          ? null
                          : (value) {
                              prioritizeExpiring = value;
                              _edited();
                            },
                    ),
                    if (_busy) const LinearProgressIndicator(),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: (_busy || _account == null)
                              ? null
                              : () => _persistPreferences(),
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('이 기기에 저장'),
                        ),
                        TextButton(
                          onPressed: (_busy || _account == null)
                              ? null
                              : () => _persistPreferences(delete: true),
                          child: const Text('선호 설정 지우기'),
                        ),
                        if (_loadFailed)
                          TextButton(
                            onPressed: (_busy || _account == null)
                                ? null
                                : _loadPreferences,
                            child: const Text('저장 설정 다시 불러오기'),
                          ),
                      ],
                    ),
                    if (_storageMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(_storageMessage!),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '기피 이름이 괄호 설명이나 선택 목록에 명시된 요리도 제외해요. 알레르기 판별 기능이 아니며, 제품 성분·분량·재료 상태는 직접 확인해 주세요.',
              style: TextStyle(color: mediumGray),
            ),
            const SizedBox(height: 8),
            const Text('이전 버전의 공용 설정은 어느 계정에도 가져오지 않아요. 아래에서 별도로 삭제할 수 있어요.'),
            TextButton(
              onPressed: (_busy || _account == null)
                  ? null
                  : () => _persistPreferences(legacy: true),
              child: const Text('이전 공용 설정 삭제'),
            ),
            const SizedBox(height: 20),
            MealHistoryCard(store: _meals, today: mealToday),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('이번 주 먹은 메뉴 피하기'),
              subtitle: const Text('기록한 음식 이름이 같은 경우에만 구분해요. 설정은 이 화면에서 적용돼요.'),
              value: avoidWeeklyMeals,
              onChanged: (value) => setState(() {
                avoidWeeklyMeals = value;
                showRepeatedMeals = false;
              }),
            ),
            if (!historyReady && _account != null)
              const Text('식사 기록 확인 전에는 중복 회피가 적용되지 않아요.'),
            if (variety.eatenAgain.isNotEmpty)
              TextButton(
                onPressed: () =>
                    setState(() => showRepeatedMeals = !showRepeatedMeals),
                child: Text(
                  showRepeatedMeals
                      ? '이번 주 먹은 메뉴 숨기기'
                      : '이번 주 먹은 메뉴도 보기 (${variety.eatenAgain.length})',
                ),
              ),
            if (matches.isNotEmpty && visibleMatches.isEmpty)
              const Text('추천 조건에 맞는 메뉴를 모두 이번 주에 기록했어요. 위에서 먹은 메뉴도 볼 수 있어요.'),
            if (recipes.isLoading || inventory.isLoading)
              const LinearProgressIndicator()
            else if (recipes.hasError || inventory.hasError)
              TextButton.icon(
                onPressed: () {
                  ref.invalidate(allRecipesListProvider);
                  ref.invalidate(ingredientsProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('데이터를 불러오지 못했어요 · 다시 시도'),
              )
            else if (matches.isEmpty)
              const AppEmptyState(
                icon: Icons.tune,
                title: '조건에 맞는 저장 레시피가 없어요.',
                message: '재료나 기피 설정을 확인해 주세요.',
              )
            else ...[
              Text(
                '${visibleMatches.length}개 추천 · ${prioritizeExpiring ? '보유 비율 → 미확인 수 → 임박 → 선호 순' : '보유 비율 → 미확인 수 → 선호 순'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              for (final match in visibleMatches) ...[
                if (variety.eatenAgain.contains(match))
                  const Text('이번 주 먹은 메뉴'),
                if (prioritizeExpiring && match.expiring.isNotEmpty)
                  Text(
                    '먼저 확인할 재료: ${match.expiring.join(', ')}',
                    style: const TextStyle(color: warningInk),
                  ),
                if (match.preferred.isNotEmpty)
                  Text(
                    '선호 재료 포함: ${match.preferred.join(', ')}',
                    style: const TextStyle(color: primaryGreen),
                  ),
                const SizedBox(height: 6),
                RecipeCard(recipe: match.recipe),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
