import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// A saved conversation (title from first question, subject hint, messages).
class Conversation {
  final String id;
  String title;
  String subject;
  DateTime updatedAt;
  List<ChatMessage> messages;

  Conversation({
    required this.id,
    required this.title,
    this.subject = '',
    required this.updatedAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages
            .map((m) => {
                  'role': m.role,
                  'content': m.content,
                  'citations': m.citations
                      .map((c) => {'n': c.n, 'ref': c.ref, 'verbatim_safe': c.verbatimSafe})
                      .toList(),
                })
            .toList(),
      };

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        subject: (j['subject'] ?? '') as String,
        updatedAt: DateTime.tryParse((j['updatedAt'] ?? '') as String) ?? DateTime.now(),
        messages: ((j['messages'] as List?) ?? [])
            .map((m) => ChatMessage(
                  role: m['role'] as String,
                  content: (m['content'] ?? '') as String,
                  citations: ((m['citations'] as List?) ?? [])
                      .map((c) => Citation(
                          n: (c['n'] ?? 0) as int,
                          ref: (c['ref'] ?? '') as String,
                          verbatimSafe: (c['verbatim_safe'] ?? false) as bool))
                      .toList(),
                ))
            .toList(),
      );
}

/// Conversations stored locally (works on every platform via SharedPreferences).
class ConversationStore {
  static const _key = 'conversations';
  final SharedPreferences _prefs;
  ConversationStore(this._prefs);

  List<Conversation> list() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      final items = (jsonDecode(raw) as List)
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items;
    } catch (_) {
      return [];
    }
  }

  Conversation? get(String id) {
    for (final c in list()) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> save(Conversation c) async {
    final all = list().where((x) => x.id != c.id).toList()..insert(0, c);
    final capped = all.take(50).toList();
    await _prefs.setString(_key, jsonEncode(capped.map((x) => x.toJson()).toList()));
  }

  Future<void> delete(String id) async {
    final all = list().where((x) => x.id != id).toList();
    await _prefs.setString(_key, jsonEncode(all.map((x) => x.toJson()).toList()));
  }

  Future<void> clear() async => _prefs.remove(_key);
}

/// Daily study streak, derived from active-day timestamps in prefs.
class StreakStore {
  final SharedPreferences _prefs;
  StreakStore(this._prefs);

  static String _day(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// Call when the student is active; returns the current streak.
  Future<int> record() async {
    final now = DateTime.now();
    final today = _day(now);
    final last = _prefs.getString('streak_last');
    var count = _prefs.getInt('streak_count') ?? 0;
    if (last == today) {
      // already counted today
    } else if (last == _day(now.subtract(const Duration(days: 1)))) {
      count += 1;
    } else {
      count = 1;
    }
    await _prefs.setString('streak_last', today);
    await _prefs.setInt('streak_count', count);
    return count;
  }

  int current() {
    final last = _prefs.getString('streak_last');
    final now = DateTime.now();
    if (last == _day(now) || last == _day(now.subtract(const Duration(days: 1)))) {
      return _prefs.getInt('streak_count') ?? 0;
    }
    return 0; // streak broken
  }
}
