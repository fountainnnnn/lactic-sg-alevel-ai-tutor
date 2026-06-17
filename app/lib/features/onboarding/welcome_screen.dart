import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../shared/illustration.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const Illustration('welcome', size: 240),
              const Spacer(),
              Text('Your A-Level tutor', textAlign: TextAlign.center, style: text.displaySmall),
              const SizedBox(height: 14),
              Text(
                'Grounded in real Singapore prelims and the SEAB syllabus, not generic AI.',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textMuted, height: 1.5, fontSize: 15),
              ),
              const Spacer(flex: 2),
              FilledButton(
                onPressed: () => context.go('/subjects'),
                child: const Text('Get started'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => context.push('/signin'),
                child: const Text('Already have an account? Sign in'),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: t.textMuted),
                const SizedBox(width: 6),
                Text('Free, private and secure',
                    style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
