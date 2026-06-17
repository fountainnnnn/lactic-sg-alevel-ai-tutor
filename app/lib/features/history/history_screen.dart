import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../shared/illustration.dart';

/// History of past conversations. Conversations persist server-side for
/// signed-in users; until sign-in is wired, this shows the real empty state.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
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
              Text(
                'Sign in to save your conversations and pick up where you left off across devices.',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textMuted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
