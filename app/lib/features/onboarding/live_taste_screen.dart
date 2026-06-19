import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../chat/chat_bubble.dart';
import '../shared/illustration.dart';
import 'demo_qa.dart';

/// Onboarding "See how it works": a no-cost demo of the real chat UI. The
/// student taps one of a few preset questions (matched to their subjects) and
/// sees a pre-canned answer — no backend call, no typing (demo only). A short
/// delay + typing dots make it feel like it's generating. Rendered as a step
/// body inside [OnboardingFlow]; the progress bar lives in the flow shell.
class LiveTasteStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  const LiveTasteStep({super.key, required this.onNext});
  @override
  ConsumerState<LiveTasteStep> createState() => _LiveTasteStepState();
}

class _LiveTasteStepState extends ConsumerState<LiveTasteStep> {
  (String, String, String)? _picked;
  bool _thinking = false;

  List<(String, String, String)> _demos() {
    // Match the student's onboarding picks (tags like "H2 Chemistry") to a
    // subject's demo set. Provider holds the live picks even for anonymous users,
    // whose memory stays empty. Prefer the first pick so the demo feels chosen
    // for them; fall back to generic only when nothing matches.
    final picks = ref.watch(onboardingSubjectsProvider);
    for (final tag in picks) {
      for (final e in demoQA.entries) {
        if (e.key != '_generic' && tag.contains(e.key)) return e.value;
      }
    }
    return demoQA['_generic']!;
  }

  void _pick((String, String, String) d) {
    setState(() {
      _picked = d;
      _thinking = true;
    });
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted && _picked == d) setState(() => _thinking = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final demos = _demos();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('See how it works', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text('Tap a question for a sample answer, a quick demo of how Lactic replies.',
                  style: TextStyle(color: t.textMuted, height: 1.5)),
              const SizedBox(height: 18),
              Expanded(
                child: _picked == null
                    // empty state: suggestion chips
                    ? ListView(
                        children: [
                          const SizedBox(height: 8),
                          const Center(child: Illustration('how_it_works', size: 110)),
                          const SizedBox(height: 22),
                          ...demos.map((d) => _Suggestion(text: d.$1, onTap: () => _pick(d))),
                        ],
                      )
                    // chat window: the conversation, top-aligned like the real chat
                    : ListView(
                        children: [
                          ChatBubble(msg: ChatMessage(role: 'user', content: _picked!.$1)),
                          ChatBubble(
                            msg: ChatMessage(
                              role: 'assistant',
                              content: _thinking ? '' : _picked!.$2,
                              streaming: _thinking,
                              examInsight: _thinking || _picked!.$3.isEmpty
                                  ? null
                                  : ExamInsight(tested: true, summary: _picked!.$3),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Center(
                            child: TextButton.icon(
                              onPressed: () => setState(() {
                                _picked = null;
                                _thinking = false;
                              }),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Try another question'),
                            ),
                          ),
                        ],
                      ),
              ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: widget.onNext, child: const Text('Continue')),
          ),
        ],
      ),
    );
  }
}

class _Suggestion extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _Suggestion({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: t.primarySoft.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            Expanded(child: Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: t.onPrimarySoft))),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: t.onPrimarySoft),
          ]),
        ),
      ),
    );
  }
}
