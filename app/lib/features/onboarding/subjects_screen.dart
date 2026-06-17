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
    // tag subjects with the chosen level (e.g. "H2 Chemistry") for the backend
    final tagged = _selected.map((s) => s == 'General Paper' ? 'H1 $s' : '$_level $s').toList();
    await memory.setProfile(subjects: tagged, level: 'JC2');
    if (mounted) context.go('/live_taste');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/welcome'),
        ),
        title: const Text('JCAI'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What are you studying?', style: text.headlineSmall),
              const SizedBox(height: 6),
              Text('I’ll tailor every explanation to your subjects and level.',
                  style: TextStyle(color: t.textMuted, height: 1.5)),
              const SizedBox(height: 20),
              _LevelToggle(value: _level, tokens: t, onChanged: (v) => setState(() => _level = v)),
              const SizedBox(height: 22),
              Row(
                children: [
                  Text('YOUR SUBJECTS',
                      style: TextStyle(
                          color: t.textMuted, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _selected.isEmpty
                        ? const SizedBox.shrink()
                        : Container(
                            key: ValueKey(_selected.length),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(999)),
                            child: Text('${_selected.length} selected',
                                style: TextStyle(color: t.onPrimarySoft, fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: LayoutBuilder(builder: (ctx, c) {
                    final w = (c.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _subjects.map((s) {
                        final on = _selected.contains(s);
                        return SizedBox(
                          width: w,
                          child: GestureDetector(
                            onTap: () => setState(() => on ? _selected.remove(s) : _selected.add(s)),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: on ? t.primarySoft : scheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: on ? scheme.primary : t.border, width: on ? 1.5 : 1),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(s,
                                        style: TextStyle(
                                            color: on ? t.onPrimarySoft : null, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  Icon(on ? Icons.check_circle_rounded : Icons.circle_outlined,
                                      size: 18, color: on ? t.onPrimarySoft : t.border),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.cloud_done_outlined, size: 15, color: t.textMuted),
                const SizedBox(width: 6),
                Text('Saved on your device', style: TextStyle(color: t.textMuted, fontSize: 12.5)),
              ]),
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
    final scheme = Theme.of(context).colorScheme;
    Widget seg(String v) {
      final on = value == v;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: on ? scheme.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: on ? Border.all(color: tokens.border) : null,
            ),
            child: Text(v,
                style: TextStyle(fontWeight: FontWeight.w700, color: on ? scheme.primary : tokens.textMuted)),
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
