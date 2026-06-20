import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'onboarding_progress.dart';
import 'subjects_screen.dart';
import 'live_taste_screen.dart';
import 'trust_screen.dart';

/// Onboarding shell. The progress indicator is fixed at the top; only the step
/// CONTENT swipes between steps in the PageView underneath. That way the dots
/// actually track progress instead of sliding away with the page.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});
  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _pc = PageController();
  final _liveTasteKey = GlobalKey<LiveTasteStepState>();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() =>
      _pc.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  void _prev() =>
      _pc.previousPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);

  // Top-left back: on the live-taste step (page 1), first let it collapse a
  // shown demo answer back to the 3-question list; otherwise step back within
  // the flow, or leave onboarding from step 1.
  void _back() {
    if (_page == 1 && (_liveTasteKey.currentState?.handleBack() ?? false)) {
      return;
    }
    if (_page == 0) {
      context.canPop() ? context.pop() : context.go('/welcome');
    } else {
      _prev();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Top bar: back on the left, fixed progress dots centered. Welcome
            // is step 0, so these three steps are 1..3.
            SizedBox(
              height: 48,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: IconButton(
                        tooltip: 'Back',
                        icon: Icon(Icons.arrow_back_rounded, color: scheme.onSurface),
                        onPressed: _back,
                      ),
                    ),
                  ),
                  Center(child: OnboardingProgress(step: _page + 1)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: PageView(
                controller: _pc,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  SubjectsStep(onNext: _next),
                  LiveTasteStep(key: _liveTasteKey, onNext: _next),
                  const TrustStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
