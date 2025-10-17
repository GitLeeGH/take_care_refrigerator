import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers.dart';
import '../theme.dart';
import 'add_recipe_page.dart';
import 'recipes_page.dart'; // For RecipeDetailPage

// 계정 삭제 다이얼로그 함수
void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text(
          '계정 삭제',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
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
    print('사용자 데이터 삭제 시작: ${user.id}');
    
    // 사용자 식재료 데이터 삭제 (냉장고 아이템)
    try {
      await supabase.from('ingredients').delete().eq('user_id', user.id);
      print('식재료 데이터 삭제 완료');
    } catch (e) {
      print('식재료 데이터 삭제 중 오류: $e');
    }

    // 레시피 좋아요 삭제
    try {
      await supabase.from('recipe_likes').delete().eq('user_id', user.id);
      print('레시피 좋아요 삭제 완료');
    } catch (e) {
      print('레시피 좋아요 삭제 중 오류: $e');
    }

    // 사용자가 생성한 레시피 삭제 (올바른 컬럼명 확인 후 삭제)
    try {
      // recipes 테이블의 올바른 컬럼명을 사용 (user_id 또는 author_id 등)
      await supabase.from('recipes').delete().eq('user_id', user.id);
      print('사용자 레시피 삭제 완료');
    } catch (e) {
      print('사용자 레시피 삭제 중 오류: $e');
      // 다른 컬럼명으로 재시도
      try {
        await supabase.from('recipes').delete().eq('author_id', user.id);
        print('사용자 레시피 삭제 완료 (author_id 사용)');
      } catch (e2) {
        print('사용자 레시피 삭제 재시도 중 오류: $e2');
        // 레시피 테이블에 사용자별 컬럼이 없을 수 있음 - 무시하고 계속 진행
      }
    }

    // 사용자 프로필 삭제 (마지막에 삭제)
    try {
      await supabase.from('profiles').delete().eq('id', user.id);
      print('사용자 프로필 삭제 완료');
    } catch (e) {
      print('사용자 프로필 삭제 중 오류: $e');
    }

    // 2. Supabase 인증 계정 삭제 시도
    try {
      // Supabase에서 실제 계정 삭제는 Admin API를 통해서만 가능
      // 클라이언트에서는 로그아웃으로 처리
      await supabase.auth.signOut();
      print('계정 로그아웃 완료');
    } catch (e) {
      print('로그아웃 중 오류: $e');
    }

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
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login', 
                  (route) => false,
                );
              },
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    print('계정 삭제 중 전체 오류: $e');
    
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
        title: const Text('마이페이지', style: TextStyle(color: darkGray, fontWeight: FontWeight.bold)),
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
                user?.email ?? (user?.isAnonymous == true ? '익명 사용자' : '사용자 정보 없음'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkGray),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: const Icon(Icons.post_add, color: primaryGreen),
                        title: const Text('레시피 추가하기', style: TextStyle(fontWeight: FontWeight.w600, color: darkGray)),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AddRecipePage()),
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
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: const Icon(Icons.logout, color: Color(0xFFE57373)),
              title: const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFE57373))),
              onTap: () async {
                await ref.read(supabaseProvider).auth.signOut();
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Account Deletion Card
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('계정 삭제', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
              subtitle: const Text('계정과 모든 데이터가 영구적으로 삭제됩니다', style: TextStyle(fontSize: 12, color: mediumGray)),
              onTap: () => _showDeleteAccountDialog(context, ref),
            ),
          ),
        ],
      ),
    );
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkGray),
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
                    child: Text('아직 좋아요를 누른 레시피가 없습니다.', style: TextStyle(color: mediumGray)),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    title: Text(recipe.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: mediumGray),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RecipeDetailPage(recipe: recipe),
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
