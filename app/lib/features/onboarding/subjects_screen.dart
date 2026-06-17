import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../state/app_state.dart';

const _subjects = [
  'Mathematics',
  'Physics',
  'Chemistry',
  'Biology',
  'Economics',
  'Geography',
  'History',
  'Literature',
  'Computing',
  'General Paper',
];

class SubjectsScreen extends ConsumerStatefulWidget {
  const SubjectsScreen({super.key});
  @override
  ConsumerState<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends ConsumerState<SubjectsScreen> {
  String _level = 'H2';
  final _selected = <String>{};

  Future<void> _continue() async {
    final memory = ref.read(memoryStoreProvider);
    await memory.setProfile(subjects: _selected.toList(), level: 'JC2');
    await ref.read(prefsProvider).setBool('onboarding_done', true);
    ref.read(onboardingDoneProvider.notifier).state = true;
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Step 1 of 2')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What are you studying?', style: text.titleLarge),
              const SizedBox(height: 6),
              Text('I will tailor every explanation to your subjects and level.',
                  style: TextStyle(color: t.textMuted, height: 1.5)),
              const SizedBox(height: 18),
              _LevelToggle(value: _level, tokens: t, onChanged: (v) => setState(() => _level = v)),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _subjects.map((s) {
                      final on = _selected.contains(s);
                      return GestureDetector(
                        onTap: () => setState(() => on ? _selected.remove(s) : _selected.add(s)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: on ? t.primarySoft : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: on ? Theme.of(context).colorScheme.primary : t.border),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (on) ...[
                              Icon(Icons.check_rounded, size: 16, color: t.onPrimarySoft),
                              const SizedBox(width: 6),
                            ],
                            Text(s,
                                style: TextStyle(
                                    color: on ? t.onPrimarySoft : null,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              FilledButton(
                onPressed: _selected.isEmpty ? null : _continue,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelToggle extends StatelessWidget {
  final String value;
  final AppTokens tokens;
  final ValueChanged<String> onChanged;
  const _LevelToggle({required this.value, required this.tokens, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget seg(String v) {
      final on = value == v;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(v),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: on ? Theme.of(context).colorScheme.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: on ? Border.all(color: tokens.border) : null,
            ),
            child: Text(v,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: on ? tokens.onPrimarySoft : tokens.textMuted)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: tokens.surfaceMuted, borderRadius: BorderRadius.circular(999)),
      child: Row(children: [seg('H1'), seg('H2'), seg('H3')]),
    );
  }
}
