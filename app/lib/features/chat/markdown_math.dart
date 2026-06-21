import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// Renders an answer as Markdown with LaTeX math. Uses gpt_markdown so inline
/// math ($x$) stays inline and block math ($$...$$) is centered on its own line
/// — the flutter_markdown builder was breaking inline math onto new lines.
/// Body weight is bumped slightly for easier reading.
class MathMarkdown extends StatelessWidget {
  final String data;
  const MathMarkdown(this.data, {super.key});

  // Strip orphaned inline citation markers like "[#1]" or "[#1, #4]".
  static final _cite = RegExp(r'\s*\[#\d+(?:\s*,\s*#?\d+)*\]');
  // gpt_markdown expects LaTeX in \( \) / \[ \], not $ / $$ — convert.
  static final _block = RegExp(r'\$\$([\s\S]+?)\$\$');
  static final _inline = RegExp(r'\$([^\$\n]+?)\$');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    var s = data.replaceAll(_cite, '');
    s = s.replaceAllMapped(_block, (m) => '\\[${m[1]!.trim()}\\]');
    s = s.replaceAllMapped(_inline, (m) => '\\(${m[1]!.trim()}\\)');
    return GptMarkdown(s.trim(), style: style, latexBuilder: _latex);
  }

  /// Render LaTeX ourselves so wide *block* equations scroll horizontally
  /// instead of overflowing the chat bubble (which happens with long lines or
  /// at large system font sizes). Inline math flows with the text as before.
  Widget _latex(BuildContext context, String tex, TextStyle textStyle, bool inline) {
    final math = Math.tex(
      tex,
      textStyle: textStyle,
      mathStyle: inline ? MathStyle.text : MathStyle.display,
      textScaleFactor: 1,
      settings: const TexParserSettings(strict: Strict.ignore),
      onErrorFallback: (err) => Text(tex, style: textStyle),
    );
    if (inline) return math;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: math,
    );
  }
}
