import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../state/app_state.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  String? _section(String md, String heading) {
    final m = RegExp('## $heading\\n([\\s\\S]*?)(?=\\n## |\$)').firstMatch(md);
    return m?.group(1)?.trim();
  }

  List<String> _bullets(String? block) {
    if (block == null) return [];
    return block
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'^[-*]\s*'), '').trim())
        .where((l) => l.isNotEmpty && !l.startsWith('- '))
        .toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final md = ref.watch(memoryStoreProvider).markdown;

    final profile = _section(md, 'Profile') ?? '';
    final subjects = RegExp(r'Subjects:\s*(.+)').firstMatch(profile)?.group(1)?.trim();
    final struggling = _bullets(_section(md, 'Struggling topics'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.onPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your profile', style: text.titleLarge),
                    if (subjects != null)
                      Text(subjects, style: TextStyle(color: t.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 24),
            Text('Struggling topics', style: text.titleMedium),
            const SizedBox(height: 10),
            if (struggling.isEmpty)
              Text('Nothing yet. As you study, I will note topics you find tricky here.',
                  style: TextStyle(color: t.textMuted, height: 1.5))
            else
              ...struggling.map((s) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: t.border),
                    ),
                    child: Text(s),
                  )),
            const SizedBox(height: 24),
            Row(children: [
              Icon(Icons.lock_outline_rounded, size: 15, color: t.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Your data is private and secure, used only to tutor you.',
                    style: TextStyle(color: t.textMuted, fontSize: 12)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
