import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../data/conversation_store.dart';
import '../../state/app_state.dart';
import '../../state/chat_controller.dart';
import '../shared/illustration.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  String _bucket(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'This week';
    return 'Earlier';
  }

  String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final convos = ref.watch(conversationStoreProvider).list();

    if (convos.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('History')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Illustration('empty_chats', size: 150),
                const SizedBox(height: 12),
                Text('No saved questions yet', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Your conversations are saved here so you can pick up where you left off.',
                    textAlign: TextAlign.center, style: TextStyle(color: t.textMuted, height: 1.5)),
                const SizedBox(height: 20),
                FilledButton(onPressed: () => context.go('/chat'), child: const Text('Start a chat')),
              ],
            ),
          ),
        ),
      );
    }

    // group by bucket, preserving recency order
    final groups = <String, List<Conversation>>{};
    for (final c in convos) {
      groups.putIfAbsent(_bucket(c.updatedAt), () => []).add(c);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(entry.key,
                    style: TextStyle(color: t.textMuted, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              ...entry.value.map((c) => Dismissible(
                    key: ValueKey(c.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: t.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.delete_outline_rounded, color: t.danger),
                    ),
                    onDismissed: (_) => ref.read(conversationStoreProvider).delete(c.id),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: t.border),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          [if (c.subject.isNotEmpty) c.subject, _time(c.updatedAt)].join(' · '),
                          style: TextStyle(color: t.textMuted, fontSize: 12.5),
                        ),
                        trailing: Icon(Icons.chevron_right_rounded, color: t.textMuted),
                        onTap: () {
                          ref.read(chatControllerProvider.notifier).load(c);
                          context.go('/chat');
                        },
                      ),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
