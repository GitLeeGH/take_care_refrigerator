import 'package:flutter/material.dart';
import '../theme.dart';

/// Only existing receipt registration is advertised, not fridge recognition.
class RegistrationHero extends StatelessWidget {
  const RegistrationHero({
    super.key,
    required this.onGallery,
    required this.onCamera,
  });
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xFFFFE7E0), Color(0xFFF7B5A5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final large = MediaQuery.textScalerOf(context).scale(16) > 23;
          final gallery = FilledButton.icon(
            onPressed: onGallery,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: primaryGreen,
            ),
            icon: const Icon(Icons.photo_library_outlined, size: 20),
            label: const Text('사진 선택'),
          );
          final camera = OutlinedButton.icon(
            onPressed: onCamera,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: primaryGreen),
              backgroundColor: Colors.white.withValues(alpha: .26),
            ),
            icon: const Icon(Icons.camera_alt_outlined, size: 20),
            label: const Text('직접 촬영'),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI 재료 등록',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.7,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '영수증 사진으로 품목을 확인하고 등록해요.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: darkGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!large) ...[
                    const SizedBox(width: 12),
                    ExcludeSemantics(
                      child: Transform.rotate(
                        angle: .08,
                        child: Container(
                          width: 66,
                          height: 82,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .8),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.receipt_long_outlined,
                            size: 44,
                            color: primaryGreen,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              if (large || constraints.maxWidth < 260)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [gallery, const SizedBox(height: 10), camera],
                )
              else
                Row(
                  children: [
                    Expanded(child: gallery),
                    const SizedBox(width: 10),
                    Expanded(child: camera),
                  ],
                ),
            ],
          );
        },
      ),
    ),
  );
}
