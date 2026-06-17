import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Reveals an answer with a smooth typewriter + blinking caret while it streams,
/// then settles into formatted Markdown once the turn is done. The reveal pace
/// is decoupled from the (chunky) network token cadence: it advances a few chars
/// per frame and speeds up if it falls behind, so it always keeps up with — but
/// never dumps — the incoming stream. Only messages that *begin* while streaming
/// animate; messages loaded from history (`done` already true) render instantly.
class StreamingText extends StatefulWidget {
  /// The full text received so far. Grows as tokens arrive.
  final String text;

  /// True once the turn is finished (no more tokens coming).
  final bool done;

  /// Called each time more characters are revealed, so the caller can keep the
  /// view scrolled to the bottom as the answer types in.
  final VoidCallback? onGrow;

  const StreamingText({super.key, required this.text, required this.done, this.onGrow});

  @override
  State<StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<StreamingText> {
  late final bool _animated = !widget.done;
  int _shown = 0;
  bool _caretOn = true;
  Timer? _reveal;
  Timer? _blink;

  @override
  void initState() {
    super.initState();
    if (_animated) {
      _reveal = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
      _blink = Timer.periodic(const Duration(milliseconds: 530), (_) {
        if (mounted) setState(() => _caretOn = !_caretOn);
      });
    } else {
      _shown = widget.text.length;
    }
  }

  void _tick() {
    final target = widget.text.length;
    if (_shown >= target) {
      if (widget.done) _finish();
      return;
    }
    final remaining = target - _shown;
    final step = remaining > 150 ? remaining ~/ 10 : (remaining > 20 ? 3 : 1);
    setState(() => _shown = (_shown + step).clamp(0, target));
    widget.onGrow?.call();
    if (_shown >= target && widget.done) _finish();
  }

  void _finish() {
    _reveal?.cancel();
    _reveal = null;
    _blink?.cancel();
    _blink = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _reveal?.cancel();
    _blink?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fullyShown = _shown >= widget.text.length;
    final showMarkdown = !_animated || (widget.done && fullyShown);

    if (showMarkdown) {
      return MarkdownBody(
        data: widget.text,
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
          p: theme.textTheme.bodyLarge,
          strong: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      );
    }

    final shown = widget.text.substring(0, _shown.clamp(0, widget.text.length));
    return Text.rich(
      TextSpan(
        style: theme.textTheme.bodyLarge,
        children: [
          TextSpan(text: shown),
          // Caret keeps its slot (transparent when "off") so blinking never reflows.
          TextSpan(
            text: '▌',
            style: TextStyle(color: _caretOn ? theme.colorScheme.primary : Colors.transparent),
          ),
        ],
      ),
    );
  }
}
