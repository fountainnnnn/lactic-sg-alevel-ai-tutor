import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final email = Supabase.instance.client.auth.currentUser?.email;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                    child: Icon(Icons.person_rounded, color: scheme.onPrimary, size: 44),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Custom photos are coming soon.'))),
                    child: const Text('Change photo'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _Label('Name'),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'Your name'),
            ),
            const SizedBox(height: 20),
            const _Label('Email'),
            const SizedBox(height: 8),
            TextField(
              readOnly: true,
              decoration: InputDecoration(hintText: email ?? 'Sign in to set an email'),
            ),
            const SizedBox(height: 8),
            Text('Email is tied to your sign-in method.', style: TextStyle(color: t.textMuted, fontSize: 12.5)),
            const SizedBox(height: 24),
            const _Label('Subjects & level'),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'H1', label: Text('H1')),
                ButtonSegment(value: 'H2', label: Text('H2')),
                ButtonSegment(value: 'H3', label: Text('H3')),
              ],
              selected: {_level},
              onSelectionChanged: (s) => setState(() => _level = s.first),
            ),
            const SizedBox(height: 14),
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
                      color: on ? t.primarySoft : scheme.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: on ? scheme.primary : t.border),
                    ),
                    child: Text(s,
                        style: TextStyle(color: on ? t.onPrimarySoft : null, fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            FilledButton(onPressed: _save, child: const Text('Save changes')),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
            color: context.tokens.textMuted, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8),
      );
}
