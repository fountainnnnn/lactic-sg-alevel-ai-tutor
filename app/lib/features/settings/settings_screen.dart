import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/tokens.dart';
import '../../state/app_state.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _pickAnswerStyle(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsProvider.notifier);
    final current = ref.read(settingsProvider).answerStyle;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in const [('direct', 'Just answer', 'Leads with the answer.'), ('coach', 'Guide me', 'Walks you through it step by step.')])
              ListTile(
                title: Text(o.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(o.$3),
                trailing: current == o.$1
                    ? Icon(Icons.check_rounded, color: Theme.of(ctx).colorScheme.primary)
                    : null,
                onTap: () {
                  notifier.setAnswerStyle(o.$1);
                  Navigator.of(ctx).pop();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final signedIn = Supabase.instance.client.auth.currentSession != null;
    final answerLabel = settings.answerStyle == 'coach' ? 'Guide me' : 'Just answer';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            _Section(
              label: 'Appearance',
              child: _ThemePicker(value: settings.themeMode, onChanged: notifier.setThemeMode),
            ),
            _Section(
              label: 'Preferences',
              tight: true,
              child: Column(children: [
                _NavRow(label: 'Notifications', onTap: () => context.push('/notifications')),
                _Divider(),
                _NavRow(label: 'Default answer style', value: answerLabel, onTap: () => _pickAnswerStyle(context, ref)),
              ]),
            ),
            _Section(
              label: 'Account',
              tight: true,
              child: Column(children: [
                _NavRow(label: 'Manage Subscription', onTap: () => context.push('/subscription')),
                _Divider(),
                _NavRow(label: 'Privacy', onTap: () => context.push('/privacy')),
                _Divider(),
                _NavRow(label: 'Help', onTap: () => context.push('/help')),
                _Divider(),
                _NavRow(label: 'About', onTap: () => context.push('/about')),
              ]),
            ),
            _Section(
              tight: true,
              child: Column(children: [
                if (signedIn)
                  _NavRow(label: 'Sign out', icon: Icons.logout_rounded, onTap: () => Supabase.instance.client.auth.signOut())
                else
                  _NavRow(label: 'Sign in', icon: Icons.login_rounded, onTap: () => context.push('/signin')),
                _Divider(),
                _NavRow(label: 'Delete account', icon: Icons.delete_outline_rounded, danger: true, onTap: () => context.push('/delete-account')),
              ]),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text('Lactic · v1.0.0',
                  style: TextStyle(color: context.tokens.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String? label;
  final Widget child;
  final bool tight;
  const _Section({this.label, required this.child, this.tight = false});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(label!.toUpperCase(),
                  style: TextStyle(color: t.textMuted, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            ),
          Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            padding: tight ? const EdgeInsets.symmetric(horizontal: 6) : const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(FF.rCard),
              border: Border.all(color: t.border),
            ),
            // Transparent Material so list-tile ripples paint over the card
            // instead of being hidden by its background color.
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: context.tokens.border, indent: 10, endIndent: 10);
}

class _NavRow extends StatelessWidget {
  final String label;
  final String? value;
  final IconData? icon;
  final bool danger;
  final VoidCallback onTap;
  const _NavRow({required this.label, this.value, this.icon, this.danger = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = danger ? t.danger : null;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      leading: icon != null ? Icon(icon, color: color, size: 22) : null,
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5, color: color)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) Text(value!, style: TextStyle(color: t.textMuted, fontSize: 14)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 20, color: t.textMuted),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Three icon boxes: Light / Dark / System.
class _ThemePicker extends StatelessWidget {
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const opts = [
      (ThemeMode.light, Icons.light_mode_outlined, 'Light'),
      (ThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
      (ThemeMode.system, Icons.desktop_windows_outlined, 'System'),
    ];
    return Row(
      children: [
        for (var i = 0; i < opts.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: _ThemeBox(
            selected: value == opts[i].$1,
            icon: opts[i].$2,
            label: opts[i].$3,
            onTap: () => onChanged(opts[i].$1),
          )),
        ],
      ],
    );
  }
}

class _ThemeBox extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ThemeBox({required this.selected, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? t.primarySoft : t.surfaceMuted,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: selected ? t.onPrimarySoft : t.textMuted),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: selected ? t.onPrimarySoft : t.textMuted)),
          ],
        ),
      ),
    );
  }
}
