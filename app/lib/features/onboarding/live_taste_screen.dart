import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../chat/streaming_text.dart';

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
    final scheme = theme.colorScheme;
    final questions = _questions();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/subjects'),
        ),
        title: const Text('Step 3 of 3'),
        actions: [TextButton(onPressed: () => context.go('/trust'), child: const Text('Skip'))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          children: [
            Text('See how I teach', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text('Tap a question — I’ll answer it for real.', style: TextStyle(color: t.textMuted)),
            const SizedBox(height: 18),
            ...questions.map((q) {
              final on = _asked == q;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _loading ? null : () => _ask(q),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: t.primarySoft.withValues(alpha: on ? 1 : 0.55),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: on ? scheme.primary : Colors.transparent),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Text(q,
                            style: TextStyle(fontWeight: FontWeight.w600, color: t.onPrimarySoft)),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: t.onPrimarySoft),
                    ]),
                  ),
                ),
              );
            }),
            if (_asked != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(FF.rCard),
                  border: Border.all(color: t.border),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.auto_awesome_rounded, size: 15, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text('JCAI',
                          style: TextStyle(
                              color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: 0.2)),
                    ]),
                    const SizedBox(height: 8),
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
                      StreamingText(text: _answer, done: !_loading),
                    if (_citations.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 14, bottom: 12),
                        child: Divider(height: 1, color: t.border),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _citations
                            .map((c) => Tooltip(
                                  message: c.ref,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: t.primarySoft,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: t.border),
                                    ),
                                    child: Text('#${c.n}',
                                        style: TextStyle(
                                            fontSize: 12, fontWeight: FontWeight.w700, color: t.onPrimarySoft)),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.verified_user_outlined, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Every answer cites real notes — and tells you when it’s unsure.',
                      style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.4))),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => context.go('/trust'), child: const Text('Continue')),
            ),
          ],
        ),
      ),
    );
  }
}
