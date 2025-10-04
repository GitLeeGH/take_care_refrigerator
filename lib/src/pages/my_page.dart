import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme.dart';
import 'add_recipe_page.dart'; // Added import

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
        ],
      ),
    );
  }
}
