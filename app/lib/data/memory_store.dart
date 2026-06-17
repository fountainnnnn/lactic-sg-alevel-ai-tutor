import 'package:shared_preferences/shared_preferences.dart';

/// On-device `memory.md` (privacy by default), stored in SharedPreferences so it
/// works on every platform including web. Sent to the backend each turn to
/// personalise answers; the backend returns a delta we apply locally. We never
/// claim it "stays on device" in copy — it is transmitted securely for inference.
class MemoryStore {
  static const _key = 'memory_md';
  final SharedPreferences _prefs;
  String _md = '';

  MemoryStore(this._prefs);

  String get markdown => _md;

  Future<String> load() async {
    _md = _prefs.getString(_key) ?? '# JCAI Memory\n';
    return _md;
  }

  Future<void> _save() async => _prefs.setString(_key, _md);

  /// Write the Profile section from onboarding (subjects + level).
  Future<void> setProfile({
    String? name,
    required List<String> subjects,
    String? level,
  }) async {
    final lines = <String>['## Profile'];
    if (name != null && name.isNotEmpty) lines.add('- Name: $name');
    if (subjects.isNotEmpty) lines.add('- Subjects: ${subjects.join(', ')}');
    if (level != null && level.isNotEmpty) lines.add('- JC year: $level');
    final profile = '${lines.join('\n')}\n';
    if (_md.contains('## Profile')) {
      _md = _md.replaceFirst(RegExp(r'## Profile[\s\S]*?(?=\n## |$)'), profile);
    } else {
      _md = _md.trimRight().isEmpty ? '# JCAI Memory\n\n$profile' : '$_md\n$profile';
    }
    await _save();
  }

  /// Apply a memory delta returned by the backend (mirror of the server logic).
  Future<void> applyDelta(Map<String, dynamic> delta) async {
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
