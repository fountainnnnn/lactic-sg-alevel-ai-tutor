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

/// One chat turn shown in the thread.
class ChatMessage {
  final String role; // 'user' | 'assistant'
  String content;
  List<Citation> citations;
  final bool streaming;
  ChatMessage({
    required this.role,
    this.content = '',
    List<Citation>? citations,
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
