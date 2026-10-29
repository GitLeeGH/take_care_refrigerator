import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models.dart';
import '../providers.dart';
import '../ingredient_matching.dart';
import '../services/cooking_steps.dart';
import '../services/video_segments.dart';
import '../widgets/original_video_panel.dart';
import '../widgets/recipe_cover.dart';
import 'add_recipe_page.dart';

const cookingOrange = Color(0xFFCA4B00);

class RecipeDetailPage extends ConsumerStatefulWidget {
  const RecipeDetailPage({super.key, required this.recipe});
  final Recipe recipe;
  @override
  ConsumerState<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends ConsumerState<RecipeDetailPage> {
  int tab = 0;
  Future<void> openSource() async {
    final uri = Uri.tryParse(widget.recipe.blogUrl ?? '');
    var opened = false;
    if (uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    if (!opened && mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출처를 열지 못했습니다. 잠시 후 다시 시도해 주세요.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final inventory = ref.watch(ingredientsProvider);
    final profile = ref.watch(userProfileProvider).asData?.value;
    final likes = ref.watch(likedRecipeIdsProvider);
    final steps = savedCookingSteps(
      recipe.displayDescription,
      unverified: recipe.hasUnverifiedSteps,
    );
    final availability = IngredientAvailability(
      recipe.requiredIngredients,
      (inventory.asData?.value ?? <Ingredient>[]).map((e) => e.name),
    );
    final summary = availability.requiredIngredients.isEmpty
        ? '등록된 재료 정보가 없습니다.'
        : availability.canMake
        ? '모든 재료 보유 · 수량은 직접 확인해 주세요.'
        : '부족한 재료: ${availability.missingIngredients.join(', ')}';
    final lightTheme = Theme.of(context).copyWith(
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: cookingOrange,
        brightness: Brightness.light,
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
    );
    return Theme(
      data: lightTheme,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          surfaceTintColor: Colors.transparent,
          title: Text(
            recipe.name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          actions: [
            if (likes.asData != null)
              IconButton(
                tooltip: '좋아요',
                icon: Icon(
                  likes.asData!.value.contains(recipe.id)
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
                onPressed: () async {
                  try {
                    await ref.read(likeRecipeProvider)(
                      recipe.id,
                      likes.asData!.value.contains(recipe.id),
                    );
                  } catch (_) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('좋아요를 저장하지 못했습니다.')),
                      );
                  }
                },
              ),
            if (profile?.role == 'admin')
              IconButton(
                tooltip: '레시피 수정',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddRecipePage(recipe: recipe),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cookingOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CookingPage(recipe: recipe)),
              ),
              child: Text(
                steps.isEmpty ? '조리 단계 확인' : '요리 시작',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (recipe.originalVideo case final video?)
                OriginalVideoPanel(
                  video: video,
                  hero: true,
                  posterImageUrl: recipe.imageUrl,
                )
              else if (recipe.imageUrl?.trim().isNotEmpty == true)
                SizedBox(
                  height: 230,
                  child: RecipeCover(
                    imageUrl: recipe.imageUrl,
                    label: '${recipe.name} 이미지',
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('등록된 원본 영상이 없습니다.', textAlign: TextAlign.center),
                ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: Semantics(
                        selected: tab == i,
                        child: InkWell(
                          onTap: () => setState(() => tab = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: tab == i
                                      ? Colors.black87
                                      : const Color(0xFFEEEEEE),
                                  width: tab == i ? 2 : 1,
                                ),
                              ),
                            ),
                            child: Text(
                              ['요약', '레시피', '재료'][i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: tab == i
                                    ? Colors.black87
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (tab == 0) ...[
                      _InfoBox(
                        tinted: true,
                        child: Text(
                          recipe.hasUnverifiedSteps
                              ? '제작자 댓글에서 확인한 재료·분량입니다. 조리 순서와 영상 구간은 아직 확인되지 않았습니다.'
                              : '저장된 레시피를 바탕으로 표시합니다. 조리 전 분량과 과정을 확인해 주세요.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _InfoBox(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipe.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                if (recipe.totalTime?.isNotEmpty == true)
                                  Text('◷ ${recipe.totalTime}'),
                                if (recipe.cuisineType?.isNotEmpty == true)
                                  Text(recipe.cuisineType!),
                                Text(
                                  '재료 ${availability.requiredIngredients.length}가지',
                                ),
                                Text(
                                  steps.isEmpty
                                      ? '조리 단계 미등록'
                                      : '저장된 순서 ${steps.length}단계',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _InfoBox(
                        child: inventory.isLoading
                            ? const Text('재료 확인 중')
                            : inventory.hasError
                            ? const Text('재료 정보를 불러올 수 없습니다.')
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(summary),
                                  if (availability
                                      .missingIngredients
                                      .isNotEmpty)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Icon(
                                        Icons.remove_circle_outline,
                                        color: cookingOrange,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ],
                    if (tab == 1) ...[
                      Text(
                        recipe.hasUnverifiedSteps ? '재료·출처 확인 정보' : '저장된 레시피',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (steps.isEmpty)
                        const _InfoBox(
                          tinted: true,
                          child: Text(
                            '진행할 조리 단계가 등록되어 있지 않습니다. 아래 원문을 확인해 주세요. 영상 시점은 자동으로 추정하지 않습니다.',
                          ),
                        ),
                      const SizedBox(height: 14),
                      if (recipe.displayDescription.isEmpty)
                        const Text('등록된 레시피 설명이 없습니다.')
                      else
                        MarkdownBody(data: recipe.displayDescription),
                    ],
                    if (tab == 2) ...[
                      if (inventory.isLoading)
                        const LinearProgressIndicator()
                      else if (inventory.hasError)
                        const Text('재료 정보를 불러올 수 없습니다.')
                      else
                        Text(summary),
                      const SizedBox(height: 12),
                      for (final name in availability.requiredIngredients)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _InfoBox(
                            child: Row(
                              children: [
                                Icon(
                                  inventory.isLoading || inventory.hasError
                                      ? Icons.help_outline
                                      : availability.owns(name)
                                      ? Icons.check_circle_outline
                                      : Icons.remove_circle_outline,
                                  color: cookingOrange,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const Text('분량은 레시피 탭의 저장된 원문을 확인해 주세요.'),
                    ],
                    if (recipe.blogUrl?.isNotEmpty == true)
                      TextButton.icon(
                        onPressed: openSource,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('원본 출처 보기'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.child, this.tinted = false});
  final Widget child;
  final bool tinted;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: tinted ? const Color(0xFFFFF7EB) : Colors.white,
      border: Border.all(
        color: tinted ? const Color(0xFFF0D8B8) : const Color(0xFFE8E8E8),
      ),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
}

class CookingPage extends StatefulWidget {
  const CookingPage({super.key, required this.recipe});
  final Recipe recipe;
  @override
  State<CookingPage> createState() => _CookingPageState();
}

class _CookingPageState extends State<CookingPage> {
  int current = 0;
  bool completed = false;
  bool followVideo = true;
  bool repeatVideo = false;
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void move(int next) {
    setState(() {
      current = next;
      completed = false;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final steps = savedCookingSteps(
      recipe.displayDescription,
      unverified: recipe.hasUnverifiedSteps,
    );
    final segments = verifiedVideoSegments(
      recipe.videoSegments,
      recipe.youtubeVideoId,
      steps,
    );
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(primary: Color(0xFFFF8B3D)),
        cardTheme: const CardThemeData(color: Color(0xFF151515), elevation: 0),
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(recipe.name, style: const TextStyle(fontSize: 17)),
        ),
        bottomNavigationBar: steps.isEmpty
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: current > 0 || completed
                              ? () => move(completed ? current : current - 1)
                              : null,
                          child: const Text('이전'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: cookingOrange,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: completed
                              ? () => Navigator.pop(context)
                              : () {
                                  if (current + 1 < steps.length) {
                                    move(current + 1);
                                  } else {
                                    setState(() => completed = true);
                                  }
                                },
                          child: Text(
                            completed
                                ? '레시피로'
                                : current + 1 == steps.length
                                ? '완료'
                                : '다음',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        body: SingleChildScrollView(
          controller: scroll,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (recipe.originalVideo case final video?)
                  OriginalVideoPanel(
                    video: video,
                    hero: true,
                    posterImageUrl: recipe.imageUrl,
                    playOnEntry: true,
                    segment: !completed && followVideo && segments != null
                        ? segments[current]
                        : null,
                    repeatSegment: repeatVideo && followVideo && !completed,
                    playbackEnabled: !completed,
                  ),
                const SizedBox(height: 16),
                if (segments == null)
                  const Text(
                    '영상 구간 정보가 없어 단계 이동과 영상 시점은 연동되지 않습니다.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  )
                else if (!completed) ...[
                  Text(
                    '단계 영상 · 약 ${segments[current].label}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const Text(
                    '장면을 보고 정한 초 단위의 대략적인 구간입니다. 단계 경계와 재생 위치가 조금 다를 수 있으며, 전체 조리 과정을 담지 않을 수 있어요.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('단계에 맞춰 영상 이동'),
                    value: followVideo,
                    onChanged: (value) => setState(() {
                      followVideo = value;
                      if (!value) repeatVideo = false;
                    }),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('이 구간 반복'),
                    subtitle: const Text('플레이어에서 재생을 눌러 시작하세요.'),
                    value: repeatVideo,
                    onChanged: followVideo
                        ? (value) => setState(() => repeatVideo = value)
                        : null,
                  ),
                ],
                const SizedBox(height: 20),
                if (steps.isEmpty) ...[
                  const Icon(
                    Icons.menu_book_outlined,
                    color: Color(0xFFFF8B3D),
                    size: 40,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '아직 조리 단계가 없습니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '검증된 조리 순서가 저장되면 터치로 한 단계씩 진행할 수 있어요. 현재는 원본 영상과 저장된 레시피 정보를 확인해 주세요.',
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Semantics(
                    label: '${current + 1} / ${steps.length} 단계',
                    child: LinearProgressIndicator(
                      value: completed ? 1 : (current + 1) / steps.length,
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    completed ? '요리 완료' : '${current + 1} / ${steps.length} 단계',
                    style: const TextStyle(
                      color: Color(0xFFFF8B3D),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B1B),
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        completed
                            ? '수고하셨어요. 완성된 요리를 즐겨보세요.'
                            : '${current + 1}. ${steps[current]}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  if (!completed)
                    for (var i = current + 1; i < steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Text(
                          '${i + 1}. ${steps[i]}',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white60,
                            height: 1.5,
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
