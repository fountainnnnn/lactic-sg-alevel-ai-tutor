import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../data/conversation_store.dart';
import '../../state/app_state.dart';
import '../../state/chat_controller.dart';
import '../shared/illustration.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _query = '';

  static const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  static const _weekdays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];

  String _bucket(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    return '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
  }

  String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  String _question(Conversation c) {
    for (final m in c.messages) {
      if (m.role == 'user' && m.content.trim().isNotEmpty) return m.content.trim();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    var convos = ref.watch(conversationStoreProvider).list();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      convos = convos.where((c) => c.title.toLowerCase().contains(q) || c.subject.toLowerCase().contains(q)).toList();
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text('History', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search topics...',
                prefixIcon: Icon(Icons.search_rounded, color: t.textMuted),
              ),
            ),
            const SizedBox(height: 8),
            if (convos.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    const Illustration('empty_chats', size: 140),
                    const SizedBox(height: 12),
                    Text(_query.isEmpty ? 'No saved questions yet' : 'No matches',
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(_query.isEmpty
                        ? 'Your conversations are saved here so you can pick up where you left off.'
                        : 'Try a different search.',
                        textAlign: TextAlign.center, style: TextStyle(color: t.textMuted, height: 1.5)),
                    if (_query.isEmpty) ...[
                      const SizedBox(height: 20),
                      FilledButton(onPressed: () => context.go('/chat'), child: const Text('Start a chat')),
                    ],
                  ],
                ),
              )
            else
              ..._buildGroups(convos, t),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroups(List<Conversation> convos, AppTokens t) {
    final groups = <String, List<Conversation>>{};
    for (final c in convos) {
      groups.putIfAbsent(_bucket(c.updatedAt), () => []).add(c);
    }
    final out = <Widget>[];
    for (final entry in groups.entries) {
      out.add(Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 0, 10),
        child: Text(entry.key,
            style: TextStyle(color: t.textMuted, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6)),
      ));
      out.addAll(entry.value.map((c) => _Card(conv: c, question: _question(c), time: _time(c.updatedAt), t: t)));
    }
    return out;
  }
}

class _Card extends ConsumerWidget {
  final Conversation conv;
  final String question;
  final String time;
  final AppTokens t;
  const _Card({required this.conv, required this.question, required this.time, required this.t});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(conv.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: t.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(FF.rCard)),
        child: Icon(Icons.delete_outline_rounded, color: t.danger),
      ),
      onDismissed: (_) => ref.read(conversationStoreProvider).delete(conv.id),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
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
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(conv.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      if (question.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(question, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: t.textMuted, fontSize: 13.5)),
                      ],
                      const SizedBox(height: 10),
                      Row(children: [
                        if (conv.subject.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(999)),
                            child: Text(conv.subject,
                                style: TextStyle(color: t.onPrimarySoft, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(time, style: TextStyle(color: t.textMuted, fontSize: 13)),
                      ]),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: t.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
