import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';

class ManageSubscriptionScreen extends StatelessWidget {
  const ManageSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: t.surfaceMuted, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Icon(Icons.person_outline_rounded, color: t.onPrimarySoft),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current plan', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text('Free', style: TextStyle(color: t.textMuted)),
                  ],
                ),
              ]),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => context.push('/premium'), child: const Text('Upgrade to Premium')),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Manage billing in your app store settings.'))),
              child: const Text('Manage in app store'),
            ),
          ],
        ),
      ),
    );
  }
}

class SubscriptionSuccessScreen extends StatelessWidget {
  const SubscriptionSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: t.success, size: 64),
              const SizedBox(height: 16),
              Text("You're Premium", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Answer Feedback, weak-spot drilling, and mastery tracking are unlocked.',
                  textAlign: TextAlign.center, style: TextStyle(color: t.textMuted, height: 1.5)),
              const Spacer(),
              FilledButton(onPressed: () => context.go('/home'), child: const Text('Start studying')),
            ],
          ),
        ),
      ),
    );
  }
}
