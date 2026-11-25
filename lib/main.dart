import 'src/services/notification_preferences.dart';
import 'src/services/local_expiry_reminders.dart';
import 'src/local_expiry_provider.dart';
import 'src/widgets/test_notification_card.dart';
import 'src/services/background_expiry_worker.dart';
import 'src/services/one_shot_expiry_reminder.dart';
import 'src/app_variant.dart';
import 'src/widgets/original_video_panel.dart';
import 'src/widgets/app_bootstrap.dart';
import 'src/widgets/app_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'src/services/auth_gateway.dart';
import 'src/widgets/auth_session_gate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
Future<void> verifiedExpiryWorkEntrypoint() => runVerifiedExpiryWork();

@pragma('vm:entry-point')
void alarmCallback() {
  /* Legacy entry point: delivery disabled. */
}

NotificationPreferencesStore? _notificationPreferencesStore;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    AppBootstrap(
      initialize: _initializeApp,
      ready: (hasSeenOnboarding) => ProviderScope(
        overrides: [
          notificationPreferencesStoreProvider.overrideWithValue(
            _notificationPreferencesStore,
          ),
        ],
        child: MyApp(hasSeenOnboarding: hasSeenOnboarding),
      ),
    ),
  );
}

Future<bool> _initializeApp() async {
  // Cleanup is best-effort; a slow platform response must not block app startup.
  OneShotExpiryReminder.instance.prepareStartup();
  explicitTestReminder.cancel();
  NotificationService().cancelLegacyNotifications();

  // Initialize Kakao SDK
  if (!isDevelopmentApp) {
    KakaoSdk.init(nativeAppKey: '5f221c04f30c10b07c1f376aedf67b61');
  }

  // Print Key Hash for Kakao (Android only)
  try {
    if (!kIsWeb && Platform.isAndroid) {
      // 실제 키 해시는 카카오 에러 메시지에서 확인할 수 있습니다.
    }
  } catch (e) {}

  final prefs = await SharedPreferences.getInstance();
  _notificationPreferencesStore = NotificationPreferencesStore(
    SharedNotificationPreferencesStorage(prefs),
  );
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
      title: '냉장고를 부탁해',
      debugShowCheckedModeBanner: false,
      theme: appTheme, // Use the theme from theme.dart
      home: hasSeenOnboarding ? const AuthChecker() : const OnboardingPage(),
    );
  }
}

// Correctly listens to authentication state changes
class AuthChecker extends ConsumerWidget {
  const AuthChecker({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesStore = ref.watch(notificationPreferencesStoreProvider);
    final gateway = ref.watch(authGatewayProvider);
    final client = ref.watch(supabaseProvider);
    return AuthSessionGate(
      gateway: gateway,
      onStartupBoundary:
          () {}, // Startup receipt reconciliation is handled separately.
      onAccountBoundary: () {
        invalidateLocalExpiryReminders().catchError((Object _) {});
      },
      onSessionBoundary: () {
        ref.read(notificationCleanupProvider)();
      },
      signedOut: (_) => const LoginPage(),
      signedIn: (id) => AccountSessionScope(
        key: ValueKey(id),
        createContainer: () => ProviderContainer(
          overrides: [
            notificationPreferencesStoreProvider.overrideWithValue(
              preferencesStore,
            ),
            notificationPreferencesAccountProvider.overrideWithValue(id),
            supabaseProvider.overrideWithValue(client),
            authGatewayProvider.overrideWithValue(gateway),
          ],
        ),
        observers: [videoRouteObserver],
        child: const AppShell(),
      ),
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
    ref.watch(localExpirySyncProvider);
    final pageIndex = ref.watch(pageIndexProvider);
    final pages = <Widget>[
      DashboardPage(
        active: pageIndex == 0,
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
