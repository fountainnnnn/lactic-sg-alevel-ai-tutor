import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/tokens.dart';
import '../../state/app_state.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  String? _section(String md, String heading) {
    final m = RegExp('## ${RegExp.escape(heading)}[^\n]*\\n([\\s\\S]*?)(?=\\n## |\$)').firstMatch(md);
    return m?.group(1)?.trim();
  }

  List<String> _lines(String? block) {
    if (block == null) return [];
    return block
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'^[-*]\s*'), '').trim())
        .map((l) => l.replaceFirst(RegExp(r'^\d{4}-\d{2}-\d{2}\s+'), ''))
        .where((l) => l.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final md = ref.watch(memoryStoreProvider).markdown;

    final profile = _section(md, 'Profile') ?? '';
    final name = RegExp(r'Name:\s*(.+)').firstMatch(profile)?.group(1)?.trim();
    final subjectsRaw = RegExp(r'Subjects:\s*(.+)').firstMatch(profile)?.group(1)?.trim();
    final subjects = subjectsRaw?.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList() ?? [];
    final email = Supabase.instance.client.auth.currentUser?.email;

    // "What I remember" bullets, distilled from memory sections.
    final bullets = <String>[];
    if (subjectsRaw != null) bullets.add('Studying $subjectsRaw.');
    bullets.addAll(_lines(_section(md, 'Struggling topics')).take(2));
    bullets.addAll(_lines(_section(md, 'Explanation preferences')).take(1));
    bullets.addAll(_lines(_section(md, 'Notes from tutor')).take(1));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: scheme.primary,
                  child: Icon(Icons.person_rounded, color: scheme.onPrimary, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name ?? 'Your profile', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 2),
                      Text(email ?? 'Not signed in', style: TextStyle(color: t.textMuted, fontSize: 14)),
                    ],
                  ),
                ),
                _IconBox(icon: Icons.edit_outlined, onTap: () => context.push('/edit-profile')),
              ],
            ),

            if (subjects.isNotEmpty) ...[
              const _Label('Subjects'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: subjects
                    .map((s) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(999)),
                          child: Text(s, style: TextStyle(color: t.onPrimarySoft, fontWeight: FontWeight.w600)),
                        ))
                    .toList(),
              ),
            ],

            const SizedBox(height: 22),
            // Upgrade card
            InkWell(
              borderRadius: BorderRadius.circular(FF.rCard),
              onTap: () => context.push('/premium'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(FF.rCard)),
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(18)),
                    child: Icon(Icons.workspace_premium_rounded, color: scheme.onPrimary, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Upgrade to Lactic Plus',
                            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text('Marks Coach, Mastery Tracking, Photo Upload',
                            style: TextStyle(color: t.onPrimarySoft, fontSize: 13)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: t.onPrimarySoft),
                ]),
              ),
            ),

            const SizedBox(height: 22),
            Row(children: [
              const Expanded(child: _Label('What I remember about you', topPad: 0)),
              GestureDetector(
                onTap: () => context.push('/edit-profile'),
                child: Text('Edit', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(FF.rCard),
                border: Border.all(color: t.border),
              ),
              child: bullets.isEmpty
                  ? Text('As you study, I will note what you are working on and how you like things explained here.',
                      style: TextStyle(color: t.textMuted, height: 1.5))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < bullets.length; i++)
                          Padding(
                            padding: EdgeInsets.only(bottom: i == bullets.length - 1 ? 0 : 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 8, right: 12),
                                  child: Container(width: 6, height: 6, decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle)),
                                ),
                                Expanded(child: Text(bullets[i], style: TextStyle(color: scheme.onSurface, height: 1.45, fontSize: 15.5))),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),

            const SizedBox(height: 22),
            const _Label('Account', topPad: 0),
            const SizedBox(height: 10),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(FF.rCard),
                border: Border.all(color: t.border),
              ),
              // Transparent Material so the tiles' tap ripples paint over the
              // card instead of being hidden by its background.
              child: Material(
                type: MaterialType.transparency,
                child: Column(children: [
                  _Row(label: 'Settings', onTap: () => context.push('/settings')),
                  _Div(t),
                  _Row(label: 'Notification Settings', onTap: () => context.push('/notifications')),
                  _Div(t),
                  _Row(label: 'Help', onTap: () => context.push('/help')),
                  _Div(t),
                  _Row(label: 'Privacy Policy', onTap: () => context.push('/privacy')),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final double topPad;
  const _Label(this.text, {this.topPad = 22});
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: topPad, bottom: 12),
        child: Text(text.toUpperCase(),
            style: TextStyle(color: context.tokens.textMuted, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
      );
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBox({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: t.surfaceMuted, borderRadius: BorderRadius.circular(16)),
        child: Icon(icon, size: 20, color: t.textMuted),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Row({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
      trailing: Icon(Icons.chevron_right_rounded, size: 20, color: t.textMuted),
      onTap: onTap,
    );
  }
}

class _Div extends StatelessWidget {
  final AppTokens t;
  const _Div(this.t);
  @override
  Widget build(BuildContext context) => Divider(height: 1, color: t.border, indent: 16, endIndent: 16);
}
