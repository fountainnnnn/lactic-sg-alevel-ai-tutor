import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../data/conversation_store.dart';
import '../../state/app_state.dart';
import '../../state/chat_controller.dart';
import '../premium/plans.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _ask = TextEditingController();
  bool _dismissed = false;

  @override
  void dispose() {
    _ask.dispose();
    super.dispose();
  }

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

  void _go(String text) {
    if (text.trim().isNotEmpty) {
      ref.read(chatControllerProvider.notifier).send(text.trim());
    }
    context.go('/chat');
  }

  static const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String _fmt(DateTime d) => '${d.day} ${_mon[d.month - 1]} ${d.year}';

  Future<void> _editExam() async {
    final prefs = ref.read(prefsProvider);
    final labelCtrl = TextEditingController(text: prefs.getString('exam_label') ?? '');
    DateTime? date = DateTime.tryParse(prefs.getString('exam_date') ?? '');
    final hadDate = prefs.getString('exam_date') != null;
    await showModalBottomSheet(
      context: context,
      // Use the ROOT navigator so the sheet (and its scrim) cover the whole
      // screen including the shell's bottom nav bar. Without this the sheet is
      // confined to the Home page's inner navigator — it renders behind the
      // opaque nav bar (looking empty) and only dims the page, not the nav.
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final t = ctx.tokens;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (ctx, setSheet) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Exam countdown', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Track the days to your next big paper.', style: TextStyle(color: t.textMuted)),
                  const SizedBox(height: 16),
                  TextField(controller: labelCtrl, decoration: const InputDecoration(hintText: 'e.g. H2 Chemistry Prelim')),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: Text(date == null ? 'Pick a date' : _fmt(date!)),
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date ?? now.add(const Duration(days: 30)),
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 365 * 3)),
                      );
                      if (picked != null) setSheet(() => date = picked);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: date == null
                            ? null
                            : () async {
                                await prefs.setString('exam_date', date!.toIso8601String());
                                final label = labelCtrl.text.trim();
                                await prefs.setString('exam_label', label.isEmpty ? 'A-Levels' : label);
                                if (ctx.mounted) Navigator.of(ctx).pop();
                              },
                        child: const Text('Save'),
                      ),
                    ),
                    if (hadDate) ...[
                      const SizedBox(width: 12),
                      // Must be a flex child (Expanded): a bare Material button as
                      // a non-flex child gets measured with unbounded width and
                      // throws "BoxConstraints forces an infinite width", which
                      // collapsed the whole sheet.
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await prefs.remove('exam_date');
                            await prefs.remove('exam_label');
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                          child: const Text('Remove'),
                        ),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
    labelCtrl.dispose();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final prefs = ref.watch(prefsProvider);
    final md = ref.watch(memoryStoreProvider).markdown;
    final name = RegExp(r'Name:\s*(.+)').firstMatch(md)?.group(1)?.trim();
    final struggle = _firstStruggle(md);
    final recents = ref.watch(conversationStoreProvider).list().take(3).toList();
    final streak = ref.watch(streakStoreProvider).current();
    final rank = ref.watch(tierRankProvider);
    final nextTier = Subscriptions.nextTier(rank);

    // Exam countdown (optional; hidden until an exam date is set).
    final examIso = prefs.getString('exam_date');
    final examLabel = prefs.getString('exam_label');
    int? daysLeft;
    if (examIso != null) {
      final d = DateTime.tryParse(examIso);
      if (d != null) {
        final now = DateTime.now();
        daysLeft = DateTime(d.year, d.month, d.day)
            .difference(DateTime(now.year, now.month, now.day))
            .inDays;
        if (daysLeft < 0) daysLeft = null;
      }
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            // Greeting + avatar
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (name != null && name.trim().isNotEmpty) ...[
                        Text('${_greeting()},', style: TextStyle(color: t.textMuted, fontSize: 18)),
                        Text(name, style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
                      ] else
                        // No name yet — make the greeting the headline (no awkward "there").
                        Text(_greeting(), style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/edit-profile'),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: scheme.primary,
                    child: Icon(Icons.person_rounded, color: scheme.onPrimary, size: 30),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Exam countdown (tap to set or edit)
            GestureDetector(
              onTap: _editExam,
              child: (daysLeft != null && examLabel != null)
                  ? Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(FF.rCard)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('A-LEVEL COUNTDOWN',
                                    style: TextStyle(color: t.onPrimarySoft, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                                const SizedBox(height: 4),
                                Text(examLabel, style: TextStyle(color: t.onPrimarySoft, fontSize: 17, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('$daysLeft',
                                  style: TextStyle(color: scheme.primary, fontSize: 40, fontWeight: FontWeight.w800, height: 1)),
                              Text(daysLeft == 1 ? 'day left' : 'days left', style: TextStyle(color: t.onPrimarySoft, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: t.surfaceMuted, borderRadius: BorderRadius.circular(FF.rCard)),
                      child: Row(children: [
                        Icon(Icons.event_rounded, color: t.textMuted),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Set your exam countdown',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface)),
                              const SizedBox(height: 2),
                              Text('Add your next exam date to track the days left.',
                                  style: TextStyle(color: t.textMuted, fontSize: 13)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: t.textMuted),
                      ]),
                    ),
            ),
            const SizedBox(height: 16),

            // Ask anything
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(FF.rCard),
                border: Border.all(color: t.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ask anything', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _SquareIcon(icon: Icons.photo_camera_outlined, onTap: () => _go('')),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _ask,
                          textInputAction: TextInputAction.send,
                          decoration: const InputDecoration(hintText: 'Type a question or topic...'),
                          onSubmitted: _go,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FF.rButton)),
                          ),
                          onPressed: () => _go(_ask.text),
                          child: const Icon(Icons.send_rounded, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Memory nudge
            if (struggle != null && !_dismissed) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(FF.rCard),
                  border: Border.all(color: t.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('MEMORY NUDGE',
                          style: TextStyle(color: t.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _dismissed = true),
                        child: Icon(Icons.close_rounded, size: 18, color: t.textMuted),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Text.rich(TextSpan(
                      style: TextStyle(color: scheme.onSurface, height: 1.4, fontSize: 16),
                      children: [
                        const TextSpan(text: 'You have been working on '),
                        TextSpan(text: struggle, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const TextSpan(text: '. Want to drill it?'),
                      ],
                    )),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _go('Give me a practice question on $struggle'),
                          child: const Text('Start drill'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _dismissed = true),
                          child: const Text('Dismiss'),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ],

            // Stats
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _Stat(label: 'Day streak', value: '$streak', unit: 'days in a row', icon: Icons.local_fire_department_rounded, t: t)),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/premium'),
                  child: rank == 0
                      // Free: the card is an upsell — show the locked state.
                      ? _Stat(label: 'Plan', value: 'Free', unit: 'Upgrade', icon: Icons.lock_outline_rounded, t: t, muted: true)
                      // Paid: show what they have; Max is the top tier, lower
                      // tiers nudge the next upgrade.
                      : _Stat(
                          label: 'Plan',
                          value: Subscriptions.tierShort(rank),
                          unit: nextTier == null ? 'Top tier' : 'Upgrade to ${Subscriptions.tierShort(rank + 1)}',
                          icon: Icons.workspace_premium_rounded,
                          t: t,
                          muted: nextTier != null,
                        ),
                ),
              ),
            ]),

            // Recents
            if (recents.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: Text('Pick up where you left off', style: theme.textTheme.titleMedium)),
                GestureDetector(
                  onTap: () => context.go('/history'),
                  child: Text('See all', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 10),
              ...recents.map((c) => _RecentCard(conv: c, t: t)),
            ],
          ],
        ),
      ),
    );
  }

}

class _SquareIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SquareIcon({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      borderRadius: BorderRadius.circular(FF.rButton),
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: t.surfaceMuted, borderRadius: BorderRadius.circular(FF.rButton)),
        child: Icon(icon, color: t.textMuted),
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(FF.rCard),
        onTap: () {
          ref.read(chatControllerProvider.notifier).load(conv);
          context.go('/chat');
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(FF.rCard),
            border: Border.all(color: t.border),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conv.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  if (conv.subject.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(999)),
                      child: Text(conv.subject,
                          style: TextStyle(color: t.onPrimarySoft, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
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
  final String unit;
  final IconData icon;
  final AppTokens t;
  final bool muted;
  const _Stat({required this.label, required this.value, required this.unit, required this.icon, required this.t, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.surfaceMuted, borderRadius: BorderRadius.circular(FF.rCard)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: muted ? t.textMuted : scheme.primary),
            const SizedBox(width: 6),
            Text(label.toUpperCase(),
                style: TextStyle(color: t.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          if (muted)
            Text(unit, style: TextStyle(color: scheme.primary, fontSize: 12.5, fontWeight: FontWeight.w700, decoration: TextDecoration.underline))
          else
            Text(unit, style: TextStyle(color: t.textMuted, fontSize: 12.5)),
        ],
      ),
    );
  }
}
