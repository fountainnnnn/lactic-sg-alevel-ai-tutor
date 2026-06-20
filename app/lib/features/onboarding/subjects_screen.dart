import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/subjects.dart';
import '../../core/theme/tokens.dart';
import '../../state/app_state.dart';
import '../shared/illustration.dart';

// Subjects offered at each level — shared catalogue (see core/subjects.dart) so
// onboarding and the profile editor never drift apart.
const _byLevel = subjectsByLevel;
const _levels = subjectLevels;

class SubjectsStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  const SubjectsStep({super.key, required this.onNext});
  @override
  ConsumerState<SubjectsStep> createState() => _SubjectsStepState();
}

class _SubjectsStepState extends ConsumerState<SubjectsStep> {
  String _level = 'H2';
  final _selected = <String>{}; // tagged: "H2 Chemistry"

  @override
  void initState() {
    super.initState();
    // Restore any previously saved picks so going back/forward keeps them. Read
    // the live provider first (works for anon); fall back to saved memory.
    final live = ref.read(onboardingSubjectsProvider);
    _selected.addAll(live.isNotEmpty ? live : ref.read(memoryStoreProvider).subjects);
    for (final lv in _levels) {
      if (_selected.any((t) => t.startsWith('$lv '))) {
        _level = lv;
        break;
      }
    }
  }

  // Save on every toggle so the next step's demo reflects the picks even if the
  // student swipes forward instead of tapping Continue. We persist to memory
  // (signed-in only) AND to onboardingSubjectsProvider, which always holds the
  // live picks so the anonymous demo step can match them.
  void _toggle(String tag) {
    setState(() => _selected.contains(tag) ? _selected.remove(tag) : _selected.add(tag));
    ref.read(onboardingSubjectsProvider.notifier).state = _selected.toList();
    ref.read(memoryStoreProvider).setProfile(subjects: _selected.toList(), level: 'JC2');
  }

  Future<void> _continue() async {
    ref.read(onboardingSubjectsProvider.notifier).state = _selected.toList();
    await ref.read(memoryStoreProvider).setProfile(subjects: _selected.toList(), level: 'JC2');
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final subjects = _byLevel[_level]!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: Illustration('subjects', size: 84)),
              const SizedBox(height: 14),
              Text('Which subjects are you taking?', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text('Select all that apply, grouped by level.',
                        style: TextStyle(color: t.textMuted, height: 1.5)),
                  ),
                  if (_selected.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(999)),
                      child: Text('${_selected.length} selected',
                          style: TextStyle(color: t.onPrimarySoft, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _LevelTabs(value: _level, onChanged: (v) => setState(() => _level = v)),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: subjects.map((s) {
                      final tag = '$_level $s';
                      return _Chip(label: s, selected: _selected.contains(tag), onTap: () => _toggle(tag));
                    }).toList(),
                  ),
                ),
              ),
          const SizedBox(height: 12),
          _CoverageNote(t: t),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selected.isEmpty ? null : _continue,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelTabs extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _LevelTabs({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: t.surfaceMuted, borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: _levels.map((lv) {
          final on = lv == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(lv),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: on ? scheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: on ? Border.all(color: t.border) : null,
                ),
                child: Text(lv,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: on ? scheme.primary : t.textMuted)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.fromLTRB(selected ? 14 : 16, 12, 16, 12),
        decoration: BoxDecoration(
          color: selected ? t.primarySoft : scheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? scheme.primary : t.border, width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded, size: 18, color: t.onPrimarySoft),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? t.onPrimarySoft : scheme.onSurface)),
          ],
        ),
      ),
    );
  }
}

class _CoverageNote extends StatelessWidget {
  final AppTokens t;
  const _CoverageNote({required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.surfaceMuted, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: t.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Our data is richest for the sciences, maths, and economics. You can still ask about any subject, but answers for more niche ones will be less grounded.',
              style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
