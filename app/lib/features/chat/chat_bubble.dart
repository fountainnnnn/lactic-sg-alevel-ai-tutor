import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../core/text_utils.dart';
import '../../core/theme/tokens.dart';
import '../../data/models.dart';
import 'streaming_text.dart';

/// One chat message: a mode-change notice (centered pill), a student bubble
/// (right), or the tutor answer (left) with a "How this is tested" footer.
/// While waiting for the first token, a compact 3-dot typing indicator shows
/// instead of the full answer card.
class ChatBubble extends StatelessWidget {
  final ChatMessage msg;
  final VoidCallback? onGrow;
  const ChatBubble({super.key, required this.msg, this.onGrow});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);

    // mid-conversation mode-change note
    if (msg.role == 'notice') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: t.surfaceMuted, borderRadius: BorderRadius.circular(999)),
            child: Text(msg.content.noDashes,
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.35)),
          ),
        ),
      );
    }

    if (msg.role == 'user') {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 56, bottom: 18),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: t.primarySoft,
            border: Border.all(color: t.border),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(FF.rBubble),
              topRight: Radius.circular(FF.rBubble),
              bottomLeft: Radius.circular(FF.rBubble),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(msg.content.noDashes,
              style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600, height: 1.45)),
        ),
      );
    }

    // assistant, still waiting for the first token → compact typing indicator
    if (msg.content.isEmpty && msg.streaming) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: t.border),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(FF.rBubble),
              topRight: Radius.circular(FF.rBubble),
              bottomRight: Radius.circular(FF.rBubble),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: const _TypingDots(),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(right: 40, bottom: 18),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: t.border),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(FF.rBubble),
          topRight: Radius.circular(FF.rBubble),
          bottomRight: Radius.circular(FF.rBubble),
          bottomLeft: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(6, 3, 11, 3),
            decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Image.asset('assets/brand/lactic_icon_small.png',
                  width: 15, height: 15, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              const SizedBox(width: 5),
              Text('Lactic',
                  style: TextStyle(
                      color: t.onPrimarySoft, fontWeight: FontWeight.w700, fontSize: 11.5, letterSpacing: 0.2)),
            ]),
          ),
          const SizedBox(height: 10),
          StreamingText(text: msg.content.noDashes, done: !msg.streaming, onGrow: onGrow),
          if (msg.examInsight != null) _ExamInsight(insight: msg.examInsight!),
        ],
      ),
    );
  }
}

/// "How this is tested" — a general note on how the concept shows up in
/// A-Level exams. No specific question, no named paper (by design).
class _ExamInsight extends StatelessWidget {
  final ExamInsight insight;
  const _ExamInsight({required this.insight});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 12),
          child: Divider(height: 1, color: t.border),
        ),
        Row(children: [
          Icon(Icons.workspace_premium_outlined, size: 17, color: scheme.primary),
          const SizedBox(width: 6),
          Text('How this is tested',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: scheme.onSurface)),
        ]),
        if (insight.tested) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: t.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_rounded, size: 14, color: t.success),
              const SizedBox(width: 5),
              Text('Tested in A-Levels',
                  style: TextStyle(fontSize: 11.5, color: t.success, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
            ]),
          ),
        ],
        if (insight.summary.isNotEmpty) ...[
          const SizedBox(height: 10),
          GptMarkdown(insight.summary.noDashes, style: TextStyle(color: t.textMuted, fontSize: 13.5, height: 1.5)),
        ] else if (!insight.tested) ...[
          const SizedBox(height: 8),
          Text('Not a common A-Level exam topic, but still worth understanding well.',
              style: TextStyle(color: t.textMuted, fontSize: 13.5, height: 1.45)),
        ],
      ],
    );
  }
}

/// Three softly pulsing dots — the "tutor is typing" indicator.
class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.tokens.textMuted;
    return SizedBox(
      height: 9,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_c.value - i * 0.18) % 1.0;
            final pulse = (phase < 0.5 ? phase * 2 : 2 - phase * 2).clamp(0.0, 1.0);
            return Padding(
              padding: EdgeInsets.only(right: i < 2 ? 5 : 0),
              child: Opacity(
                opacity: 0.3 + 0.7 * pulse,
                child: Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              ),
            );
          }),
        ),
      ),
    );
  }
}
