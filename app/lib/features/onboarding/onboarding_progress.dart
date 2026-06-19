import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// 4-dot onboarding progress indicator. [step] is 0-based
/// (welcome=0, subjects=1, live-taste=2, trust=3).
class OnboardingProgress extends StatelessWidget {
  final int step;
  final int total;
  const OnboardingProgress({super.key, required this.step, this.total = 4});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final on = i == step;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: on ? 26 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: on ? scheme.primary : t.border,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }
}

/// Square bordered back button used in the onboarding footer.
class OnboardingBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const OnboardingBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 56,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(color: t.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FF.rButton)),
        ),
        onPressed: onTap,
        child: Icon(Icons.arrow_back_rounded, color: scheme.onSurface),
      ),
    );
  }
}
