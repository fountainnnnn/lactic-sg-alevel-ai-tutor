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
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final signedIn = Supabase.instance.client.auth.currentSession != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _Card(
              label: 'Appearance',
              children: [
                _Segmented<ThemeMode>(
                  value: settings.themeMode,
                  options: const [
                    (ThemeMode.system, 'System'),
                    (ThemeMode.light, 'Light'),
                    (ThemeMode.dark, 'Dark'),
                  ],
                  onChanged: notifier.setThemeMode,
                ),
              ],
            ),
            _Card(
              label: 'Tutor preferences',
              children: [
                const _RowTitle('Default answer style'),
                const SizedBox(height: 10),
                _Segmented<String>(
                  value: settings.answerStyle,
                  options: const [('direct', 'Just answer'), ('coach', 'Guide me')],
                  onChanged: notifier.setAnswerStyle,
                ),
                const SizedBox(height: 10),
                const _Hint('Just answer leads with the answer. Guide me walks you through it.'),
              ],
            ),
            _Card(
              label: 'Account',
              tight: true,
              children: [
                const _Row(icon: Icons.workspace_premium_outlined, label: 'JCAI Premium', route: '/premium'),
                const _Row(icon: Icons.person_outline_rounded, label: 'Edit profile', route: '/edit-profile'),
                const _Row(icon: Icons.notifications_none_rounded, label: 'Notifications', route: '/notifications'),
                if (signedIn)
                  _Row(
                    icon: Icons.logout_rounded,
                    label: 'Sign out',
                    onTap: () => Supabase.instance.client.auth.signOut(),
                  )
                else
                  const _Row(icon: Icons.login_rounded, label: 'Sign in', route: '/signin'),
              ],
            ),
            const _Card(
              label: 'More',
              tight: true,
              children: [
                _Row(icon: Icons.help_outline_rounded, label: 'Help & FAQ', route: '/help'),
                _Row(icon: Icons.lock_outline_rounded, label: 'Privacy Policy', route: '/privacy'),
                _Row(icon: Icons.description_outlined, label: 'Terms & Conditions', route: '/terms'),
                _Row(icon: Icons.info_outline_rounded, label: 'About JCAI', route: '/about'),
                _Row(icon: Icons.delete_outline_rounded, label: 'Delete account', route: '/delete-account', danger: true),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: Text('JCAI · v1.0.0',
                  style: TextStyle(color: context.tokens.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A grouped settings section: uppercase label + a bordered surface card.
class _Card extends StatelessWidget {
  final String label;
  final List<Widget> children;
  final bool tight; // tight = list rows (no inner padding); else padded content
  const _Card({required this.label, required this.children, this.tight = false});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(label.toUpperCase(),
                style: TextStyle(color: t.textMuted, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          ),
          Container(
            width: double.infinity,
            padding: tight ? const EdgeInsets.symmetric(horizontal: 6) : const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(FF.rCard),
              border: Border.all(color: t.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }
}

class _RowTitle extends StatelessWidget {
  final String text;
  const _RowTitle(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15));
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(color: context.tokens.textMuted, fontSize: 12.5, height: 1.4));
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? route;
  final VoidCallback? onTap;
  final bool danger;
  const _Row({required this.icon, required this.label, this.route, this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? context.tokens.danger : null;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      trailing: Icon(Icons.chevron_right_rounded, size: 20, color: context.tokens.textMuted),
      onTap: onTap ?? (route != null ? () => context.push(route!) : null),
    );
  }
}

/// A pill segmented control matching the chat composer's toggle.
class _Segmented<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  const _Segmented({required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: t.surfaceMuted, borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: options.map((o) {
          final on = o.$1 == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: on ? scheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: on ? Border.all(color: t.border) : null,
                ),
                child: Text(o.$2,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: on ? scheme.primary : t.textMuted)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
