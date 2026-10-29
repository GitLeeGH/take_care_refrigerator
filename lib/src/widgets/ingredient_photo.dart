import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

final ingredientPhotoBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, path) async {
      final client = ref.watch(supabaseProvider);
      final uid = client.auth.currentUser?.id;
      final subscription = client.auth.onAuthStateChange.listen((state) {
        if (state.session?.user.id != uid) ref.invalidateSelf();
      });
      ref.onDispose(subscription.cancel);
      if (uid == null || path.split('/').first != uid) {
        throw StateError('Photo unavailable');
      }
      final bytes = await client.storage
          .from('ingredient-photos')
          .download(path);
      if (client.auth.currentUser?.id != uid) {
        throw StateError('Session changed');
      }
      return bytes;
    });

class IngredientPhoto extends ConsumerWidget {
  const IngredientPhoto({
    super.key,
    required this.path,
    required this.fallback,
  });
  final String? path;
  final Widget fallback;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (path == null) return fallback;
    return ref
        .watch(ingredientPhotoBytesProvider(path!))
        .when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          data: (bytes) => Image.memory(
            bytes,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            semanticLabel: '저장한 재료 사진',
            errorBuilder: (_, _, _) => fallback,
          ),
          loading: () => const Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, _) => IconButton(
            tooltip: '사진 다시 불러오기',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(ingredientPhotoBytesProvider(path!)),
          ),
        );
  }
}
