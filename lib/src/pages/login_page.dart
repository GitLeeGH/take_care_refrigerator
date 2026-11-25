import '../app_variant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_gateway.dart';

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

  Future<void> _social(OAuthProvider provider) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final launched = await ref.read(authGatewayProvider).oauth(provider);
      if (launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '로그인 창에서 인증을 마쳐 주세요. 앱으로 돌아오지 않거나 로그인이 유지되지 않으면 다시 시도해 주세요.',
            ),
          ),
        );
      }
      if (!launched && mounted) {
        _showErrorSnackBar('로그인 화면을 열지 못했어요. 다시 시도해 주세요.');
      }
    } catch (_) {
      if (mounted) _showErrorSnackBar('로그인 연결을 확인하고 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() => _social(OAuthProvider.google);
  Future<void> _signInWithKakao() async {
    if (!const bool.fromEnvironment('KAKAO_OAUTH_ENABLED')) return;
    await _social(OAuthProvider.kakao);
  }

  Future<void> _email({required bool signup}) async {
    if (_isLoading || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      final gateway = ref.read(authGatewayProvider);
      if (signup) {
        final signedIn = await gateway.signUp(
          _emailController.text.trim(),
          _passwordController.text,
        );
        if (mounted && !signedIn) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('가입 요청을 접수했어요. 인증 메일이 도착하면 안내를 확인해 주세요.'),
            ),
          );
        }
      } else {
        await gateway.signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
    } catch (_) {
      if (mounted) {
        _showErrorSnackBar('요청을 완료하지 못했어요. 입력 정보와 연결을 확인하고 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithEmail() => _email(signup: false);
  Future<void> _signUpWithEmail() => _email(signup: true);

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
                    if (_isLoading) const LinearProgressIndicator(),
                    if (_showEmailForm)
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
              '개발용 앱 · Google 로그인은 이 앱의 전용 콜백 주소를 사용해요. 로그인 후 돌아오지 않으면 창을 닫고 다시 시도해 주세요.',
              textAlign: TextAlign.center,
            ),
          ),
        ElevatedButton(
          onPressed: _isLoading ? null : _signInWithGoogle,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
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
          onPressed:
              isDevelopmentApp ||
                  _isLoading ||
                  !const bool.fromEnvironment('KAKAO_OAUTH_ENABLED')
              ? null
              : _signInWithKakao,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFEE500), // Kakao yellow
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            const bool.fromEnvironment('KAKAO_OAUTH_ENABLED')
                ? '카카오로 로그인'
                : '카카오 로그인 준비 중',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF191919),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (!const bool.fromEnvironment('KAKAO_OAUTH_ENABLED'))
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '카카오 계정 연결을 확인 중이에요. 익명 계정으로 대신 로그인하지 않아요.',
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isLoading
              ? null
              : () => setState(() => _showEmailForm = true),
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
                enabled: !_isLoading,
                decoration: const InputDecoration(labelText: '이메일'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => (value == null || !value.contains('@'))
                    ? '유효한 이메일을 입력하세요.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                enabled: !_isLoading,
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
          onPressed: _isLoading ? null : _signInWithEmail,
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
          onPressed: _isLoading ? null : _signUpWithEmail,
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
          onPressed: _isLoading
              ? null
              : () => setState(() => _showEmailForm = false),
          child: const Text('뒤로가기', style: TextStyle(color: mediumGray)),
        ),
      ],
    );
  }
}
