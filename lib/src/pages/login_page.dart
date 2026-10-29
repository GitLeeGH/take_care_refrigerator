import '../app_variant.dart';
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
    if (isDevelopmentApp) return;
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseProvider);

      final launched = await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? null
            : 'io.supabase.flutterquickstart://login-callback/',
      );
      if (!launched && mounted) {
        _showErrorSnackBar('로그인 화면을 열지 못했어요. 다시 시도해 주세요.');
      }
    } on AuthException catch (e) {
      if (mounted) _showErrorSnackBar('인증 오류: ${e.message}');
    } catch (_) {
      if (mounted) _showErrorSnackBar('구글 로그인에 실패했어요. 잠시 후 다시 시도해 주세요.');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithKakao() async {
    if (isDevelopmentApp) return;
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      // Enable only after the provider and legacy-user migration are reviewed.
      // Never fall back to an anonymous account after an OAuth failure.
      if (const bool.fromEnvironment('KAKAO_OAUTH_ENABLED')) {
        final launched = await ref
            .read(supabaseProvider)
            .auth
            .signInWithOAuth(
              OAuthProvider.kakao,
              redirectTo: kIsWeb
                  ? null
                  : 'io.supabase.flutterquickstart://login-callback/',
            );
        if (!launched && mounted) {
          _showErrorSnackBar('로그인 화면을 열지 못했어요. 다시 시도해 주세요.');
        }
        return;
      }
      // Use the account flow when KakaoTalk is not installed.
      if (await kakao.isKakaoTalkInstalled()) {
        await kakao.UserApi.instance.loginWithKakaoTalk();
      } else {
        await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      // 카카오 사용자 정보 가져오기
      kakao.User kakaoUser = await kakao.UserApi.instance.me();

      final String kakaoId = kakaoUser.id.toString();
      final String? email = kakaoUser.kakaoAccount?.email;
      final String? nickname = kakaoUser.kakaoAccount?.profile?.nickname;

      // Legacy identity flow. Metadata does not establish a verified identity.
      final supabase = ref.read(supabaseProvider);
      // 익명 로그인 후 사용자 데이터에 카카오 정보 저장
      final response = await supabase.auth.signInAnonymously();

      if (response.user != null) {
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
      }
    } catch (e) {
      final cancelled =
          e is kakao.KakaoClientException &&
          e.reason == kakao.ClientErrorCause.cancelled;
      if (mounted && !cancelled)
        _showErrorSnackBar('카카오 로그인에 실패했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithEmail() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(supabaseProvider)
          .auth
          .signInWithPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
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
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(supabaseProvider)
          .auth
          .signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
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
                  minHeight: (constraints.maxHeight - 48).clamp(
                    0.0,
                    double.infinity,
                  ), // 패딩 고려
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
        if (isDevelopmentApp)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              '개발용 앱 · 이메일 로그인을 이용해 주세요.\nGoogle·카카오 로그인은 개발용 연결 설정 전까지 사용할 수 없습니다.',
              textAlign: TextAlign.center,
            ),
          ),
        ElevatedButton(
          onPressed: isDevelopmentApp ? null : _signInWithGoogle,
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
          onPressed: isDevelopmentApp ? null : _signInWithKakao,
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
