import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../shared/illustration.dart';

/// Shared full-screen state layout: a centered illustration with the message and
/// actions toward the bottom (matches the Figma state screens).
class AppStateView extends StatelessWidget {
  final Widget art;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool primaryFilled;
  final String? footer;

  const AppStateView({
    super.key,
    required this.art,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryFilled = true,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),
              Center(child: art),
              const Spacer(flex: 3),
              Text(title, textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: TextStyle(color: t.textMuted, height: 1.55, fontSize: 15.5)),
              const SizedBox(height: 28),
              if (primaryFilled)
                FilledButton(onPressed: onPrimary, child: Text(primaryLabel))
              else
                OutlinedButton(onPressed: onPrimary, child: Text(primaryLabel)),
              if (footer != null) ...[
                const SizedBox(height: 14),
                Text(footer!, textAlign: TextAlign.center, style: TextStyle(color: t.textMuted, fontSize: 13)),
              ],
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _circleIcon(BuildContext context, IconData icon, {Color? color}) {
  final t = context.tokens;
  return Container(
    width: 180,
    height: 180,
    decoration: BoxDecoration(color: t.primarySoft.withValues(alpha: 0.5), shape: BoxShape.circle),
    child: Icon(icon, size: 76, color: color ?? Theme.of(context).colorScheme.primary),
  );
}

class DailyLimitScreen extends StatelessWidget {
  const DailyLimitScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return AppStateView(
      art: const Illustration('state_break', size: 180),
      title: 'Time for a break',
      message: "You have reached today's question limit. Great effort today.\n\nYour limit resets at midnight.",
      primaryLabel: 'Go home',
      primaryFilled: false,
      onPrimary: () => context.go('/home'),
      footer: 'Need more? Upgrade to Lactic Plus for higher limits.',
    );
  }
}

class AtCapacityScreen extends StatelessWidget {
  const AtCapacityScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return AppStateView(
      art: _circleIcon(context, Icons.hourglass_empty_rounded, color: context.tokens.warning),
      title: "We're at capacity",
      message: 'A lot of students are studying right now. Please try again in a few minutes.',
      primaryLabel: 'Try again',
      onPrimary: () => context.go('/home'),
    );
  }
}

class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return AppStateView(
      art: const Illustration('offline', size: 200),
      title: 'You are offline',
      message: 'Lactic needs an internet connection to tutor you. Check your connection and try again.',
      primaryLabel: 'Retry',
      onPrimary: () => context.go('/home'),
    );
  }
}

/// Skeleton placeholder shown while the first screen loads.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: t.surfaceMuted, borderRadius: BorderRadius.circular(14)),
        );
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(180, 22),
              bar(double.infinity, 16),
              bar(260, 16),
              bar(200, 16),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 150,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: t.surfaceMuted, borderRadius: BorderRadius.circular(FF.rCard)),
              ),
              bar(double.infinity, 16),
              bar(240, 16),
            ],
          ),
        ),
      ),
    );
  }
}
