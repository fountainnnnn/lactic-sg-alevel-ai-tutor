import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Brief branded loading splash: the full Lactic lockup (icon + name on ONE
/// line) on the app background, then routes into the app. The native cold-start
/// splash uses the same background colour so the hand-off is seamless.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) context.go('/home'); // router redirect routes to welcome/home
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFAFE), // matches the native splash bg
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 44),
          child: Image.asset(
            'assets/brand/lactic_lockup.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text(
              'Lactic',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: 44,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
