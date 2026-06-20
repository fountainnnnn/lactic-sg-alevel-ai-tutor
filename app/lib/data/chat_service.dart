import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import 'models.dart';

/// Streams answers from the deployed `chat` Edge Function over SSE.
/// Uses the signed-in user's JWT when available, else the publishable key
/// (anonymous use — the backend allows it and rate-limits per device).
class ChatService {
  final http.Client _client = http.Client();

  Stream<ChatEvent> stream({
    required String message,
    required String memoryMd,
    List<Map<String, String>> history = const [],
    String? answerStyle, // 'coach' | 'direct'
    String? modelPref, // 'standard' | 'reasoning' (Plus+ only; backend ignores it otherwise)
    String? subjectHint,
    String? levelHint,
    String? deviceId,
    String? imagePath, // storage path under uploads/ — triggers backend OCR
    bool premium = false,
  }) async* {
    final token =
        Supabase.instance.client.auth.currentSession?.accessToken ??
            Config.supabasePublishableKey;

    final req = http.Request('POST', Uri.parse(Config.chatEndpoint));
    req.headers.addAll({
      'Authorization': 'Bearer $token',
      'apikey': Config.supabasePublishableKey,
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      if (deviceId != null) 'x-device-id': deviceId,
    });
    req.body = jsonEncode({
      'message': message,
      'memory_md': memoryMd,
      'history': history,
      if (imagePath != null) 'image_path': imagePath,
      if (answerStyle != null) 'answer_style': answerStyle,
      if (modelPref != null) 'model_pref': modelPref,
      if (subjectHint != null) 'subject_hint': subjectHint,
      if (levelHint != null) 'level_hint': levelHint,
      'premium': premium,
    });

    final http.StreamedResponse resp;
    try {
      // connect timeout: don't leave the user hanging if the backend never
      // responds to the request headers.
      resp = await _client.send(req).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      yield const ErrorEvent('Could not reach the tutor. Check your connection and try again.');
      return;
    }
    if (resp.statusCode == 429 || resp.statusCode == 503) {
      final body = await resp.stream.bytesToString();
      yield ErrorEvent(_msgFrom(body, resp.statusCode));
      throw LimitException(resp.statusCode, _msgFrom(body, resp.statusCode));
    }
    if (resp.statusCode >= 400) {
      await resp.stream.drain<void>();
      yield ErrorEvent('Something went wrong (${resp.statusCode}).');
      return;
    }

    // Parse the SSE stream: lines `event: X` then `data: {...}`, blank-separated.
    // idle timeout: resets on every line, so it fires only when the backend goes
    // silent mid-answer (no blinking-caret-forever).
    var event = '';
    final buffer = StringBuffer();
    try {
      await for (final line in resp.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(const Duration(seconds: 60))) {
        if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          buffer.write(line.substring(5).trim());
        } else if (line.isEmpty) {
          final data = buffer.toString();
          buffer.clear();
          if (data.isEmpty) continue;
          final parsed = _parse(event, data);
          if (parsed != null) yield parsed;
          event = '';
        }
      }
    } on TimeoutException {
      yield const ErrorEvent('The tutor took too long to respond. Please try again.');
    }
  }

  ChatEvent? _parse(String event, String data) {
    Map<String, dynamic> j;
    try {
      final decoded = jsonDecode(data);
      if (decoded is List && event == 'citations') {
        return CitationsEvent(
            decoded.map((e) => Citation.fromJson(e as Map<String, dynamic>)).toList());
      }
      j = decoded as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    switch (event) {
      case 'token':
        return TokenEvent((j['t'] ?? '').toString());
      case 'clarify':
        return ClarifyEvent((j['question'] ?? '').toString());
      case 'memory_delta':
        return MemoryDeltaEvent(j);
      case 'exam_insight':
        return ExamInsightEvent(ExamInsight.fromJson(j));
      case 'suggest_reasoning':
        return SuggestReasoningEvent((j['on'] ?? false) == true);
      case 'done':
        return DoneEvent(
            conversationId: j['conversation_id']?.toString(), model: j['model']?.toString());
      case 'error':
        return ErrorEvent((j['message'] ?? 'Something went wrong.').toString());
      default:
        return null;
    }
  }

  String _msgFrom(String body, int status) {
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      return (j['message'] ?? '').toString();
    } catch (_) {
      return status == 429
          ? "You've reached today's questions. Back in a few hours."
          : "Lactic is taking a short break. Try again soon.";
    }
  }
}
