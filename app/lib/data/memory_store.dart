import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// On-device `memory.md` (privacy by default), stored in SharedPreferences so it
/// works on every platform including web. Sent to the backend each turn to
/// personalise answers; the backend returns a delta we apply locally. We never
/// claim it "stays on device" in copy — it is transmitted securely for inference.
///
/// Memory is a SIGNED-IN benefit. For anonymous users every method is a no-op:
/// nothing is loaded, saved, or built, so each session starts fresh with no
/// memory. Sign up to get a tutor that remembers you across sessions.
class MemoryStore {
  static const _key = 'memory_md';
  final SharedPreferences _prefs;
  String _md = '';

  MemoryStore(this._prefs);

  static bool get _signedIn => Supabase.instance.client.auth.currentUser != null;

  String get markdown => _md;

  /// Subject tags saved during onboarding (e.g. "H2 Chemistry"), parsed back out
  /// of the Profile section so the picker can restore the student's selection.
  List<String> get subjects {
    final m = RegExp(r'- Subjects:\s*(.+)').firstMatch(_md);
    if (m == null) return [];
    return m.group(1)!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  /// Load persisted memory for a signed-in user. Anonymous users get an empty
  /// memory every launch (no persistence) — this is what makes each anonymous
  /// session a fresh start. Call this again on sign-in/out to re-sync.
  Future<String> load() async {
    _md = _signedIn ? (_prefs.getString(_key) ?? '# Lactic Memory\n') : '';
    return _md;
  }

  /// Drop the in-memory copy (used on sign-out so the session reverts to the
  /// anonymous, no-memory state immediately).
  void clear() => _md = '';

  Future<void> _save() async {
    if (!_signedIn) return; // anonymous sessions never persist memory
    await _prefs.setString(_key, _md);
  }

  /// Write the Profile section from onboarding (subjects + level).
  Future<void> setProfile({
    String? name,
    required List<String> subjects,
    String? level,
  }) async {
    if (!_signedIn) return; // no memory for anonymous users
    final lines = <String>['## Profile'];
    if (name != null && name.isNotEmpty) lines.add('- Name: $name');
    if (subjects.isNotEmpty) lines.add('- Subjects: ${subjects.join(', ')}');
    if (level != null && level.isNotEmpty) lines.add('- JC year: $level');
    final profile = '${lines.join('\n')}\n';
    if (_md.contains('## Profile')) {
      _md = _md.replaceFirst(RegExp(r'## Profile[\s\S]*?(?=\n## |$)'), profile);
    } else {
      _md = _md.trimRight().isEmpty ? '# Lactic Memory\n\n$profile' : '$_md\n$profile';
    }
    await _save();
  }

  /// Apply a memory delta returned by the backend (mirror of the server logic).
  Future<void> applyDelta(Map<String, dynamic> delta) async {
    if (!_signedIn) return; // anonymous users build no persistent memory
    for (final s in (delta['struggling_add'] as List? ?? [])) {
      final m = s as Map<String, dynamic>;
      _append('Struggling topics', '- ${m['date'] ?? ''}  ${m['topic'] ?? ''} (${m['why'] ?? ''})');
    }
    for (final m in (delta['mastered_add'] as List? ?? [])) {
      final mm = m as Map<String, dynamic>;
      _append('Mastered (recent)', '- ${mm['date'] ?? ''}  ${mm['topic'] ?? ''}');
    }
    final rq = delta['recent_question_add'];
    if (rq is String && rq.isNotEmpty) _append('Recent questions', '- $rq');
    final tn = delta['tutor_note_add'];
    if (tn is String && tn.isNotEmpty) _append('Notes from tutor', '- $tn');
    _capSize();
    await _save();
  }

  void _append(String heading, String line) {
    if (!_md.contains('## $heading')) {
      _md = '${_md.trimRight()}\n\n## $heading\n';
    }
    _md = _md.replaceFirst('## $heading\n', '## $heading\n$line\n');
  }

  void _capSize() {
    const cap = 8192;
    while (_md.length > cap) {
      final lines = _md.split('\n');
      if (lines.length <= 1) break;
      lines.removeLast();
      _md = lines.join('\n');
    }
  }
}
