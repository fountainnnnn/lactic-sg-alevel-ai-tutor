import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/home/home_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/history/history_screen.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/onboarding/subjects_screen.dart';
import 'features/onboarding/live_taste_screen.dart';
import 'features/onboarding/trust_screen.dart';
import 'features/premium/premium_screen.dart';
import 'features/premium/subscription_screens.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/edit_profile_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/info_screens.dart';
import 'features/shell/home_shell.dart';
import 'state/app_state.dart';

class JcaiApp extends ConsumerWidget {
  const JcaiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(_routerProvider);
    return MaterialApp.router(
      title: 'JCAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      routerConfig: router,
    );
  }
}

final _shellKey = GlobalKey<NavigatorState>();

final _routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final done = ref.read(onboardingDoneProvider);
      const onboardingPaths = {'/welcome', '/subjects', '/live_taste', '/trust'};
      final onboarding = onboardingPaths.contains(state.matchedLocation);
      if (!done && !onboarding) return '/welcome';
      if (done && onboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/subjects', builder: (_, __) => const SubjectsScreen()),
      GoRoute(path: '/live_taste', builder: (_, __) => const LiveTasteScreen()),
      GoRoute(path: '/trust', builder: (_, __) => const TrustScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/signin', builder: (_, __) => const SignInScreen()),
      GoRoute(path: '/premium', builder: (_, __) => const PremiumScreen()),
      GoRoute(path: '/subscription', builder: (_, __) => const ManageSubscriptionScreen()),
      GoRoute(path: '/subscription/success', builder: (_, __) => const SubscriptionSuccessScreen()),
      GoRoute(path: '/edit-profile', builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationSettingsScreen()),
      GoRoute(path: '/help', builder: (_, __) => const HelpFaqScreen()),
      GoRoute(path: '/privacy', builder: (_, __) => const LegalScreen(title: 'Privacy Policy', body: privacyBody)),
      GoRoute(path: '/terms', builder: (_, __) => const LegalScreen(title: 'Terms & Conditions', body: termsBody)),
      GoRoute(path: '/about', builder: (_, __) => const LegalScreen(title: 'About JCAI', body: aboutBody)),
      GoRoute(path: '/delete-account', builder: (_, __) => const DeleteAccountScreen()),
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
