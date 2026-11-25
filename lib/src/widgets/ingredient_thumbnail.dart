import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/ingredient_photos.dart';

/// A bundled reference photograph, never evidence of the user's actual food.
/// Private uploaded photographs remain the outer IngredientPhoto's priority.
class IngredientThumbnail extends StatelessWidget {
  const IngredientThumbnail({
    super.key,
    required this.name,
    this.width = 76,
    this.height = 52,
  });

  final String name;
  final double width;
  final double height;

  // Continuous backgrounds fill their frame instead of showing random side
  // bars. Isolated subjects stay whole, including long vegetables and tofu.
  static const _scenePhotos = <String>{
    'garlic',
    'cucumber',
    'potato_chips',
    'spinach',
    'soft_tofu',
    'enoki',
    'soybean_sprouts',
    'mung_sprouts',
    'rice',
    'lettuce',
    'button_mushroom',
    'aehobak',
  };

  @override
  Widget build(BuildContext context) {
    final photo = ingredientReferencePhotoFor(name);
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: const Color(0xFFF5F5F5),
          child: photo == null
              ? _missingPhoto()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final shortestSide = math.min(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    final inset = (shortestSide * .06).clamp(3.0, 8.0);
                    return Padding(
                      padding: EdgeInsets.all(inset),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ColoredBox(
                          color: Colors.white,
                          child: Image.asset(
                            photo.assetPath,
                            semanticLabel: '$name 참고 사진',
                            width: double.infinity,
                            height: double.infinity,
                            fit: _scenePhotos.contains(photo.id)
                                ? BoxFit.cover
                                : BoxFit.contain,
                            cacheWidth: 512,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, _, _) => _missingPhoto(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _missingPhoto() => Semantics(
    label: '$name 사진 없음',
    excludeSemantics: true,
    child: const ColoredBox(
      color: Color(0xFFF5F5F5),
      child: Center(
        child: Icon(Icons.photo_outlined, color: Color(0xFF8B9488), size: 24),
      ),
    ),
  );
}
