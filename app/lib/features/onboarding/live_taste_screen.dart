import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';

/// Onboarding "aha": tap a tailored question and get a REAL streamed, cited
/// answer from the live backend, before any sign-up.
class LiveTasteScreen extends ConsumerStatefulWidget {
  const LiveTasteScreen({super.key});
  @override
  ConsumerState<LiveTasteScreen> createState() => _LiveTasteScreenState();
}

const _bySubject = {
  'Chemistry': [
    'Explain Le Chatelier\'s principle',
    'Why is phenol more acidic than ethanol?',
    'Walk me through a buffer calculation',
  ],
  'Physics': [
    'Explain Newton\'s second law',
    'Why does a projectile follow a parabola?',
    'What is simple harmonic motion?',
  ],
  'Mathematics': [
    'Explain the chain rule simply',
    'How do I integrate by parts?',
    'What is a complex number?',
  ],
  'Economics': [
    'Explain supply and demand simply',
    'What causes market failure?',
    'What is price elasticity of demand?',
  ],
  'Biology': [
    'How does natural selection work?',
    'Explain DNA replication',
    'Why is osmosis important to cells?',
  ],
};
const _generic = [
  'Explain a concept I find tricky',
  'How do I structure an essay answer?',
  'Give me a quick worked example',
];

class _LiveTasteScreenState extends ConsumerState<LiveTasteScreen> {
  String _answer = '';
  List<Citation> _citations = [];
  bool _loading = false;
  String? _asked;

  List<String> _questions() {
    final md = ref.read(memoryStoreProvider).markdown;
    for (final s in _bySubject.keys) {
      if (md.contains(s)) return _bySubject[s]!;
    }
    return _generic;
  }

  Future<void> _ask(String q) async {
    setState(() {
      _asked = q;
      _answer = '';
      _citations = [];
      _loading = true;
    });
    try {
      final stream = ref.read(chatServiceProvider).stream(
            message: q,
            memoryMd: ref.read(memoryStoreProvider).markdown,
            answerStyle: 'direct',
            deviceId: ref.read(deviceIdProvider),
          );
      await for (final ev in stream) {
        if (!mounted) return;
        switch (ev) {
          case TokenEvent(:final text):
            setState(() => _answer += text);
          case CitationsEvent(:final citations):
            setState(() => _citations = citations);
          default:
            break;
        }
      }
    } catch (_) {
      if (mounted) setState(() => _answer = 'Could not reach the tutor right now. Try again in a moment.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final questions = _questions();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 3 of 3'),
        actions: [TextButton(onPressed: () => context.go('/trust'), child: const Text('Skip'))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          children: [
            Text('See how I teach', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('Tap a question, I\'ll answer it for real.', style: TextStyle(color: t.textMuted)),
            const SizedBox(height: 16),
            ...questions.map((q) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _loading ? null : () => _ask(q),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: _asked == q ? t.primarySoft : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _asked == q ? theme.colorScheme.primary : t.border),
                      ),
                      child: Row(children: [
                        Expanded(
                            child: Text(q,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _asked == q ? t.onPrimarySoft : null))),
                        Icon(Icons.chevron_right_rounded, color: t.textMuted),
                      ]),
                    ),
                  ),
                )),
            if (_asked != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(FF.rCard),
                  border: Border.all(color: t.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_answer.isEmpty && _loading)
                      Row(children: [
                        SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: t.textMuted)),
                        const SizedBox(width: 10),
                        Text('Thinking…', style: TextStyle(color: t.textMuted)),
                      ])
                    else
                      MarkdownBody(data: _answer, styleSheet: MarkdownStyleSheet.fromTheme(theme)),
                    if (_citations.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _citations
                            .take(3)
                            .map((c) => Chip(
                                  label: Text('#${c.n} ${c.ref}'),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  labelStyle: TextStyle(fontSize: 12, color: t.onPrimarySoft),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Icon(Icons.verified_user_outlined, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Every answer cites real notes, and tells you when it\'s unsure.',
                      style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.4))),
            ]),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => context.go('/trust'), child: const Text('Continue')),
          ],
        ),
      ),
    );
  }
}
