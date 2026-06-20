import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../state/app_state.dart';
import '../shared/illustration.dart';
import 'plans.dart';

/// Subscribed-state design (matches the Figma). Renewal data is placeholder
/// until in-app purchases are wired; this screen reads real billing data then.
class ManageSubscriptionScreen extends ConsumerWidget {
  const ManageSubscriptionScreen({super.key});

  static const _renewDate = '17 Jul 2026'; // placeholder until real store billing data is wired

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Tier name + price reflect the actual active subscription; renewal date is
    // still a placeholder until real store billing data is read from RevenueCat.
    final rank = ref.watch(tierRankProvider);
    final tier = switch (rank) {
      3 => Subscriptions.max,
      2 => Subscriptions.plus,
      1 => Subscriptions.lite,
      _ => null,
    };
    // Free users have no subscription — show a plan card + upgrade CTA, never a
    // bogus renewal date / amount. Paid users see real billing details.
    final planCard = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CURRENT PLAN',
              style: TextStyle(color: t.onPrimarySoft, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Text(tier?.name ?? 'Lactic Free', style: theme.textTheme.titleLarge?.copyWith(color: scheme.primary)),
          const SizedBox(height: 4),
          Text(
            tier == null ? "You're on the free plan, no billing." : 'Renews $_renewDate at ${tier.monthly.price}',
            style: TextStyle(color: t.onPrimarySoft.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: tier == null
              ? [
                  planCard,
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.push('/premium'),
                    child: const Text('See plans'),
                  ),
                  const SizedBox(height: 14),
                  Text('Upgrade any time for more daily questions, the Reasoning model, photo solve, and more.',
                      textAlign: TextAlign.center, style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.5)),
                ]
              : [
                  planCard,
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: t.border),
                    ),
                    child: Column(children: [
                      _DetailRow('Plan', '${tier.name} · Monthly'),
                      _Divider(t),
                      _DetailRow('Amount', '${tier.monthly.price} / month'),
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

class SubscriptionSuccessScreen extends ConsumerWidget {
  const SubscriptionSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final theme = Theme.of(context);
    // Tailor the welcome to the tier actually purchased, so we never promise a
    // higher tier's feature (e.g. Weak-Spot Drilling is Max-only).
    final rank = ref.watch(tierRankProvider);
    final tierName = switch (rank) {
      3 => 'Lactic Max',
      2 => 'Lactic Plus',
      1 => 'Lactic Lite',
      _ => 'Lactic',
    };
    final perks = switch (rank) {
      3 => 'You now have the Reasoning model for math, Marks Coach, Mastery Tracking, Weak-Spot Drilling, Photo Upload, and the most daily questions.',
      2 => 'You now have the Reasoning model for math, Marks Coach, Mastery Tracking, and Photo Upload.',
      1 => 'You now have a higher daily question limit to keep studying.',
      _ => 'Your upgrade is ready.',
    };
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              const Spacer(flex: 3),
              const Illustration('success', size: 200),
              const Spacer(flex: 1),
              Text('Welcome to $tierName!', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text('$perks Good luck with your A-Levels.',
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
