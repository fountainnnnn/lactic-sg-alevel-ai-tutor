import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Shows assets/illustrations/<name>.png if it exists, otherwise a tasteful
/// on-brand placeholder so the app runs before the generated art is added.
class Illustration extends StatelessWidget {
  final String name;
  final double size;
  const Illustration(this.name, {super.key, this.size = 200});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Image.asset(
      'assets/illustrations/$name.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: t.primarySoft,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Icon(Icons.auto_stories_rounded, size: size * 0.34, color: t.onPrimarySoft),
      ),
    );
  }
}
