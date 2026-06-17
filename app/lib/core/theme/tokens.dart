import 'package:flutter/material.dart';

/// Friendly Focus design tokens (see docs/DESIGN_SYSTEM.md).
/// Light = soft lavender paper. Dark = neutral charcoal with a lavender accent.
class FF {
  // ---- Light ----
  static const lBg = Color(0xFFFAF8FF);
  static const lSurface = Color(0xFFFFFFFF);
  static const lSurfaceMuted = Color(0xFFF1EEFA);
  static const lText = Color(0xFF221F33);
  static const lTextMuted = Color(0xFF6F6A82);
  static const lBorder = Color(0xFFE9E4F6);
  static const lPrimary = Color(0xFF6B5DE0);
  static const lPrimaryStrong = Color(0xFF5B4FCF);
  static const lPrimarySoft = Color(0xFFEEEBFC);
  static const lOnPrimarySoft = Color(0xFF4A3D9E);

  // ---- Dark (neutral charcoal + lavender accent) ----
  static const dBg = Color(0xFF121316);
  static const dSurface = Color(0xFF1C1D22);
  static const dSurfaceMuted = Color(0xFF26272D);
  static const dText = Color(0xFFE3E2E6);
  static const dTextMuted = Color(0xFF9B9CA3);
  static const dBorder = Color(0xFF303138);
  static const dPrimary = Color(0xFFA99BF5);
  static const dPrimaryStrong = Color(0xFFC9BEFF);
  static const dPrimarySoft = Color(0xFF2A2B31);
  static const dOnPrimarySoft = Color(0xFFC9BEFA);

  // ---- Semantic ----
  static const successL = Color(0xFF15803D);
  static const successD = Color(0xFF4ADE80);
  static const warningL = Color(0xFFB45309);
  static const warningD = Color(0xFFFBBF24);
  static const dangerL = Color(0xFFDC2626);
  static const dangerD = Color(0xFFF87171);

  // radii
  static const rCard = 16.0;
  static const rButton = 14.0;
  static const rField = 14.0;
  static const rBubble = 18.0;
}

/// Extra brand tokens not covered by [ColorScheme], exposed via theme so widgets
/// read `Theme.of(context).extension<AppTokens>()!`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  final Color surfaceMuted;
  final Color textMuted;
  final Color border;
  final Color primarySoft;
  final Color onPrimarySoft;
  final Color success;
  final Color warning;
  final Color danger;

  const AppTokens({
    required this.surfaceMuted,
    required this.textMuted,
    required this.border,
    required this.primarySoft,
    required this.onPrimarySoft,
    required this.success,
    required this.warning,
    required this.danger,
  });

  static const light = AppTokens(
    surfaceMuted: FF.lSurfaceMuted,
    textMuted: FF.lTextMuted,
    border: FF.lBorder,
    primarySoft: FF.lPrimarySoft,
    onPrimarySoft: FF.lOnPrimarySoft,
    success: FF.successL,
    warning: FF.warningL,
    danger: FF.dangerL,
  );

  static const dark = AppTokens(
    surfaceMuted: FF.dSurfaceMuted,
    textMuted: FF.dTextMuted,
    border: FF.dBorder,
    primarySoft: FF.dPrimarySoft,
    onPrimarySoft: FF.dOnPrimarySoft,
    success: FF.successD,
    warning: FF.warningD,
    danger: FF.dangerD,
  );

  @override
  AppTokens copyWith({
    Color? surfaceMuted,
    Color? textMuted,
    Color? border,
    Color? primarySoft,
    Color? onPrimarySoft,
    Color? success,
    Color? warning,
    Color? danger,
  }) =>
      AppTokens(
        surfaceMuted: surfaceMuted ?? this.surfaceMuted,
        textMuted: textMuted ?? this.textMuted,
        border: border ?? this.border,
        primarySoft: primarySoft ?? this.primarySoft,
        onPrimarySoft: onPrimarySoft ?? this.onPrimarySoft,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
      );

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      onPrimarySoft: Color.lerp(onPrimarySoft, other.onPrimarySoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// Convenience accessor: `context.tokens`.
extension TokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
