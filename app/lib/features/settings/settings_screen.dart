import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
            Text('Account', style: text.titleMedium),
            const SizedBox(height: 4),
            const _Link(icon: Icons.workspace_premium_outlined, label: 'JCAI Premium', route: '/premium'),
            if (Supabase.instance.client.auth.currentSession == null)
              const _Link(icon: Icons.login_rounded, label: 'Sign in', route: '/signin')
            else
              _Link(
                icon: Icons.logout_rounded,
                label: 'Sign out',
                onTap: () => Supabase.instance.client.auth.signOut(),
              ),
            const _Link(icon: Icons.person_outline_rounded, label: 'Edit profile', route: '/edit-profile'),
            const _Link(icon: Icons.notifications_none_rounded, label: 'Notifications', route: '/notifications'),
            const SizedBox(height: 20),
            Text('More', style: text.titleMedium),
            const SizedBox(height: 4),
            const _Link(icon: Icons.help_outline_rounded, label: 'Help & FAQ', route: '/help'),
            const _Link(icon: Icons.lock_outline_rounded, label: 'Privacy Policy', route: '/privacy'),
            const _Link(icon: Icons.description_outlined, label: 'Terms & Conditions', route: '/terms'),
            const _Link(icon: Icons.info_outline_rounded, label: 'About JCAI', route: '/about'),
            const _Link(icon: Icons.delete_outline_rounded, label: 'Delete account', route: '/delete-account', danger: true),
          ],
        ),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? route;
  final VoidCallback? onTap;
  final bool danger;
  const _Link({required this.icon, required this.label, this.route, this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? context.tokens.danger : null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap ?? (route != null ? () => context.push(route!) : null),
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
