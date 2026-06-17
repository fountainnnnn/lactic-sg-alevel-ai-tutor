import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../state/app_state.dart';

const _allSubjects = [
  'Mathematics', 'Physics', 'Chemistry', 'Biology', 'Economics',
  'Geography', 'History', 'Literature', 'Computing', 'General Paper',
];

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name;
  String _level = 'H2';
  final _selected = <String>{};

  @override
  void initState() {
    super.initState();
    final md = ref.read(memoryStoreProvider).markdown;
    _name = TextEditingController(
        text: RegExp(r'Name:\s*(.+)').firstMatch(md)?.group(1)?.trim() ?? '');
    for (final s in _allSubjects) {
      if (md.contains(s)) _selected.add(s);
    }
    if (md.contains('H1 ')) _level = 'H1';
    if (md.contains('H3 ')) _level = 'H3';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tagged = _selected.map((s) => s == 'General Paper' ? 'H1 $s' : '$_level $s').toList();
    await ref.read(memoryStoreProvider).setProfile(
        name: _name.text.trim(), subjects: tagged, level: 'JC2');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text('Name', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(controller: _name, decoration: const InputDecoration(hintText: 'Your name (optional)')),
            const SizedBox(height: 20),
            Text('Level', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'H1', label: Text('H1')),
                ButtonSegment(value: 'H2', label: Text('H2')),
                ButtonSegment(value: 'H3', label: Text('H3')),
              ],
              selected: {_level},
              onSelectionChanged: (s) => setState(() => _level = s.first),
            ),
            const SizedBox(height: 20),
            Text('Subjects', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _allSubjects.map((s) {
                final on = _selected.contains(s);
                return GestureDetector(
                  onTap: () => setState(() => on ? _selected.remove(s) : _selected.add(s)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: on ? t.primarySoft : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: on ? Theme.of(context).colorScheme.primary : t.border),
                    ),
                    child: Text(s,
                        style: TextStyle(
                            color: on ? t.onPrimarySoft : null, fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
