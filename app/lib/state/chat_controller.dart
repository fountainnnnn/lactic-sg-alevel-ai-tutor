import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/conversation_store.dart';
import '../data/models.dart';
import 'app_state.dart';

@immutable
class ChatState {
  final List<ChatMessage> messages;
  final bool sending;
  final LimitException? limit; // non-null -> show 429/503 state

  const ChatState({this.messages = const [], this.sending = false, this.limit});

  ChatState copyWith({List<ChatMessage>? messages, bool? sending, LimitException? limit}) =>
      ChatState(
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
        limit: limit,
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
    state = ChatState(messages: List.of(c.messages));
  }

  Future<void> send(String text, {String? subjectHint, String? levelHint}) async {
    final msg = text.trim();
    if (msg.isEmpty || state.sending) return;

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

    final history = state.messages
        .where((m) => !m.streaming)
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    final user = ChatMessage(role: 'user', content: msg);
    final assistant = ChatMessage(role: 'assistant', streaming: true);
    state = state.copyWith(
      messages: [...state.messages, user, assistant],
      sending: true,
      limit: null,
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
        );
      }
      state = state.copyWith(messages: [...state.messages], sending: false);
      final c = _current;
      if (c != null && state.messages.isNotEmpty) {
        c.messages = state.messages.where((m) => !m.streaming).toList();
        c.updatedAt = DateTime.now();
        ref.read(conversationStoreProvider).save(c);
      }
    }
  }

  void reset() {
    _current = null;
    state = const ChatState();
  }
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) => ChatController(ref));
