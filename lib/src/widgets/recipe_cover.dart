import 'package:flutter/material.dart';
import '../services/original_video.dart';

/// Direct display only: no image upload, backend copy or persistent disk cache.
class RecipeCover extends StatelessWidget {
  const RecipeCover({
    super.key,
    this.imageUrl,
    this.video,
    this.label = '레시피 이미지',
  });
  final String? imageUrl;
  final OriginalVideo? video;
  final String label;

  List<Uri> get sources {
    final uploaded = Uri.tryParse(imageUrl?.trim() ?? '');
    final thumbnail = video?.thumbnailUrl;
    return [
      if (uploaded != null &&
          uploaded.scheme == 'https' &&
          uploaded.host.isNotEmpty &&
          uploaded.userInfo.isEmpty)
        uploaded,
      if (thumbnail != null && thumbnail != uploaded) thumbnail,
    ];
  }

  Widget placeholder(String message) => ColoredBox(
    color: const Color(0xFFE8EDE5),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.image_outlined,
              size: 32,
              color: Color(0xFF506655),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF344C3B)),
            ),
          ],
        ),
      ),
    ),
  );

  Widget sourceAt(List<Uri> candidates, int index) {
    if (index == candidates.length) {
      return placeholder(
        candidates.isEmpty ? '등록된 이미지가 없어요' : '이미지를 불러올 수 없어요',
      );
    }
    final source = candidates[index];
    final youtube = source == video?.thumbnailUrl;
    return ColoredBox(
      color: youtube ? Colors.black : const Color(0xFFE8EDE5),
      child: Image.network(
        source.toString(),
        width: double.infinity,
        height: double.infinity,
        fit: youtube ? BoxFit.contain : BoxFit.cover,
        semanticLabel: youtube ? 'YouTube 영상 썸네일' : label,
        frameBuilder: (context, child, frame, wasSync) =>
            wasSync || frame != null ? child : placeholder('이미지 불러오는 중'),
        errorBuilder: (context, error, stack) =>
            sourceAt(candidates, index + 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => sourceAt(sources, 0);
}
