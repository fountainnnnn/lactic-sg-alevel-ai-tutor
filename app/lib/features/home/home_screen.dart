import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../data/conversation_store.dart';
import '../../state/app_state.dart';
import '../../state/chat_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _dismissed = false;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String? _firstStruggle(String md) {
    final m = RegExp(r'## Struggling topics\n- (.+)').firstMatch(md);
    if (m == null) return null;
    var s = m.group(1)!;
    s = s.replaceFirst(RegExp(r'^\d{4}-\d{2}-\d{2}\s+'), '').replaceAll(RegExp(r'\s*\(.*\)$'), '');
    return s.trim();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final md = ref.watch(memoryStoreProvider).markdown;
    final name = RegExp(r'Name:\s*(.+)').firstMatch(md)?.group(1)?.trim();
    final struggle = _firstStruggle(md);
    final recents = ref.watch(conversationStoreProvider).list().take(3).toList();
    final streak = ref.watch(streakStoreProvider).current();

    return Scaffold(
      appBar: AppBar(
        title: const Text('JCAI'),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings')),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(name == null ? _greeting() : '${_greeting()}, $name', style: theme.textTheme.displaySmall),
            const SizedBox(height: 18),

            // Ask anything card
            GestureDetector(
              onTap: () => context.go('/chat'),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(FF.rCard),
                  border: Border.all(color: t.border),
                ),
                child: Column(children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(color: t.primarySoft, shape: BoxShape.circle),
                    child: Icon(Icons.chat_bubble_outline_rounded, color: t.onPrimarySoft, size: 30),
                  ),
                  const SizedBox(height: 14),
                  Text('Ask anything', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Snap a photo of a question or type your study query.',
                      textAlign: TextAlign.center, style: TextStyle(color: t.textMuted)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.go('/chat'),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Type query'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(52, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FF.rButton)),
                        ),
                        onPressed: () => context.go('/chat'),
                        child: Icon(Icons.photo_camera_outlined, color: scheme.primary),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),

            // Memory-driven suggestion (real, from struggling topics)
            if (struggle != null && !_dismissed) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: t.primarySoft.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(FF.rCard),
                  border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.lightbulb_outline_rounded, color: t.onPrimarySoft, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(TextSpan(
                          style: TextStyle(color: scheme.onSurface, height: 1.4),
                          children: [
                            const TextSpan(text: 'You\'ve been working on '),
                            TextSpan(text: struggle, style: TextStyle(fontWeight: FontWeight.w700, color: t.onPrimarySoft)),
                            const TextSpan(text: '. Want to drill it?'),
                          ],
                        )),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () {
                          ref.read(chatControllerProvider.notifier)
                              .send('Give me a practice question on $struggle');
                          context.go('/chat');
                        },
                        child: const Text('Start drill'),
                      ),
                      const SizedBox(width: 4),
                      TextButton(onPressed: () => setState(() => _dismissed = true), child: const Text('Dismiss')),
                    ]),
                  ],
                ),
              ),
            ],

            // Recent conversations (real)
            if (recents.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Pick up where you left off', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              ...recents.map((c) => _RecentCard(conv: c, t: t)),
            ],

            // Stats: streak (real) + mastery (Premium teaser)
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _Stat(label: 'Day streak', value: '$streak', icon: Icons.local_fire_department_rounded, t: t)),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/premium'),
                  child: _Stat(label: 'Mastery', value: 'Premium', icon: Icons.lock_outline_rounded, t: t, muted: true),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _RecentCard extends ConsumerWidget {
  final Conversation conv;
  final AppTokens t;
  const _RecentCard({required this.conv, required this.t});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          ref.read(chatControllerProvider.notifier).load(conv);
          context.go('/chat');
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.border),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(11)),
              child: Icon(Icons.history_edu_outlined, color: t.onPrimarySoft, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (conv.subject.isNotEmpty)
                    Text(conv.subject.toUpperCase(),
                        style: TextStyle(color: t.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  Text(conv.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: t.textMuted),
          ]),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final AppTokens t;
  final bool muted;
  const _Stat({required this.label, required this.value, required this.icon, required this.t, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.surfaceMuted, borderRadius: BorderRadius.circular(FF.rCard)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: muted ? t.textMuted : Theme.of(context).colorScheme.primary),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              Text(label, style: TextStyle(color: t.textMuted, fontSize: 12.5)),
            ],
          ),
        ],
      ),
    );
  }
}
