import '../services/recipe_example_photos.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/recipe_photos.dart';

class RecipePhotoCreditsPage extends StatelessWidget {
  const RecipePhotoCreditsPage({super.key});

  Future<void> _open(BuildContext context, String url) async {
    try {
      if (await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('링크를 열지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('음식 사진 출처')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '식품의약품안전처 조리식품의 레시피 DB에서 제공한 완성 음식 사진입니다. '
          '원문 번호·정확한 제목·공식 출처가 일치할 때만 표시합니다. '
          '직접 만든 음식이나 내 냉장고를 촬영한 사진은 아닙니다.',
        ),
        const SizedBox(height: 12),
        const Text(
          '공공데이터포털 이용허락범위: 제한 없음. 원본 파일을 앱에 포함해 '
          '오프라인에서도 표시하며, 화면에 맞춰 크기와 가장자리만 조절합니다. '
          '식약처의 앱 인증이나 추천을 뜻하지 않습니다.',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => _open(context, RecipePhoto.sourceUrl),
              child: const Text('공식 데이터셋'),
            ),
            TextButton(
              onPressed: () => _open(context, RecipePhoto.licenseUrl),
              child: const Text('이용 조건'),
            ),
          ],
        ),

        const SizedBox(height: 20),
        const Text('예시 사진', style: TextStyle(fontWeight: FontWeight.w700)),
        const Text(
          '사진이 없는 메뉴에는 이름이 맞는 비슷한 요리의 참고 사진을 표시합니다. '
          '해당 레시피로 만든 실제 사진은 아니며 재료·모양이 다를 수 있어요. '
          '예시 사진은 Wikimedia Commons의 아래 라이선스로 사용하며 화면에 맞춰 축소·잘라 표시합니다. '
          'CC BY-SA 사진의 표시용 크기·잘라내기 변경분도 같은 CC BY-SA 라이선스로 제공합니다.',
        ),
        for (final example in recipeExamplePhotos)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  example.assetPath,
                  height: 160,
                  fit: BoxFit.contain,
                  semanticLabel: '${example.name} 예시 사진',
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
                Text('${example.name} · 예시 사진'),
                Text(example.originalTitle),
                Text('${example.author} · ${example.license}'),
                const Text(RecipeExamplePhoto.changes),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => _open(context, example.sourceUrl),
                      child: const Text('사진 원본·출처'),
                    ),
                    if (example.licenseUrl.isNotEmpty)
                      TextButton(
                        onPressed: () => _open(context, example.licenseUrl),
                        child: const Text('라이선스'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        const Text(
          '식약처 레시피 완성 사진',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        for (final photo in allRecipePhotos)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  photo.assetPath,
                  height: 180,
                  fit: BoxFit.contain,
                  semanticLabel: '${photo.name} 완성 음식',
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),
                Text(
                  photo.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${RecipePhoto.author} · COOKRCP01 · 원문 ${photo.sourceId}',
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
