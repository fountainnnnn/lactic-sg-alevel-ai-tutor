import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../state/app_state.dart';
import '../shared/illustration.dart';

class TrustStep extends ConsumerWidget {
  const TrustStep({super.key});

  // (icon, color-role, title, description). Figma used emoji here; we use
  // rounded icons instead (emoji-as-icons are banned in the design system).
  static const _points = [
    (Icons.menu_book_rounded, 0, 'Grounded in real content',
        'Answers reference real Singapore A-Level study material and the SEAB syllabus, not generic internet content.'),
    (Icons.track_changes_rounded, 1, 'Exam-focused guidance',
        'Structured mark-scheme answers and exam insights tailored to what SEAB assessors reward.'),
    (Icons.lock_rounded, 2, 'Private and secure',
        'Your conversations are used only to tutor you, never sold or shared. Account deletion is available at any time.'),
  ];

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    await ref.read(prefsProvider).setBool('onboarding_done', true);
    ref.read(onboardingDoneProvider.notifier).state = true;
    if (context.mounted) context.go('/signin');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final theme = Theme.of(context);
    Color roleColor(int r) => switch (r) {
          1 => t.danger,
          2 => t.warning,
          _ => theme.colorScheme.primary,
        };

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Built for A-Level prep', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text('What makes Lactic different from a generic chatbot.',
                  style: TextStyle(color: t.textMuted, height: 1.5)),
              const SizedBox(height: 16),
              const Center(child: Illustration('trust', size: 180)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: _points
                      .map((p) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: t.border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(p.$1, size: 24, color: roleColor(p.$2)),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.$3, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Text(p.$4, style: TextStyle(color: t.textMuted, fontSize: 13.5, height: 1.45)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _finish(context, ref),
              child: const Text('Create my account'),
            ),
          ),
        ],
      ),
    );
  }
}
