import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/text_utils.dart';
import '../data/conversation_store.dart';
import '../data/models.dart';
import 'app_state.dart';

@immutable
class ChatState {
  final List<ChatMessage> messages;
  final bool sending;
  final LimitException? limit; // non-null -> show 429/503 state
  final String? subject; // e.g. "Chemistry" (appbar title)
  final String? topic; // conversation title (appbar subtitle)

  const ChatState({this.messages = const [], this.sending = false, this.limit, this.subject, this.topic});

  ChatState copyWith({List<ChatMessage>? messages, bool? sending, LimitException? limit, String? subject, String? topic}) =>
      ChatState(
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
        limit: limit,
        subject: subject ?? this.subject,
        topic: topic ?? this.topic,
      );
}

/// Drives one conversation: sends a turn, streams tokens into the live assistant
/// message, applies the returned memory delta. Wired to the real backend.
class ChatController extends StateNotifier<ChatState> {
  final Ref ref;
  Conversation? _current;
  ChatController(this.ref) : super(const ChatState());

  /// Resume a saved conversation.
  void load(Conversation c) {
    _current = c;
    state = ChatState(messages: List.of(c.messages), subject: c.subject, topic: c.title);
  }

  Future<void> send(String text,
      {String? subjectHint, String? levelHint, String? imagePath}) async {
    if (state.sending) return;
    // A photo with no typed question is a valid turn — the backend OCRs it.
    final msg = (text.trim().isEmpty && imagePath != null
            ? 'Help me with this question.'
            : text.trim())
        .noDashes;
    if (msg.isEmpty) return;

    ref.read(streakStoreProvider).record();
    _current ??= Conversation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: msg.length > 60 ? '${msg.substring(0, 60)}…' : msg,
      subject: subjectHint ?? '',
      updatedAt: DateTime.now(),
      messages: [],
    );

    final memory = ref.read(memoryStoreProvider);
    final answerStyle = ref.read(settingsProvider).answerStyle;
    final deviceId = ref.read(deviceIdProvider);
    final premium = ref.read(premiumProvider);

    final history = state.messages
        .where((m) => !m.streaming && (m.role == 'user' || m.role == 'assistant'))
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    final user = ChatMessage(role: 'user', content: msg);
    final assistant = ChatMessage(role: 'assistant', streaming: true);
    state = state.copyWith(
      messages: [...state.messages, user, assistant],
      sending: true,
      limit: null,
      subject: _current!.subject,
      topic: _current!.title,
    );

    void bump() => state = state.copyWith(messages: [...state.messages]);

    try {
      final stream = ref.read(chatServiceProvider).stream(
            message: msg,
            memoryMd: memory.markdown,
            history: history,
            answerStyle: answerStyle,
            subjectHint: subjectHint,
            levelHint: levelHint,
            deviceId: deviceId,
            imagePath: imagePath,
            premium: premium,
          );
      await for (final ev in stream) {
        switch (ev) {
          case TokenEvent(:final text):
            assistant.content += text;
            bump();
          case ClarifyEvent(:final question):
            assistant.content = question;
            bump();
          case CitationsEvent(:final citations):
            assistant.citations = citations;
            bump();
          case ExamInsightEvent(:final insight):
            assistant.examInsight = insight;
            bump();
          case MemoryDeltaEvent(:final delta):
            await memory.applyDelta(delta);
          case DoneEvent():
          case ErrorEvent():
            break;
        }
      }
    } on LimitException catch (e) {
      // remove the empty assistant placeholder, surface the limit state
      final trimmed = [...state.messages]..removeWhere((m) => m == assistant);
      state = state.copyWith(messages: trimmed, limit: e);
    } catch (_) {
      if (assistant.content.isEmpty) {
        assistant.content = 'Sorry, I could not reach the tutor. Please try again.';
      }
    } finally {
      final i = state.messages.indexOf(assistant);
      if (i != -1) {
        state.messages[i] = ChatMessage(
          role: 'assistant',
          content: assistant.content,
          citations: assistant.citations,
          examInsight: assistant.examInsight,
        );
      }
      state = state.copyWith(messages: [...state.messages], sending: false);
      final c = _current;
      if (c != null && state.messages.isNotEmpty) {
        c.messages = state.messages.where((m) => !m.streaming && m.role != 'notice').toList();
        c.updatedAt = DateTime.now();
        ref.read(conversationStoreProvider).save(c);
      }
    }
  }

  void reset() {
    _current = null;
    state = const ChatState();
  }

  /// Insert a verbose, in-thread note when the answer style changes mid-chat.
  /// (No-op before the conversation has started.)
  void noteStyle(String style) {
    if (state.messages.isEmpty) return;
    final text = style == 'coach'
        ? "Switched to Guide me. I'll walk you through it step by step and check your understanding as we go."
        : "Switched to Just answer. I'll lead with the answer, then a tight explanation.";
    state = state.copyWith(messages: [...state.messages, ChatMessage(role: 'notice', content: text)]);
  }
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) => ChatController(ref));
