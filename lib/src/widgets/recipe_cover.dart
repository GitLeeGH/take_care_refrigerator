import '../services/recipe_example_photos.dart';
import '../theme.dart';
import 'package:flutter/material.dart';
import '../services/original_video.dart';
import '../services/recipe_photos.dart';

/// Direct display and reviewed bundled photos. No upload or persistent cache.
class RecipeCover extends StatelessWidget {
  const RecipeCover({
    super.key,
    this.imageUrl,
    this.video,
    this.photo,
    this.examplePhoto,
    this.label = '레시피 이미지',
    this.backgroundOnlyPlaceholder = false,
    this.imageAspectRatio,
    this.placeholderBuilder,
  });
  final String? imageUrl;
  final OriginalVideo? video;
  final RecipePhoto? photo;
  final RecipeExamplePhoto? examplePhoto;
  final String label;
  final bool backgroundOnlyPlaceholder;
  final double? imageAspectRatio;
  final Widget Function(String message)? placeholderBuilder;

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

  bool get hasSources =>
      sources.isNotEmpty || photo != null || examplePhoto != null;

  Widget placeholder(String message) =>
      placeholderBuilder?.call(message) ??
      (backgroundOnlyPlaceholder
          ? Semantics(
              label: message,
              child: const ColoredBox(color: softGreen),
            )
          : ColoredBox(
              color: softGreen,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.image_outlined,
                        size: 32,
                        color: mediumGray,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: darkGray),
                      ),
                    ],
                  ),
                ),
              ),
            ));

  Widget frame(BuildContext context, Widget child, int? frame, bool wasSync) =>
      wasSync || frame != null
      ? imageAspectRatio == null
            ? child
            : AspectRatio(aspectRatio: imageAspectRatio!, child: child)
      : placeholder('이미지 불러오는 중');

  Widget bundledOrPlaceholder(String message) {
    final reference = photo;
    if (reference == null) return exampleOrPlaceholder(message);
    return ColoredBox(
      color: softGreen,
      child: Image.asset(
        reference.assetPath,
        key: ValueKey('recipe-photo:${reference.assetPath}'),
        alignment: Alignment(0, reference.focalY),
        width: double.infinity,
        height: imageAspectRatio == null ? double.infinity : null,
        cacheWidth: 768,
        fit: BoxFit.cover,
        semanticLabel: '${reference.name} 완성 음식 사진 · ${RecipePhoto.author}',
        frameBuilder: frame,
        errorBuilder: (_, _, _) => exampleOrPlaceholder('음식 사진을 불러올 수 없어요'),
      ),
    );
  }

  Widget exampleOrPlaceholder(String message) {
    final example = examplePhoto;
    if (example == null) return placeholder(message);
    return Image.asset(
      example.assetPath,
      key: ValueKey('recipe-example:${example.assetPath}'),
      width: double.infinity,
      height: imageAspectRatio == null ? double.infinity : null,
      cacheWidth: 768,
      fit: BoxFit.cover,
      semanticLabel: '${example.name} 예시 사진. 이 레시피의 실제 완성 사진은 아닙니다.',
      frameBuilder: (context, child, index, wasSync) {
        if (!wasSync && index == null) return placeholder('이미지 불러오는 중');
        return Stack(
          fit: StackFit.passthrough,
          children: [
            frame(context, child, index, wasSync),
            Positioned(
              left: 10,
              right: 10,
              top: 10,
              child: Align(
                alignment: Alignment.topRight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    child: Text(
                      '예시 사진',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: darkGray,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      errorBuilder: (_, _, _) => placeholder('음식 사진을 불러올 수 없어요'),
    );
  }

  Widget sourceAt(List<Uri> candidates, int index) {
    if (index == candidates.length) {
      return bundledOrPlaceholder(
        candidates.isEmpty ? '등록된 이미지가 없어요' : '이미지를 불러올 수 없어요',
      );
    }
    final source = candidates[index];
    final youtube = source == video?.thumbnailUrl;
    return ColoredBox(
      color: youtube ? Colors.black : softGreen,
      child: Image.network(
        source.toString(),
        width: double.infinity,
        height: imageAspectRatio == null ? double.infinity : null,
        fit: youtube ? BoxFit.contain : BoxFit.cover,
        semanticLabel: youtube ? 'YouTube 영상 썸네일' : label,
        frameBuilder: frame,
        errorBuilder: (_, _, _) => sourceAt(candidates, index + 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => sourceAt(sources, 0);
}
