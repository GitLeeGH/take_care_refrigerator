import 'recipe_photo_credits_page.dart';
import 'ingredient_photo_credits_page.dart';
import 'receipt_synthetic_pilot_page.dart';
import 'receipt_pilot_preparation_page.dart';
import '../services/reminder_auth_boundary.dart';
import '../widgets/logout_tile.dart';
import '../widgets/account_deletion_tile.dart';
import '../widgets/app_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers.dart';
import '../services/account_deletion.dart';
import '../theme.dart';
import 'add_recipe_page.dart';
import 'recipes_page.dart';

class MyPage extends ConsumerWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentSessionUserProvider)();
    final profile = ref.watch(userProfileProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: pageToolbarHeight(context),
        title: const Text('마이페이지'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(pageGutter, 12, pageGutter, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: softGreen,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person_outline, color: primaryGreen),
                    ),
                    SizedBox(width: 12),
                    Expanded(child: Text('나의 주방', style: sectionHeadingStyle)),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  user?.email ??
                      (user?.isAnonymous == true ? '익명 사용자' : '사용자 정보 없음'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '내 냉장고와 저장한 레시피',
                  style: TextStyle(fontSize: 13, color: mediumGray),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          profile.when(
            data: (value) => value?.role == 'admin'
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.post_add_outlined),
                        title: const Text(
                          '레시피 추가하기',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AddRecipePage(),
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const LikedRecipesSection(),
          const SizedBox(height: 24),
          const Text('앱 정보', style: sectionHeadingStyle),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('재료 사진 출처'),
              subtitle: const Text('참고 사진과 사용 라이선스'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const IngredientPhotoCreditsPage(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restaurant_outlined),
              title: const Text('음식 사진 출처'),
              subtitle: const Text('완성 요리 사진과 사용 조건'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RecipePhotoCreditsPage(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const ReceiptSyntheticPilotLauncher(),
          const ReceiptPilotPreparationLauncher(),
          const Text('계정 관리', style: sectionHeadingStyle),
          const SizedBox(height: 12),
          const Card(child: LogoutTile()),
          const SizedBox(height: 12),
          Card(
            child: AccountDeletionTile(
              onDelete: () => _deleteAccount(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final supabase = ref.read(supabaseProvider);
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인된 사용자가 없습니다.')));
      return;
    }
    bool stillCurrent() =>
        context.mounted && supabase.auth.currentUser?.id == currentUser.id;
    try {
      await invalidateReminderSession();
      await deleteAccountSafely(
        stillCurrent: stillCurrent,
        deleteData: () async => await supabase.rpc('delete_my_account'),
        deleteIdentity: () async => await supabase.rpc(
          'delete_auth_user',
          params: {'user_id': currentUser.id},
        ),
        onConfirmed: () async {
          if (!stillCurrent()) throw StateError('Account changed');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('계정이 성공적으로 삭제되었습니다.')));
          // The pinned auth SDK captures this account and removes its local
          // session before its first await. The auth gate owns navigation.
          // Never clear all-device preferences or sign out again after a delay.
          try {
            await supabase.auth.signOut(scope: SignOutScope.global);
          } catch (_) {
            // Both server deletion steps succeeded. A remote signout failure
            // does not justify retrying against a replacement account.
            if (stillCurrent()) rethrow;
          }
        },
      );
    } catch (_) {
      if (stillCurrent()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '계정 삭제를 완료하지 못했어요. 일부 작업이 처리되었을 수 있습니다. 잠시 후 다시 시도해 주세요.',
            ),
            backgroundColor: dangerInk,
          ),
        );
      }
    }
  }
}

class LikedRecipesSection extends ConsumerWidget {
  const LikedRecipesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedRecipesAsync = ref.watch(likedRecipesProvider);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Icon(Icons.favorite_outline, color: primaryGreen),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '좋아요 누른 레시피',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: darkGray,
                    ),
                  ),
                ),
              ],
            ),
          ),
          likedRecipesAsync.when(
            data: (recipes) {
              if (recipes.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Center(
                    child: Text(
                      '아직 좋아요를 누른 레시피가 없습니다.',
                      style: TextStyle(color: mediumGray),
                    ),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  final recipe = recipes[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    title: Text(
                      recipe.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: mediumGray,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              RecipeDetailPage(recipe: recipe),
                        ),
                      );
                    },
                  );
                },
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) => Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      '좋아요 레시피를 불러오지 못했어요.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(likedRecipesProvider),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('다시 불러오기'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
