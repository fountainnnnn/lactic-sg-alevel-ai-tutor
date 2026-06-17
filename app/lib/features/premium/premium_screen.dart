import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  static const _features = [
    (Icons.fact_check_outlined, 'Answer Feedback', 'Your work checked against real mark schemes.'),
    (Icons.track_changes_rounded, 'Weak-spot drilling', 'Targeted prelim questions tailored to you.'),
    (Icons.insights_rounded, 'Mastery tracking', 'See your progress across every subject.'),
    (Icons.photo_camera_outlined, 'Photo uploads', 'Snap a question for instant help.'),
    (Icons.bolt_rounded, 'Unlimited, faster', 'No daily limits, priority answers.'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(18)),
                child: Icon(Icons.workspace_premium_rounded, size: 34, color: t.onPrimarySoft),
              ),
            ),
            const SizedBox(height: 16),
            Text('Unlock Premium', textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('Go beyond answers, get exam-ready with targeted feedback.',
                textAlign: TextAlign.center, style: TextStyle(color: t.textMuted, height: 1.5)),
            const SizedBox(height: 18),
            Center(
              child: RichText(
                text: TextSpan(style: theme.textTheme.bodyLarge, children: [
                  TextSpan(text: 'S\$8.90', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 30, color: theme.colorScheme.primary)),
                  TextSpan(text: ' / month', style: TextStyle(color: t.textMuted)),
                ]),
              ),
            ),
            const SizedBox(height: 22),
            ..._features.map((f) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: t.surfaceMuted, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Icon(f.$1, color: t.onPrimarySoft),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(f.$3, style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.35)),
                        ],
                      ),
                    ),
                  ]),
                )),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('In-app purchases are coming soon.'))),
              child: const Text('Go Premium'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Maybe later')),
            const SizedBox(height: 14),
            Center(
              child: Text('Recurring billing. Cancel anytime in your app store settings.',
                  textAlign: TextAlign.center, style: TextStyle(color: t.textMuted, fontSize: 11.5)),
            ),
          ],
        ),
      ),
    );
  }
}
