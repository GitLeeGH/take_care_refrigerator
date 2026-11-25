import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/recipe_draft.dart';
import '../services/verified_recipe_sample.dart';
import '../services/original_video.dart';
import '../widgets/external_video_reference.dart';

class RecipeImportPage extends ConsumerStatefulWidget {
  const RecipeImportPage({super.key});
  @override
  ConsumerState<RecipeImportPage> createState() => _RecipeImportPageState();
}

class _RecipeImportPageState extends ConsumerState<RecipeImportPage> {
  final link = TextEditingController();
  final sourceText = TextEditingController();
  RecipeSourceKind kind = RecipeSourceKind.description;
  bool busy = false;
  String? message;
  RecipeDraft? draft;
  @override
  void dispose() {
    link.dispose();
    sourceText.dispose();
    super.dispose();
  }

  Future<void> preview() async {
    if (busy) return;
    final source = YoutubeSource.parse(link.text);
    if (OriginalVideo.parse(link.text)?.kind == OriginalVideoKind.instagram) {
      setState(
        () => message = '릴스는 원본 링크로 볼 수 있어요. 릴스의 레시피 자동 추출은 아직 연결되지 않았습니다.',
      );
      return;
    }
    if (source == null) {
      setState(() => message = '올바른 HTTPS YouTube 또는 Shorts 링크를 입력해 주세요.');
      return;
    }
    final text = sourceText.text.trim();
    if (text.isEmpty) {
      setState(
        () => message = '영상 설명이나 직접 제공할 자막을 붙여넣어 주세요. 링크만으로 내용을 추측하지 않습니다.',
      );
      return;
    }
    final extractor = ref.read(recipeDraftExtractorProvider);
    if (!extractor.available) {
      setState(() => message = '자동 추출은 아직 연결되지 않았어요. 입력 내용은 이 화면에서만 유지됩니다.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
      draft = null;
    });
    try {
      final result = await extractor.extract(source, text, kind);
      if (mounted) setState(() => draft = result);
    } catch (_) {
      if (mounted)
        setState(() => message = '초안을 만들지 못했어요. 입력 내용은 유지됩니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('영상 레시피 미리보기')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('설명·자막을 바탕으로 재료와 조리 순서를 검토하는 화면입니다. 공개 레시피로 저장하지 않습니다.'),
          const SizedBox(height: 16),
          TextField(
            key: const Key('recipe-source-url'),
            controller: link,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'YouTube / Shorts / 릴스 링크',
            ),
            onChanged: (_) => setState(() {
              draft = null;
              message = null;
            }),
          ),
          const SizedBox(height: 12),
          if (draft == null && OriginalVideo.parse(link.text) != null)
            ExternalVideoReference(
              key: ValueKey(OriginalVideo.parse(link.text)!.url),
              video: OriginalVideo.parse(link.text)!,
            ),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('영상 설명'),
                selected: kind == RecipeSourceKind.description,
                onSelected: busy
                    ? null
                    : (_) => setState(() {
                        kind = RecipeSourceKind.description;
                        draft = null;
                      }),
              ),
              ChoiceChip(
                label: const Text('직접 제공한 자막'),
                selected: kind == RecipeSourceKind.userTranscript,
                onSelected: busy
                    ? null
                    : (_) => setState(() {
                        kind = RecipeSourceKind.userTranscript;
                        draft = null;
                      }),
              ),
            ],
          ),
          TextField(
            key: const Key('recipe-source-text'),
            controller: sourceText,
            enabled: !busy,
            minLines: 5,
            maxLines: 12,
            maxLength: 20000,
            decoration: const InputDecoration(
              labelText: '원문 붙여넣기',
              alignLabelWithHint: true,
            ),
            onChanged: (_) => setState(() {
              draft = null;
              message = null;
            }),
          ),
          if (!ref.watch(recipeDraftExtractorProvider).available)
            const Text('자동 추출 서비스 연결 준비 중 · 영상 다운로드나 외부 전송을 하지 않습니다.'),
          if (verifiedRecipeSample(YoutubeSource.parse(link.text)) != null)
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      draft = verifiedRecipeSample(
                        YoutubeSource.parse(link.text),
                      );
                      message = null;
                    }),
              child: const Text('이 영상의 제작자 댓글 예시 보기'),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : preview,
            child: Text(busy ? '확인 중…' : '입력 확인'),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(message!),
            ),
          if (draft != null) RecipeDraftPreview(draft: draft!),
        ],
      ),
    ),
  );
}

class RecipeDraftPreview extends StatelessWidget {
  const RecipeDraftPreview({super.key, required this.draft});
  final RecipeDraft draft;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 16),
      Text(
        draft.title?.trim().isNotEmpty == true ? draft.title! : '제목 확인 필요',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const Text('확인 필요 · 원문과 비교해 주세요. 아직 저장되지 않았습니다.'),
      ExternalVideoReference(
        key: ValueKey(draft.source.url),
        video: OriginalVideo(OriginalVideoKind.youtube, draft.source.videoId),
      ),
      if (draft.sourceKind == RecipeSourceKind.creatorComment)
        const Text('제작자 댓글에서 확인한 예시 · 자동 추출 결과가 아닙니다.'),
      if (draft.creator != null) Text('제작자: ${draft.creator}'),
      SelectableText('출처: ${draft.source.url}'),
      Text(switch (draft.sourceKind) {
        RecipeSourceKind.description => '근거: 영상 설명',
        RecipeSourceKind.userTranscript => '근거: 사용자가 제공한 자막',
        RecipeSourceKind.creatorComment => '근거: 제작자 고정 댓글',
      }),
      if (draft.evidenceUrl != null)
        SelectableText('댓글 출처: ${draft.evidenceUrl}'),
      if (draft.measurementNote != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(draft.measurementNote!),
        ),
      const SizedBox(height: 12),
      const Text('재료'),
      if (draft.ingredients.isEmpty) const Text('재료 정보 없음 · 원문 확인 필요'),
      for (final item in draft.ingredients)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${item.name} · ${item.amount ?? '분량 확인 필요'}'),
          subtitle: Text('근거: ${item.evidence}'),
        ),
      const Text('조리 순서'),
      if (draft.steps.isEmpty) const Text('조리 순서 없음 · 원문 확인 필요'),
      for (var i = 0; i < draft.steps.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${i + 1}. ${draft.steps[i].instruction}'),
          subtitle: Text('근거: ${draft.steps[i].evidence}'),
        ),
    ],
  );
}
