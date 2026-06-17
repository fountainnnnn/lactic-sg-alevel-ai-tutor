import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('JCAI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(_greeting(), style: theme.textTheme.displaySmall),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => context.go('/chat'),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(FF.rCard),
                ),
                child: Row(children: [
                  Icon(Icons.chat_bubble_outline_rounded, color: scheme.onPrimary, size: 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ask anything',
                            style: TextStyle(
                                color: scheme.onPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
                        const SizedBox(height: 2),
                        Text('Explain a concept, mark your work, or find a question.',
                            style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.85), fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: scheme.onPrimary),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            Text('How I can help', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            _HelpRow(icon: Icons.school_outlined, title: 'Explain a concept', subtitle: 'Clear, grounded, with sources', t: t),
            _HelpRow(icon: Icons.checklist_rounded, title: 'Mark my working', subtitle: 'Exam-style feedback', t: t),
            _HelpRow(icon: Icons.search_rounded, title: 'Find a question', subtitle: 'Real prelim practice', t: t),
          ],
        ),
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final AppTokens t;
  const _HelpRow({required this.icon, required this.title, required this.subtitle, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: t.onPrimarySoft),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(subtitle, style: TextStyle(color: t.textMuted, fontSize: 12.5)),
          ],
        ),
      ]),
    );
  }
}
