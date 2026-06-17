import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../state/app_state.dart';
import '../shared/illustration.dart';

class TrustScreen extends ConsumerWidget {
  const TrustScreen({super.key});

  static const _points = [
    (Icons.menu_book_rounded, 'Grounded in real material', 'Answers cite Singapore prelims and the SEAB syllabus.'),
    (Icons.balance_rounded, 'Honest, not a know-it-all', 'It flags when it is unsure instead of bluffing.'),
    (Icons.lock_outline_rounded, 'Private and secure', 'Used only to tutor you, never sold.'),
    (Icons.favorite_border_rounded, 'Free to use', 'Ask as much as you need.'),
  ];

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    await ref.read(prefsProvider).setBool('onboarding_done', true);
    ref.read(onboardingDoneProvider.notifier).state = true;
    if (context.mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              const Illustration('trust', size: 180),
              const SizedBox(height: 18),
              Text('Your study partner', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('Built for A-Level rigor, focused on what matters most.',
                  textAlign: TextAlign.center, style: TextStyle(color: t.textMuted, height: 1.5)),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: _points
                      .map((p) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: t.border),
                            ),
                            child: Row(children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration:
                                    BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(11)),
                                child: Icon(p.$1, size: 21, color: t.onPrimarySoft),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(p.$3, style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.35)),
                                  ],
                                ),
                              ),
                            ]),
                          ))
                      .toList(),
                ),
              ),
              FilledButton(onPressed: () => _finish(context, ref), child: const Text('Get started')),
            ],
          ),
        ),
      ),
    );
  }
}
