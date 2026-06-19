import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),
              Center(
                child: Image.asset(
                  'assets/brand/lactic_wordmark.png',
                  height: 56,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text(
                    'Lactic',
                    textAlign: TextAlign.center,
                    style: (text.displaySmall ?? const TextStyle()).copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 44,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    'You won\'t need ChatGPT or Claude anymore. Lactic knows your A-Level content, techniques, and question patterns.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: t.textMuted, height: 1.5, fontSize: 16.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const Spacer(flex: 2),
              Center(
                child: Image.asset(
                  'assets/illustrations/welcome.png',
                  height: 240,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 240,
                    width: 240,
                    decoration: BoxDecoration(
                      color: t.primarySoft,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 3),
              FilledButton(
                onPressed: () => context.push('/onboarding'),
                child: const Text('Get started'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => context.push('/signin'),
                child: const Text('I already have an account'),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
