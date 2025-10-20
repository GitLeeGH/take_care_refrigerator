import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

import 'src/theme.dart';
import 'src/providers.dart';
import 'src/pages/home_page.dart';
import 'src/pages/recipes_page.dart';
import 'src/pages/notifications_page.dart';
import 'src/pages/my_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/pages/onboarding_page.dart';
import 'package:take_care_refrigerator/src/pages/login_page.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

Future<void> main() async {
  print('🚨🚨🚨 MAIN 함수 시작 - NEW VERSION 2024.10.19 🚨🚨🚨');
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Kakao SDK
  print('🥳 Kakao SDK 초기화 시작');
  KakaoSdk.init(nativeAppKey: '5f221c04f30c10b07c1f376aedf67b61');
  print('✅ Kakao SDK 초기화 완료');

  // Temporary key hash code removed.

  final prefs = await SharedPreferences.getInstance();
  final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(ProviderScope(child: MyApp(hasSeenOnboarding: hasSeenOnboarding)));
}

class MyApp extends StatelessWidget {
  final bool hasSeenOnboarding;
  const MyApp({super.key, required this.hasSeenOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '냉장고를 부탁해',
      theme: appTheme, // Use the theme from theme.dart
      home: hasSeenOnboarding ? const AuthChecker() : const OnboardingPage(),
    );
  }
}

// Correctly listens to authentication state changes
class AuthChecker extends ConsumerStatefulWidget {
  const AuthChecker({super.key});

  @override
  ConsumerState<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends ConsumerState<AuthChecker> {
  late AppLinks _appLinks;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _initDeepLinks();
    await _recoverSession();
    setState(() {
      _isInitialized = true;
    });
  }

  Future<void> _recoverSession() async {
    try {
      final supabase = ref.read(supabaseProvider);
      print('🔄 앱 시작 시 세션 복구 시도');

      // 세션 새로고침 시도
      final session = supabase.auth.currentSession;
      if (session != null) {
        print('✅ 기존 세션 발견: ${session.user.email}');
        print(
          '세션 만료 시간: ${DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)}',
        );

        // 만료되지 않은 경우만 세션 유지
        final now = DateTime.now().millisecondsSinceEpoch / 1000;
        if (session.expiresAt! > now) {
          print('✅ 세션이 유효함 - 자동 로그인 유지');
        } else {
          print('⚠️ 세션이 만료됨 - 새로고침 시도');
          await supabase.auth.refreshSession();
        }
      } else {
        print('❌ 기존 세션 없음');
      }
    } catch (e) {
      print('⚠️ 세션 복구 실패: $e');
    }
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle incoming links when app is already running
    _appLinks.uriLinkStream.listen((uri) {
      print('Deep link received: $uri');
      _handleDeepLink(uri);
    });

    // Handle incoming links when app is started from link
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      print('Initial deep link: $initialUri');
      _handleDeepLink(initialUri);
    }
  }

  void _handleDeepLink(Uri uri) async {
    print('🚨🚨🚨 NEW VERSION DEEP LINK HANDLER 실행됨!!! 🚨🚨🚨');
    print('Deep link received: $uri');

    final supabase = ref.read(supabaseProvider);
    final currentUser = supabase.auth.currentUser;
    final currentSession = supabase.auth.currentSession;

    print('현재 사용자: ${currentUser?.email}');
    print('현재 세션: ${currentSession != null ? '있음' : '없음'}');

    // 기존 유효한 세션이 있으면 즉시 화면 전환
    if (currentUser != null && currentSession != null) {
      print('✅ 기존 세션 발견 - 강제 화면 전환 시작');
      print('🚨🚨🚨 네이게이터 로직 강제 실행 시작 🚨🚨🚨');

      // 1차: 즉시 Navigator 실행
      if (mounted) {
        print('🚨 1차 시도: 즉시 Navigator 실행');
        try {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AppShell()),
            (route) => false,
          );
          print('💥 1차 Navigator 성공');
        } catch (e) {
          print('1차 Navigator 실패: $e');
        }
      }

      // 2차: SchedulerBinding으로 다음 프레임에서 Navigator 실행
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          print('� 2차 시도: SchedulerBinding으로 Navigator 실행');
          try {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AppShell()),
              (route) => false,
            );
            print('💥 2차 Navigator 성공');
          } catch (e) {
            print('2차 Navigator 실패: $e');
          }
        }
      });

      // 3차: 딜레이 후 재시도
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          print('🚨 3차 시도: 딜레이 후 Navigator 실행');
          try {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AppShell()),
              (route) => false,
            );
            print('💥 3차 Navigator 성공');
          } catch (e) {
            print('3차 Navigator 실패: $e');
          }
        }
      });

      // 4차: 더 긴 딜레이 후 최종 시도
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          print('🚨 4차 시도: 최종 Navigator 실행');
          try {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AppShell()),
              (route) => false,
            );
            print('💥 4차 Navigator 성공');
          } catch (e) {
            print('4차 Navigator 실패: $e');
          }
        }
      });

      // 추가로 세션 새로고침
      try {
        await supabase.auth.refreshSession();
        print('🔄 세션 새로고침 완료');
      } catch (e) {
        print('세션 새로고침 실패: $e');
      }

      return;
    }

    // 새 로그인 처리
    try {
      print('새 로그인 시도...');
      await supabase.auth.getSessionFromUrl(uri);
      print('✅ 새 로그인 성공');
    } catch (e) {
      print('=== Deep Link 처리 오류 ===');
      print('오류 타입: ${e.runtimeType}');
      print('오류 메시지: $e');

      // Code Verifier 오류 처리
      if (e.toString().contains('Code verifier could not be found')) {
        print('💥 Code Verifier 오류 감지 - OAuth 캐시 정리 후 재시도');

        try {
          // SharedPreferences에서 OAuth 관련 캐시 정리
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          print('✅ SharedPreferences 캐시 정리 완료');

          // Supabase 로컬 스토리지도 정리
          await supabase.auth.signOut(scope: SignOutScope.local);
          print('✅ Supabase 로컬 스토리지 정리 완료');

          // 잠시 대기 후 새로운 OAuth 시도 유도
          await Future.delayed(const Duration(milliseconds: 1000));

          print('🚨 OAuth 캐시 정리 완료 - 사용자에게 다시 로그인 요청');

          // 4중 Navigator 시도로 로그인 페이지로 이동
          // 1차: 즉시 실행
          if (mounted) {
            print('🚨 1차 시도: 즉시 로그인 페이지로 이동');
            try {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
              print('💥 1차 로그인 페이지 이동 성공');
            } catch (navError) {
              print('1차 Navigator 실패: $navError');
            }
          }

          // 2차: SchedulerBinding
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              print('🚨 2차 시도: SchedulerBinding 로그인 페이지로 이동');
              try {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
                print('💥 2차 로그인 페이지 이동 성공');
              } catch (navError) {
                print('2차 Navigator 실패: $navError');
              }
            }
          });

          // 3차: 딜레이 후
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              print('🚨 3차 시도: 딜레이 후 로그인 페이지로 이동');
              try {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
                print('💥 3차 로그인 페이지 이동 성공');
              } catch (navError) {
                print('3차 Navigator 실패: $navError');
              }
            }
          });

          print('🔄 로그인 페이지로 강제 이동 완료');
        } catch (cleanupError) {
          print('OAuth 캐시 정리 중 오류: $cleanupError');
        }
      }

      print('=== Deep Link 처리 완료 ===');
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabase = ref.watch(supabaseProvider);

    // 앱 초기화가 완료되지 않은 경우 로딩 표시
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('앱을 시작하는 중...'),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.signedIn,
        supabase.auth.currentSession,
      ),
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? supabase.auth.currentSession;
        final currentUser = supabase.auth.currentUser;

        print('🔍 StreamBuilder 상태 체크:');
        print('세션 존재: ${session != null}');
        print('사용자 존재: ${currentUser != null}');
        print('사용자 이메일: ${currentUser?.email}');
        print('연결 상태: ${snapshot.connectionState}');

        if (snapshot.connectionState == ConnectionState.waiting &&
            session == null) {
          print('⏳ 대기 중 - 로딩 화면 표시');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 기존 세션이나 사용자가 있으면 강제로 AppShell 반환
        if (session != null || currentUser != null) {
          print('🎉 StreamBuilder: 세션/사용자 발견 - AppShell 반환');
          print('세션 만료 시간: ${session?.expiresAt}');
          print('액세스 토큰 존재: ${session?.accessToken != null}');
          return const AppShell();
        } else {
          print('🚪 StreamBuilder: 세션 없음 - LoginPage 반환');
          return LoginPage();
        }
      },
    );
  }
}

// Provider to control the page index of the bottom navigation bar
final pageIndexProvider = StateProvider<int>((ref) => 0);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const List<Widget> _pages = <Widget>[
    HomePage(),
    RecipesPage(),
    NotificationsPage(),
    MyPage(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 알림 스케줄러 활성화
    ref.watch(notificationSchedulerProvider);
    final pageIndex = ref.watch(pageIndexProvider);
    final notifications = ref.watch(notificationListProvider);

    return Scaffold(
      body: IndexedStack(index: pageIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: pageIndex,
        onTap: (index) => ref.read(pageIndexProvider.notifier).state = index,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryBlue,
        unselectedItemColor: mediumGray,
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.kitchen_outlined),
            activeIcon: Icon(Icons.kitchen),
            label: '냉장고',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu_outlined),
            activeIcon: Icon(Icons.restaurant_menu),
            label: '레시피',
          ),
          BottomNavigationBarItem(
            icon: _buildNotificationIcon(notifications.length, false),
            activeIcon: _buildNotificationIcon(notifications.length, true),
            label: '알림',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '마이',
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon(int notificationCount, bool isActive) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(isActive ? Icons.notifications : Icons.notifications_outlined),
        if (notificationCount > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                notificationCount > 99 ? '99+' : notificationCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
