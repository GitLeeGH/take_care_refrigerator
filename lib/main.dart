import 'src/app_variant.dart';
import 'src/widgets/original_video_panel.dart';
import 'src/widgets/app_bootstrap.dart';
import 'src/widgets/app_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'dart:io';

import 'src/theme.dart';
import 'src/providers.dart';
import 'src/pages/home_page.dart';
import 'src/pages/recipes_page.dart';
import 'src/pages/notifications_page.dart';
import 'src/pages/my_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/pages/onboarding_page.dart';
import 'src/pages/login_page.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'src/services/notification_service.dart';

// 백그라운드에서 실행될 알림 콜백 (최상위 함수여야 함)
@pragma('vm:entry-point')
void alarmCallback() async {
  final notificationService = NotificationService();
  await notificationService.init();

  // 오늘 날짜 확인
  final now = DateTime.now();
  final prefs = await SharedPreferences.getInstance();
  final todayString =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final lastAlarmDate = prefs.getString('last_alarm_date');

  // 오늘 이미 알림을 보냈으면 스킵
  if (lastAlarmDate == todayString) {
    return;
  }

  // 즉시 알림 표시 (간단한 예시)
  await notificationService.showImmediateExpiryAlert('테스트 재료', 1);
  await prefs.setString('last_alarm_date', todayString);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    AppBootstrap(
      initialize: _initializeApp,
      ready: (hasSeenOnboarding) =>
          ProviderScope(child: MyApp(hasSeenOnboarding: hasSeenOnboarding)),
    ),
  );
}

Future<bool> _initializeApp() async {
  // Initialize AndroidAlarmManager
  if (!kIsWeb && Platform.isAndroid) {
    await AndroidAlarmManager.initialize();
  }

  // Initialize Notification Service
  final notificationService = NotificationService();
  if (!kIsWeb)
    await notificationService.init(requestPermissions: !isDevelopmentApp);

  // Initialize Kakao SDK
  if (!isDevelopmentApp) {
    KakaoSdk.init(nativeAppKey: 'CONFIGURE_PUBLIC_KAKAO_APP_ID');
  }

  // Print Key Hash for Kakao (Android only)
  try {
    if (!kIsWeb && Platform.isAndroid) {
      // 실제 키 해시는 카카오 에러 메시지에서 확인할 수 있습니다.
    }
  } catch (e) {}

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

  return hasSeenOnboarding;
}

class MyApp extends StatelessWidget {
  final bool hasSeenOnboarding;
  const MyApp({super.key, required this.hasSeenOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [videoRouteObserver],
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

      // 세션 새로고침 시도
      final session = supabase.auth.currentSession;
      if (session != null) {
        // 만료되지 않은 경우만 세션 유지
        final now = DateTime.now().millisecondsSinceEpoch / 1000;
        if (session.expiresAt! > now) {
        } else {
          await supabase.auth.refreshSession();
        }
      } else {}
    } catch (e) {}
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle incoming links when app is already running
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });

    // Handle incoming links when app is started from link
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _handleDeepLink(initialUri);
    }
  }

  void _handleDeepLink(Uri uri) async {
    final supabase = ref.read(supabaseProvider);
    final currentUser = supabase.auth.currentUser;
    final currentSession = supabase.auth.currentSession;

    // 기존 유효한 세션이 있으면 즉시 화면 전환
    if (currentUser != null && currentSession != null) {
      // 1차: 즉시 Navigator 실행
      if (mounted) {
        try {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AppShell()),
            (route) => false,
          );
        } catch (e) {}
      }

      // 2차: SchedulerBinding으로 다음 프레임에서 Navigator 실행
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AppShell()),
              (route) => false,
            );
          } catch (e) {}
        }
      });

      // 3차: 딜레이 후 재시도
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          try {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AppShell()),
              (route) => false,
            );
          } catch (e) {}
        }
      });

      // 4차: 더 긴 딜레이 후 최종 시도
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          try {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AppShell()),
              (route) => false,
            );
          } catch (e) {}
        }
      });

      // 추가로 세션 새로고침
      try {
        await supabase.auth.refreshSession();
      } catch (e) {}

      return;
    }

    // 새 로그인 처리
    try {
      await supabase.auth.getSessionFromUrl(uri);
    } catch (e) {
      // Code Verifier 오류 처리
      if (e.toString().contains('Code verifier could not be found')) {
        try {
          // SharedPreferences에서 OAuth 관련 캐시 정리
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();

          // Supabase 로컬 스토리지도 정리
          await supabase.auth.signOut(scope: SignOutScope.local);

          // 잠시 대기 후 새로운 OAuth 시도 유도
          await Future.delayed(const Duration(milliseconds: 1000));

          // 4중 Navigator 시도로 로그인 페이지로 이동
          // 1차: 즉시 실행
          if (mounted) {
            try {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            } catch (navError) {}
          }

          // 2차: SchedulerBinding
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              try {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              } catch (navError) {}
            }
          });

          // 3차: 딜레이 후
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              try {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              } catch (navError) {}
            }
          });
        } catch (cleanupError) {}
      }
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

        if (snapshot.connectionState == ConnectionState.waiting &&
            session == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 기존 세션이나 사용자가 있으면 강제로 AppShell 반환
        if (session != null || currentUser != null) {
          return const AppShell();
        } else {
          return LoginPage();
        }
      },
    );
  }
}

// Provider to control the page index of the bottom navigation bar
class PageIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void update(int index) => state = index;
}

final pageIndexProvider = NotifierProvider<PageIndexNotifier, int>(
  PageIndexNotifier.new,
);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 알림 스케줄러 활성화
    ref.watch(notificationSchedulerProvider);
    final pageIndex = ref.watch(pageIndexProvider);
    final pages = <Widget>[
      DashboardPage(
        onInventory: () => ref.read(pageIndexProvider.notifier).update(1),
        onRecipes: () => ref.read(pageIndexProvider.notifier).update(2),
        onNotifications: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NotificationsPage())),
      ),
      const HomePage(),
      const RecipesPage(),
      const MyPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: pageIndex, children: pages),
      bottomNavigationBar: AppNavigation(
        index: pageIndex,
        onSelected: (index) =>
            ref.read(pageIndexProvider.notifier).update(index),
      ),
    );
  }
}
