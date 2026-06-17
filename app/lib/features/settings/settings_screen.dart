import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../state/app_state.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            Text('Appearance', style: text.titleMedium),
            const SizedBox(height: 8),
            RadioGroup<ThemeMode>(
              groupValue: settings.themeMode,
              onChanged: (m) => notifier.setThemeMode(m ?? ThemeMode.system),
              child: const Column(children: [
                _ModeTile(mode: ThemeMode.system, label: 'System'),
                _ModeTile(mode: ThemeMode.light, label: 'Light'),
                _ModeTile(mode: ThemeMode.dark, label: 'Dark'),
              ]),
            ),
            const SizedBox(height: 20),
            Text('Default answer style', style: text.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'direct', label: Text('Just answer')),
                ButtonSegment(value: 'coach', label: Text('Guide me')),
              ],
              selected: {settings.answerStyle},
              onSelectionChanged: (s) => notifier.setAnswerStyle(s.first),
            ),
            const SizedBox(height: 8),
            Text('Just answer leads with the answer. Guide me walks you through it.',
                style: TextStyle(color: t.textMuted, fontSize: 12.5)),
            const SizedBox(height: 28),
            Text('About', style: text.titleMedium),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('JCAI'),
              subtitle: Text('A-Level study tutor · v0.1', style: TextStyle(color: t.textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final ThemeMode mode;
  final String label;
  const _ModeTile({required this.mode, required this.label});
  @override
  Widget build(BuildContext context) {
    return RadioListTile<ThemeMode>(
      contentPadding: EdgeInsets.zero,
      value: mode,
      title: Text(label),
    );
  }
}
