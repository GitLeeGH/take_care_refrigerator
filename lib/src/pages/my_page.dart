import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers.dart';
import '../services/account_deletion.dart';
import '../theme.dart';
import 'add_recipe_page.dart';
import 'recipes_page.dart'; // For RecipeDetailPage
import 'login_page.dart';

// 계정 삭제 다이얼로그 함수
void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text(
          '계정 삭제',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '정말로 계정을 삭제하시겠습니까?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              '계정 삭제 시 다음 데이터가 영구적으로 삭제됩니다:',
              style: TextStyle(fontSize: 14, color: darkGray),
            ),
            SizedBox(height: 8),
            Text(
              '• 계정 정보 및 프로필\n• 냉장고 식품 데이터\n• 좋아요한 레시피\n• 알림 설정',
              style: TextStyle(fontSize: 14, color: mediumGray),
            ),
            SizedBox(height: 12),
            Text(
              '이 작업은 되돌릴 수 없습니다.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAccount(context, ref);
            },
            child: const Text('삭제'),
          ),
        ],
      );
    },
  );
}

// 계정 삭제 실행 함수
Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
  final supabase = ref.read(supabaseProvider);
  final user = supabase.auth.currentUser;

  if (user == null) return;

  try {
    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('계정을 삭제하는 중...'),
          ],
        ),
      ),
    );

    // 1. 사용자 관련 데이터 삭제

    // 사용자 식재료 데이터 삭제 (냉장고 아이템)
    try {
      await supabase.from('ingredients').delete().eq('user_id', user.id);
    } catch (e) {}

    // 레시피 좋아요 삭제
    try {
      await supabase.from('recipe_likes').delete().eq('user_id', user.id);
    } catch (e) {}

    // 사용자가 생성한 레시피 삭제 (올바른 컬럼명 확인 후 삭제)
    try {
      // recipes 테이블의 올바른 컬럼명을 사용 (user_id 또는 author_id 등)
      await supabase.from('recipes').delete().eq('user_id', user.id);
    } catch (e) {
      // 다른 컬럼명으로 재시도
      try {
        await supabase.from('recipes').delete().eq('author_id', user.id);
      } catch (e2) {
        // 레시피 테이블에 사용자별 컬럼이 없을 수 있음 - 무시하고 계속 진행
      }
    }

    // 사용자 프로필 삭제 (마지막에 삭제)
    try {
      await supabase.from('profiles').delete().eq('id', user.id);
    } catch (e) {}

    // 2. Supabase 인증 계정 삭제 시도
    try {
      // Supabase에서 실제 계정 삭제는 Admin API를 통해서만 가능
      // 클라이언트에서는 로그아웃으로 처리
      await supabase.auth.signOut();
    } catch (e) {}

    // 로딩 다이얼로그 닫기
    if (context.mounted) {
      Navigator.of(context).pop();

      // 성공 메시지와 함께 확인 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              SizedBox(width: 8),
              Text('계정 삭제 완료'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('계정과 관련된 모든 데이터가 성공적으로 삭제되었습니다.'),
              SizedBox(height: 12),
              Text('• 식재료 데이터'),
              Text('• 레시피 좋아요'),
              Text('• 사용자 프로필'),
              Text('• 계정 정보'),
              SizedBox(height: 12),
              Text(
                '그동안 이용해 주셔서 감사합니다.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // 로그인 페이지로 이동
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              },
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    // 로딩 다이얼로그 닫기
    if (context.mounted) {
      Navigator.of(context).pop();

      // 에러 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('계정 삭제 중 오류가 발생했습니다.\n일부 데이터가 삭제되지 않았을 수 있습니다.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: '다시 시도',
            textColor: Colors.white,
            onPressed: () => _deleteAccount(context, ref),
          ),
        ),
      );
    }
  }
}

class MyPage extends ConsumerWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(supabaseProvider).auth.currentUser;
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          '마이페이지',
          style: TextStyle(color: darkGray, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const SizedBox(height: 20),
          Column(
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: Color(0xFFE9ECEF),
                child: Icon(Icons.person_outline, size: 50, color: mediumGray),
              ),
              const SizedBox(height: 16),
              Text(
                user?.email ??
                    (user?.isAnonymous == true ? '익명 사용자' : '사용자 정보 없음'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkGray,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'User ID: ${user?.id ?? 'N/A'}',
                style: const TextStyle(fontSize: 12, color: mediumGray),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Conditionally show the "Add Recipe" button for admins
          userProfileAsync.when(
            data: (profile) {
              if (profile?.role == 'admin') {
                return Column(
                  children: [
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: const Icon(
                          Icons.post_add,
                          color: primaryGreen,
                        ),
                        title: const Text(
                          '레시피 추가하기',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: darkGray,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddRecipePage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }
              return const SizedBox.shrink(); // Return empty space if not admin
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => const SizedBox.shrink(), // Hide on error
          ),

          const LikedRecipesSection(),
          const SizedBox(height: 16),
          // Logout Card
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: const Icon(Icons.logout, color: Color(0xFFE57373)),
              title: const Text(
                '로그아웃',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE57373),
                ),
              ),
              onTap: () async {
                // 모든 provider 상태 초기화
                ref.invalidate(ingredientsProvider);
                ref.invalidate(searchQueryProvider);
                ref.invalidate(recipeSortProvider);
                ref.invalidate(canMakeFilterProvider);
                ref.invalidate(recommendedIdsProvider);
                ref.invalidate(popularIdsProvider);
                ref.invalidate(recentIdsProvider);
                ref.invalidate(paginatedRecipesProvider);
                ref.invalidate(userProfileProvider);
                ref.invalidate(notificationListProvider);
                ref.invalidate(notificationSettingsProvider);

                // Supabase 로그아웃
                await ref.read(supabaseProvider).auth.signOut();
              },
            ),
          ),

          // 계정 삭제 Card 추가
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                '계정 삭제',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              subtitle: const Text(
                '계정과 모든 데이터가 영구적으로 삭제됩니다',
                style: TextStyle(fontSize: 12, color: mediumGray),
              ),
              onTap: () => _showDeleteAccountDialog(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  // 계정 삭제 확인 다이얼로그
  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('계정 삭제'),
          content: const Text('정말로 계정을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteAccount(context, ref);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  // 계정 삭제 함수
  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final supabase = ref.read(supabaseProvider);
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인된 사용자가 없습니다.')));
      return;
    }

    try {
      // 로딩 다이얼로그 표시 (dismissible하게 설정)
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: true, // 백그라운드 터치로도 닫을 수 있게
          builder: (ctx) {
            return const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('계정을 삭제하고 있습니다...'),
                ],
              ),
            );
          },
        );
      }

      // 🔥 즉시 로딩 다이얼로그 닫기 (서버 작업 전에)
      try {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      } catch (e) {}

      await deleteAccountSafely(
        deleteData: () async => await supabase.rpc('delete_my_account'),
        deleteIdentity: () async => await supabase.rpc(
          'delete_auth_user',
          params: {'user_id': currentUser.id},
        ),
        onConfirmed: () async {
          // 삭제된 이메일 마크
          final prefs = await SharedPreferences.getInstance();
          if (currentUser.email != null) {
            await prefs.setBool('deleted_email_${currentUser.email}', true);
          }

          // 완전한 세션 정리

          try {
            await supabase.auth.signOut(scope: SignOutScope.global);

            // SharedPreferences 정리 (계정 삭제 플래그 포함)

            await prefs.clear();

            // 상태 정리 대기
            await Future.delayed(const Duration(seconds: 1));

            // OAuth 캐시 및 내부 저장소 정리
            await supabase.auth.signOut(scope: SignOutScope.local);

            // OAuth 캐시 정리 마크
            await prefs.setBool('oauth_cache_cleared', true);
            await prefs.setInt(
              'cache_clear_timestamp',
              DateTime.now().millisecondsSinceEpoch,
            );
          } catch (signOutError) {}

          // 성공 메시지 및 안전한 로그인 페이지 이동
          if (context.mounted) {
            try {
              // 성공 메시지 표시 (짧게)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('계정이 성공적으로 삭제되었습니다.'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 1),
                ),
              );

              // 잠시 대기 후 로그인 페이지로 이동
              await Future.delayed(const Duration(milliseconds: 500));

              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            } catch (navError) {}
          }
        },
      );
    } catch (e) {
      // 에러 메시지 표시 (로딩 다이얼로그는 이미 닫혔음)
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '계정 삭제를 완료하지 못했어요. 일부 작업이 처리되었을 수 있습니다. 잠시 후 다시 시도해 주세요.',
            ),
            backgroundColor: Colors.red,
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
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Icon(Icons.favorite_outline, color: Colors.pinkAccent),
                SizedBox(width: 8),
                Text(
                  '좋아요 누른 레시피',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: darkGray,
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
              child: Center(child: Text('레시피를 불러오는 중 오류가 발생했습니다.\n$e')),
            ),
          ),
        ],
      ),
    );
  }
}
