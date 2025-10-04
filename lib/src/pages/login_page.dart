import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      if (kIsWeb) {
        // For web, use Supabase's OAuth redirect flow
        await ref.read(supabaseProvider).auth.signInWithOAuth(OAuthProvider.google);
      } else {
        // For mobile, use google_sign_in to get the idToken
        final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID']!;
        final googleSignIn = GoogleSignIn.instance;
        await googleSignIn.initialize(serverClientId: webClientId);
        final googleUser = await googleSignIn.authenticate();
        final idToken = (await googleUser!.authentication).idToken!;

        await ref.read(supabaseProvider).auth.signInWithIdToken(
              provider: OAuthProvider.google,
              idToken: idToken,
            );
      }
    } on AuthException catch (e) {
      if (mounted) _showErrorSnackBar(e.message);
    } catch (e) {
      if (mounted) _showErrorSnackBar('An unexpected error occurred: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(supabaseProvider).auth.signInWithPassword(
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
      await ref.read(supabaseProvider).auth.signUp(
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              const Icon(Icons.kitchen_outlined, size: 80, color: primaryGreen),
              const SizedBox(height: 20),
              const Text(
                '냉장고를 부탁해',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: darkGray),
              ),
              const SizedBox(height: 8),
              const Text(
                '당신의 냉장고를 스마트하게 관리하세요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: mediumGray),
              ),
              const Spacer(flex: 3),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_showEmailForm)
                _buildEmailForm()
              else
                _buildInitialActions(),
              const Spacer(flex: 1),
            ],
          ),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Google로 로그인', style: TextStyle(fontSize: 16, color: darkGray, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _showEmailForm = true),
          child: const Text('이메일로 로그인 또는 회원가입', style: TextStyle(color: mediumGray)),
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
                validator: (value) => (value == null || !value.contains('@')) ? '유효한 이메일을 입력하세요.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: '비밀번호'),
                obscureText: true,
                validator: (value) => (value == null || value.length < 6) ? '6자 이상의 비밀번호를 입력하세요.' : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _signInWithEmail,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('이메일로 로그인', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _signUpWithEmail,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: primaryBlue),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('이메일로 회원가입', style: TextStyle(fontSize: 16, color: primaryBlue)),
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
