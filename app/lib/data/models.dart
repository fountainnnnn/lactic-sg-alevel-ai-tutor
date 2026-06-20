/// A cited source the tutor used, surfaced as a chip under the answer.
class Citation {
  final int n;
  final String ref;
  final bool verbatimSafe;
  Citation({required this.n, required this.ref, required this.verbatimSafe});

  factory Citation.fromJson(Map<String, dynamic> j) => Citation(
        n: (j['n'] ?? 0) as int,
        ref: (j['ref'] ?? 'source').toString(),
        verbatimSafe: (j['verbatim_safe'] ?? false) as bool,
      );
}

/// "How this is tested" — whether the concept appears in prelim/past-year papers,
/// and one representative real question (with its paper reference) to show.
class ExamInsight {
  final bool tested;
  final String summary; // e.g. "Frequently examined in Singapore prelims."
  final String? question; // one real prelim question, verbatim
  final String? questionRef; // e.g. "H2 Chemistry 2022 Prelim"
  ExamInsight({required this.tested, this.summary = '', this.question, this.questionRef});

  factory ExamInsight.fromJson(Map<String, dynamic> j) {
    final q = (j['question'] ?? '').toString().trim();
    final r = (j['ref'] ?? j['question_ref'] ?? '').toString().trim();
    return ExamInsight(
      tested: (j['tested'] ?? false) == true,
      summary: (j['summary'] ?? '').toString().trim(),
      question: q.isEmpty ? null : q,
      questionRef: r.isEmpty ? null : r,
    );
  }
}

/// One chat turn shown in the thread.
class ChatMessage {
  final String role; // 'user' | 'assistant'
  String content;
  List<Citation> citations;
  ExamInsight? examInsight;
  final bool streaming;
  ChatMessage({
    required this.role,
    this.content = '',
    List<Citation>? citations,
    this.examInsight,
    this.streaming = false,
  }) : citations = citations ?? [];
}

/// Streaming events emitted by the chat Edge Function (SSE).
sealed class ChatEvent {
  const ChatEvent();
}

class TokenEvent extends ChatEvent {
  final String text;
  const TokenEvent(this.text);
}

class CitationsEvent extends ChatEvent {
  final List<Citation> citations;
  const CitationsEvent(this.citations);
}

class ClarifyEvent extends ChatEvent {
  final String question;
  const ClarifyEvent(this.question);
}

class MemoryDeltaEvent extends ChatEvent {
  final Map<String, dynamic> delta;
  const MemoryDeltaEvent(this.delta);
}

class ExamInsightEvent extends ChatEvent {
  final ExamInsight insight;
  const ExamInsightEvent(this.insight);
}

/// Backend hint that this turn is math/physics and a Plus+ user on the Standard
/// model would likely get a better answer from Lactic Reasoning.
class SuggestReasoningEvent extends ChatEvent {
  final bool on;
  const SuggestReasoningEvent(this.on);
}

class DoneEvent extends ChatEvent {
  final String? conversationId;
  final String? model;
  const DoneEvent({this.conversationId, this.model});
}

class ErrorEvent extends ChatEvent {
  final String message;
  const ErrorEvent(this.message);
}

/// Raised when the backend rate-limits (429) or hits capacity (503), so the UI
/// can show the right friendly state.
class LimitException implements Exception {
  final int status; // 429 or 503
  final String message;
  LimitException(this.status, this.message);
  bool get isDaily => status == 429;
}
