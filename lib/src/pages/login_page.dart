import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import '../providers.dart';
import '../theme.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _isLoading = false;
  bool _showEmailForm = false; // To toggle email/password form

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      print('구글 로그인 시도 시작 - Supabase OAuth 사용');

      final supabase = ref.read(supabaseProvider);

      if (kIsWeb) {
        // 웹에서는 OAuth 리다이렉트 플로우 사용
        print('웹에서 구글 OAuth 로그인 시도');
        await supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: kIsWeb
              ? null
              : 'io.supabase.flutterquickstart://login-callback/',
        );
      } else {
        // 모바일에서는 OAuth 리다이렉트 플로우 사용 (더 간단함)
        print('모바일에서 구글 OAuth 로그인 시도');
        await supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'io.supabase.flutterquickstart://login-callback/',
        );
      }

      print('구글 로그인 요청 완료');
    } on AuthException catch (e) {
      print('인증 에러: ${e.message}');
      if (mounted) _showErrorSnackBar('인증 오류: ${e.message}');
    } catch (e) {
      print('일반 에러: $e');
      if (mounted) _showErrorSnackBar('구글 로그인 오류: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithKakao() async {
    setState(() => _isLoading = true);
    try {
      print('🥳 카카오 로그인 시작');

      // 카카오톡 앱으로 로그인 시도, 실패하면 카카오계정으로 로그인
      if (await kakao.isKakaoTalkInstalled()) {
        print('📱 카카오톡 앱이 설치되어 있음. 카카오톡으로 로그인 시도');
        await kakao.UserApi.instance.loginWithKakaoTalk();
      } else {
        print('🌐 카카오톡 앱이 없음. 카카오계정으로 로그인 시도');
        await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      print('✅ 카카오 로그인 성공');

      // 카카오 사용자 정보 가져오기
      kakao.User kakaoUser = await kakao.UserApi.instance.me();
      print('👤 카카오 사용자 정보 가져오기 성공');

      final String kakaoId = kakaoUser.id.toString();
      final String? email = kakaoUser.kakaoAccount?.email;
      final String? nickname = kakaoUser.kakaoAccount?.profile?.nickname;

      print('📋 카카오 사용자 정보: ID=$kakaoId, email=$email, nickname=$nickname');

      // 간단한 익명 로그인 방식으로 처리 (더 안정적)
      final supabase = ref.read(supabaseProvider);

      print('🔐 Supabase 익명 로그인 시도');
      // 익명 로그인 후 사용자 데이터에 카카오 정보 저장
      final response = await supabase.auth.signInAnonymously();

      if (response.user != null) {
        print('🎯 Supabase 로그인 성공, 사용자 정보 업데이트 중');
        await supabase.auth.updateUser(
          UserAttributes(
            data: {
              'kakao_id': kakaoId,
              'provider': 'kakao',
              'nickname': nickname,
              'email': email,
              'display_name': nickname,
            },
          ),
        );
        print('✨ 사용자 정보 업데이트 완료');
      }
    } catch (e) {
      print('❌ 카카오 로그인 에러: $e');
      print('❌ 에러 타입: ${e.runtimeType}');
      if (e is kakao.KakaoException) {
        print('❌ 카카오 에러 정보: ${e.toString()}');
      }
      if (mounted) _showErrorSnackBar('카카오 로그인 중 오류가 발생했습니다: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(supabaseProvider)
          .auth
          .signInWithPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
    } on AuthException catch (e) {
      if (mounted) _showErrorSnackBar(e.message);
    } catch (e) {
      if (mounted) _showErrorSnackBar('An unexpected error occurred.');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(supabaseProvider)
          .auth
          .signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입 완료! 이메일을 확인하여 인증해주세요.')),
        );
        setState(() => _showEmailForm = false); // Hide form after signup
      }
    } on AuthException catch (e) {
      if (mounted) _showErrorSnackBar(e.message);
    } catch (e) {
      if (mounted) _showErrorSnackBar('An unexpected error occurred.');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // 키보드 대응을 위해 추가
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              // 스크롤 가능하게 변경
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48, // 패딩 고려
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: constraints.maxHeight * 0.1,
                    ), // 상단 여백을 고정값으로
                    const Icon(
                      Icons.kitchen_outlined,
                      size: 80,
                      color: primaryGreen,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '냉장고를 부탁해',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: darkGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '당신의 냉장고를 스마트하게 관리하세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: mediumGray),
                    ),
                    SizedBox(height: constraints.maxHeight * 0.15), // 중간 여백
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_showEmailForm)
                      _buildEmailForm()
                    else
                      _buildInitialActions(),
                    SizedBox(
                      height: constraints.maxHeight * 0.05,
                    ), // 하단 여백을 고정값으로
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInitialActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _signInWithGoogle,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Google로 로그인',
            style: TextStyle(
              fontSize: 16,
              color: darkGray,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _signInWithKakao,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFEE500), // Kakao yellow
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            '카카오로 로그인',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF191919),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _showEmailForm = true),
          child: const Text(
            '이메일로 로그인 또는 회원가입',
            style: TextStyle(color: mediumGray),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: '이메일'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => (value == null || !value.contains('@'))
                    ? '유효한 이메일을 입력하세요.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: '비밀번호'),
                obscureText: true,
                validator: (value) => (value == null || value.length < 6)
                    ? '6자 이상의 비밀번호를 입력하세요.'
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _signInWithEmail,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue, // Change color for better visibility
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            '이메일로 로그인',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _signUpWithEmail,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: primaryBlue),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            '이메일로 회원가입',
            style: TextStyle(fontSize: 16, color: primaryBlue),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _showEmailForm = false),
          child: const Text('뒤로가기', style: TextStyle(color: mediumGray)),
        ),
      ],
    );
  }
}
