import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../state/app_state.dart';

/// One parsed memory entry: a topic with an optional date and reason.
class _Entry {
  final String topic;
  final String? date;
  final String? note;
  const _Entry(this.topic, this.date, this.note);
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  String? _section(String md, String heading) {
    // tolerant heading match (e.g. "Mastered (recent)" or "Mastered")
    final m = RegExp('## ${RegExp.escape(heading)}[^\n]*\\n([\\s\\S]*?)(?=\\n## |\$)').firstMatch(md);
    return m?.group(1)?.trim();
  }

  List<String> _lines(String? block) {
    if (block == null) return [];
    return block
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'^[-*]\s*'), '').trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  /// "2026-06-10  H2 Physics > Kinematics (got 3 wrong)" -> date/topic/note.
  _Entry _entry(String line) {
    String rest = line;
    String? date;
    final dm = RegExp(r'^(\d{4}-\d{2}-\d{2})\s+').firstMatch(rest);
    if (dm != null) {
      date = dm.group(1);
      rest = rest.substring(dm.end);
    }
    String? note;
    final nm = RegExp(r'\s*\((.+)\)\s*$').firstMatch(rest);
    if (nm != null) {
      note = nm.group(1);
      rest = rest.substring(0, nm.start);
    }
    return _Entry(rest.trim(), date, note);
  }

  String _shortDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    const mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${mon[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final md = ref.watch(memoryStoreProvider).markdown;

    final profile = _section(md, 'Profile') ?? '';
    final name = RegExp(r'Name:\s*(.+)').firstMatch(profile)?.group(1)?.trim();
    final subjects = RegExp(r'Subjects:\s*(.+)').firstMatch(profile)?.group(1)?.trim();
    final year = RegExp(r'(JC\s*[12])').firstMatch(profile)?.group(1)?.replaceAll(' ', '');
    final subtitle = [if (year != null) year, if (subjects != null) subjects].join(' • ');

    final prefs = _lines(_section(md, 'Explanation preferences'));
    final mastered = _lines(_section(md, 'Mastered')).map(_entry).toList();
    final struggling = _lines(_section(md, 'Struggling topics')).map(_entry).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            // identity card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(FF.rCard),
                border: Border.all(color: t.border),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: t.primarySoft,
                  child: Icon(Icons.person_rounded, size: 32, color: t.onPrimarySoft),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name ?? 'Your profile', style: text.titleLarge),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(subtitle, style: TextStyle(color: t.textMuted, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit profile',
                  icon: Icon(Icons.edit_outlined, color: scheme.primary),
                  onPressed: () => context.push('/edit-profile'),
                ),
              ]),
            ),

            if (prefs.isNotEmpty) ...[
              const _SectionLabel('How I explain things'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: prefs
                    .take(4)
                    .map((p) => _Chip(label: p, bg: t.primarySoft, fg: t.onPrimarySoft, border: t.border))
                    .toList(),
              ),
            ],

            if (mastered.isNotEmpty) ...[
              const _SectionLabel('Recently mastered'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: mastered
                    .take(6)
                    .map((e) => _Chip(
                          label: e.topic,
                          icon: Icons.check_circle_rounded,
                          bg: t.success.withValues(alpha: 0.12),
                          fg: t.success,
                          border: t.success.withValues(alpha: 0.30),
                        ))
                    .toList(),
              ),
            ],

            const _SectionLabel('Struggling topics'),
            if (struggling.isEmpty)
              Text('Nothing yet. As you study, I’ll note topics you find tricky here.',
                  style: TextStyle(color: t.textMuted, height: 1.5))
            else
              ...struggling.map((e) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: t.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(e.topic, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3)),
                            ),
                            if (e.date != null) ...[
                              const SizedBox(width: 8),
                              Text(_shortDate(e.date),
                                  style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ],
                        ),
                        if (e.note != null) ...[
                          const SizedBox(height: 4),
                          Text(e.note!, style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.4)),
                        ],
                      ],
                    ),
                  )),

            const SizedBox(height: 20),
            // privacy assurance
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.primarySoft.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.lock_outline_rounded, size: 18, color: t.onPrimarySoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Your data is private and secure — kept on your device and used only to tutor you.',
                      style: TextStyle(color: scheme.onSurface, fontSize: 13, height: 1.45)),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color bg;
  final Color fg;
  final Color border;
  const _Chip({required this.label, this.icon, required this.bg, required this.fg, required this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 14 : 10, 7, 14, 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(label,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}
