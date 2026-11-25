import '../pages/ingredient_photo_credits_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/food_catalog.dart';
import 'ingredient_thumbnail.dart';

class FoodCatalogButton extends StatelessWidget {
  const FoodCatalogButton({super.key, this.name = '', this.onSelected});
  final String name;
  final ValueChanged<String>? onSelected;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: const Icon(Icons.menu_book_outlined),
    label: const Text('재료 사전 · 보관 참고'),
    onPressed: () async {
      final selected = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => FoodCatalogPage(
            initialQuery: name,
            allowSelection: onSelected != null,
          ),
        ),
      );
      if (context.mounted && selected != null) onSelected?.call(selected);
    },
  );
}

class FoodCatalogPage extends ConsumerStatefulWidget {
  const FoodCatalogPage({
    super.key,
    this.initialQuery = '',
    this.allowSelection = false,
  });
  final String initialQuery;
  final bool allowSelection;
  @override
  ConsumerState<FoodCatalogPage> createState() => _FoodCatalogState();
}

class _FoodCatalogState extends ConsumerState<FoodCatalogPage> {
  late final TextEditingController search = TextEditingController(
    text: widget.initialQuery,
  );
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(foodCatalogProvider);
    final foods = state.asData?.value ?? bundledFoods;
    final query = foodCatalogSearchKey(search.text);
    final matches = foods
        .where(
          (e) => [
            e.name,
            e.category,
            ...e.aliases,
          ].any((s) => foodKey(s).contains(query)),
        )
        .toList();
    if (query.isNotEmpty) {
      bool exact(FoodEntry entry) =>
          [entry.name, ...entry.aliases].any((name) => foodKey(name) == query);
      matches.sort((a, b) {
        final priority = (exact(b) ? 1 : 0) - (exact(a) ? 1 : 0);
        return priority != 0 ? priority : a.name.compareTo(b.name);
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('재료 사전'),
        actions: [
          IconButton(
            tooltip: '재료 사진 출처',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const IngredientPhotoCreditsPage(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: '재료·양념·분류 검색',
                        suffixIcon: IconButton(
                          tooltip: '검색어 지우기',
                          onPressed: () {
                            search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '${matches.length}종 · 기간 미상은 임의로 계산하지 않습니다. 참고 사진은 실제 보관 중인 재료와 다를 수 있습니다.',
                    ),
                  ),
                  if (!state.hasValue)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        state.isLoading
                            ? '저장된 재료 사전을 표시하며 최신 자료를 확인 중입니다.'
                            : '연결을 확인하지 못해 앱에 포함된 2026-11-04 자료를 표시합니다.',
                      ),
                    ),
                  if (state.hasError)
                    TextButton(
                      onPressed: () => ref.invalidate(foodCatalogProvider),
                      child: const Text('다시 확인'),
                    ),
                ],
              ),
            ),
            matches.isEmpty
                ? const SliverToBoxAdapter(
                    child: Center(
                      child: Text(
                        '일치하는 이름이 없습니다.\n직접 입력한 이름으로 등록할 수 있습니다.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : SliverList.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final entry = matches[index];
                      return ListTile(
                        leading: IngredientThumbnail(name: entry.name),
                        title: Text(entry.name),
                        subtitle: Text(
                          '${entry.category} · ${entry.guidance.isEmpty ? '참고 기간 미상' : '보관 조건 확인'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          FocusScope.of(context).unfocus();
                          final chosen = await showModalBottomSheet<bool>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            builder: (context) => _FoodDetails(
                              entry: entry,
                              allowSelection: widget.allowSelection,
                            ),
                          );
                          if (chosen == true && context.mounted) {
                            Navigator.pop(context, entry.name);
                          }
                        },
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

class _FoodDetails extends StatelessWidget {
  const _FoodDetails({required this.entry, required this.allowSelection});
  final FoodEntry entry;
  final bool allowSelection;
  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: 0.88,
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(entry.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            const Text(
              '보관 참고 정보는 소비기한이나 안전 보증이 아닙니다. 포장지 날짜와 보관 지시가 우선입니다. 재료의 날짜는 바뀌지 않습니다.',
            ),
            if (entry.aliases.isNotEmpty)
              Text('다른 이름: ${entry.aliases.join(', ')}'),
            if (entry.guidance.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  '참고 기간 미상\n개봉 전후·보관 방식별로 확인된 근거가 아직 없습니다. 제품 표시를 확인하세요.',
                ),
              ),
            for (final g in entry.guidance)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${const {'ambient': '실온', 'refrigerated': '냉장', 'frozen': '냉동'}[g['storage']] ?? '보관 조건 확인'} · ${const {'opened': '개봉 후', 'unopened': '미개봉', 'fresh': '신선 원물'}[g['phase']] ?? '상태 확인'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '참고 기간: ${g['period'] ?? '미상 — 숫자로 확정하지 않음'}',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(g['conditions'] as String),
                      Text(g['scope'] as String),
                      const SizedBox(height: 8),
                      Text('출처: ${g['publisher']} · 확인 ${g['checked_on']}'),
                      SelectableText(g['source_url'] as String),
                    ],
                  ),
                ),
              ),
            if (allowSelection)
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('이 이름 사용'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    ),
  );
}
