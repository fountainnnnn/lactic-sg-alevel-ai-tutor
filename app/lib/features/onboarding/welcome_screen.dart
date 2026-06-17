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
              // Large illustration card with overlaid badges (matches Stitch).
              Expanded(
                flex: 6,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 384, maxHeight: 397),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.asset(
                                'assets/illustrations/welcome.png',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => ColoredBox(color: t.primarySoft),
                              ),
                            ),
                          ),
                          const Positioned(
                            top: 12,
                            right: 12,
                            child: _Badge(icon: Icons.school_rounded, label: 'SEAB Syllabus'),
                          ),
                          Positioned(
                            bottom: 14,
                            left: 12,
                            child: _Badge(icon: Icons.verified_rounded, label: 'Prelim Ready', iconColor: t.success),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Your A-Level tutor',
                        textAlign: TextAlign.center,
                        style: text.displaySmall?.copyWith(color: scheme.primary)),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Text(
                        'Grounded in real Singapore prelims and the SEAB syllabus, not generic AI.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: t.textMuted, height: 1.5, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => context.go('/subjects'),
                child: const Text('Get started'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => context.push('/signin'),
                child: const Text('Already have an account? Sign in'),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.lock_outline_rounded, size: 13, color: t.textMuted),
                const SizedBox(width: 6),
                Text('FREE · PRIVATE & SECURE',
                    style: TextStyle(
                        color: t.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;
  const _Badge({required this.icon, required this.label, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: iconColor ?? const Color(0xFF6B5DE0)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Color(0xFF221F33), fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
