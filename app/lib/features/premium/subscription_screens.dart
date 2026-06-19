import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../state/app_state.dart';
import '../shared/illustration.dart';

/// Subscribed-state design (matches the Figma). Renewal data is placeholder
/// until in-app purchases are wired; this screen reads real billing data then.
class ManageSubscriptionScreen extends ConsumerWidget {
  const ManageSubscriptionScreen({super.key});

  static const _renewDate = '17 Jul 2026';
  static const _price = 'S\$12.90';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CURRENT PLAN',
                      style: TextStyle(color: t.onPrimarySoft, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Text('Lactic Plus', style: theme.textTheme.titleLarge?.copyWith(color: scheme.primary)),
                  const SizedBox(height: 4),
                  Text('Renews $_renewDate at $_price', style: TextStyle(color: t.onPrimarySoft.withValues(alpha: 0.85))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.border),
              ),
              child: Column(children: [
                const _DetailRow('Plan', 'Lactic Plus · Monthly'),
                _Divider(t),
                const _DetailRow('Amount', '$_price / month'),
                _Divider(t),
                const _DetailRow('Next renewal', _renewDate),
              ]),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => ref.read(purchasesServiceProvider).presentCustomerCenter(),
              child: const Text('Manage subscription'),
            ),
            const SizedBox(height: 14),
            Text('Manage opens the RevenueCat Customer Center: change plan, cancel, '
                'or restore. Cancelling stops auto-renewal; you keep access until $_renewDate.',
                textAlign: TextAlign.center, style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
          Text(value, style: TextStyle(color: t.textMuted, fontSize: 15.5)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final AppTokens t;
  const _Divider(this.t);
  @override
  Widget build(BuildContext context) => Divider(height: 1, color: t.border);
}

class SubscriptionSuccessScreen extends StatelessWidget {
  const SubscriptionSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              const Spacer(flex: 3),
              const Illustration('success', size: 200),
              const Spacer(flex: 1),
              Text('Welcome to Lactic Plus!', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text('You now have access to Marks Coach, Mastery Tracking, Weak-Spot Drilling, and Photo Upload. Good luck with your A-Levels.',
                  textAlign: TextAlign.center, style: TextStyle(color: t.textMuted, height: 1.55)),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: () => context.go('/home'), child: const Text('Start studying')),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
