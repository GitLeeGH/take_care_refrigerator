import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ingredient_photos.dart';
import '../widgets/ingredient_thumbnail.dart';

class IngredientPhotoCreditsPage extends StatelessWidget {
  const IngredientPhotoCreditsPage({super.key});

  Future<void> _open(BuildContext context, String value) async {
    try {
      if (await launchUrl(
        Uri.parse(value),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      // A failed external launch should not interrupt browsing the credits.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('링크를 열지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('재료 사진 출처')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '앱에 포함된 실제 식재료의 참고 사진입니다. 직접 저장한 사진이 있으면 먼저 표시합니다. '
          '사진이 없는 재료는 빈 사진 아이콘으로 표시하며, 사진으로 종류·상태·안전성을 판단하지 않습니다.',
        ),
        const SizedBox(height: 8),
        const Text(
          'Wikimedia Commons의 허용된 라이선스에 따라 사용합니다. '
          '원본의 축소본을 포함하며 화면에 맞춰 크기를 조절하거나 가장자리를 잘라 표시합니다. '
          '각 사진의 권리와 라이선스는 아래 원본 및 라이선스 링크에서 확인할 수 있습니다.',
        ),
        const SizedBox(height: 16),
        for (final photo in ingredientReferencePhotos)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IngredientThumbnail(name: photo.name),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              photo.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('${photo.author} · ${photo.license}'),
                            Text(
                              photo.title,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => _open(context, photo.sourceUrl),
                        child: const Text('사진 원본·출처'),
                      ),
                      if (photo.licenseUrl.isNotEmpty)
                        TextButton(
                          onPressed: () => _open(context, photo.licenseUrl),
                          child: const Text('라이선스'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
