import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lactic/features/chat/streaming_text.dart';

void main() {
  testWidgets('types the answer in, then settles into Markdown when done',
      (tester) async {
    const answer = 'Velocity is the rate of change of displacement with time.';
    var done = false;
    late StateSetter setOuter;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (_, setState) {
          setOuter = setState;
          return StreamingText(text: answer, done: done);
        }),
      ),
    ));

    // Mid-stream: rendered as plain text with a blinking caret — NOT Markdown yet.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(GptMarkdown), findsNothing,
        reason: 'should stream as plain text, not formatted markdown');
    expect(find.textContaining('▌'), findsOneWidget,
        reason: 'a caret should show while typing');
    expect(find.textContaining('Velocity'), findsOneWidget,
        reason: 'revealed text should be visible while streaming');

    // Turn finishes: it should settle into Markdown and drop the caret.
    setOuter(() => done = true);
    await tester.pump(); // apply done:true
    await tester.pump(const Duration(milliseconds: 100)); // reveal timer cancels itself

    expect(find.byType(GptMarkdown), findsOneWidget,
        reason: 'finished answer renders as formatted markdown');
    expect(find.textContaining('▌'), findsNothing,
        reason: 'caret gone once finished');
    // No pending timers here, or testWidgets would fail the test.
  });

  testWidgets('messages loaded from history render instantly, no typing',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StreamingText(text: 'Already **answered** earlier.', done: true),
      ),
    ));

    // done:true from the first frame => straight to Markdown, no animation/timers.
    expect(find.byType(GptMarkdown), findsOneWidget);
    expect(find.textContaining('▌'), findsNothing);
  });
}
