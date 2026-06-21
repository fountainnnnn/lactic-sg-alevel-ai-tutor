import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/home/home_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/history/history_screen.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/onboarding/splash_screen.dart';
import 'features/premium/premium_screen.dart';
import 'features/premium/subscription_screens.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/edit_profile_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/info_screens.dart';
import 'features/states/state_screens.dart';
import 'features/shell/home_shell.dart';
import 'state/app_state.dart';

class LacticApp extends ConsumerWidget {
  const LacticApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(_routerProvider);
    return MaterialApp.router(
      title: 'Lactic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      routerConfig: router,
      // Intercept Android back so it returns to the Home tab from a secondary
      // tab instead of exiting the app. Built inside the router's builder so its
      // observer registers after go_router's and is therefore called first.
      builder: (context, child) => _BackInterceptor(router: router, child: child!),
    );
  }
}

/// Returns to the Home tab when Android back is pressed on a secondary tab,
/// rather than letting the app exit. Pushed routes (e.g. /settings) and the Home
/// tab fall through to go_router's normal handling (pop / exit).
class _BackInterceptor extends StatefulWidget {
  final GoRouter router;
  final Widget child;
  const _BackInterceptor({required this.router, required this.child});

  @override
  State<_BackInterceptor> createState() => _BackInterceptorState();
}

class _BackInterceptorState extends State<_BackInterceptor> with WidgetsBindingObserver {
  static const _tabRoots = {'/chat', '/history', '/profile'};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    // A pushed route (e.g. /settings) is on top — let go_router pop it normally.
    if (widget.router.canPop()) return false;
    // At a tab root: a secondary tab returns to Home; Home falls through to exit.
    final location = widget.router.routerDelegate.currentConfiguration.uri.path;
    if (_tabRoots.contains(location)) {
      widget.router.go('/home');
      return true; // handled — don't exit the app
    }
    return false; // Home root — let the app exit
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Horizontal slide for the onboarding flow: each step swipes in from the right
/// and slides back out on back navigation.
Page<dynamic> _slide(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Incoming page slides in from the right; the page it covers slides out
        // to the left — a true swipe, not an overlay.
        final incoming = Tween(begin: const Offset(1, 0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic));
        final outgoing = Tween(begin: Offset.zero, end: const Offset(-1, 0))
            .chain(CurveTween(curve: Curves.easeInCubic));
        return SlideTransition(
          position: animation.drive(incoming),
          child: SlideTransition(
            position: secondaryAnimation.drive(outgoing),
            child: child,
          ),
        );
      },
    );

final _shellKey = GlobalKey<NavigatorState>();

final _routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      if (state.matchedLocation == '/splash') return null; // branded loading screen
      final done = ref.read(onboardingDoneProvider);
      const onboardingPaths = {'/welcome', '/onboarding'};
      final onboarding = onboardingPaths.contains(state.matchedLocation);
      // Sign-in is reachable before onboarding is done ("I already have an
      // account" on the welcome screen) — don't bounce it back to /welcome.
      final preAuth = onboarding || state.matchedLocation == '/signin';
      if (!done && !preAuth) return '/welcome';
      if (done && onboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/welcome', pageBuilder: (_, s) => _slide(s, const WelcomeScreen())),
      GoRoute(path: '/onboarding', pageBuilder: (_, s) => _slide(s, const OnboardingFlow())),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/signin', builder: (_, __) => const SignInScreen()),
      GoRoute(path: '/premium', builder: (_, __) => const PremiumScreen()),
      GoRoute(path: '/subscription', builder: (_, __) => const ManageSubscriptionScreen()),
      GoRoute(path: '/subscription/success', builder: (_, __) => const SubscriptionSuccessScreen()),
      GoRoute(path: '/edit-profile', builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationSettingsScreen()),
      GoRoute(path: '/help', builder: (_, __) => const HelpFaqScreen()),
      GoRoute(path: '/privacy', builder: (_, __) => const LegalScreen(title: 'Privacy policy', body: privacyBody)),
      GoRoute(path: '/terms', builder: (_, __) => const LegalScreen(title: 'Terms & conditions', body: termsBody)),
      GoRoute(path: '/about', builder: (_, __) => const LegalScreen(title: 'About Lactic', body: aboutBody)),
      GoRoute(path: '/delete-account', builder: (_, __) => const DeleteAccountScreen()),
      GoRoute(path: '/state/daily-limit', builder: (_, __) => const DailyLimitScreen()),
      GoRoute(path: '/state/at-capacity', builder: (_, __) => const AtCapacityScreen()),
      GoRoute(path: '/state/offline', builder: (_, __) => const OfflineScreen()),
      GoRoute(path: '/state/loading', builder: (_, __) => const LoadingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(navigatorKey: _shellKey, routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),
    ],
  );
});
