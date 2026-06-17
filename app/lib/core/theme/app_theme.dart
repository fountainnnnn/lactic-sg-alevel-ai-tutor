import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Builds the Friendly Focus light/dark themes. Headings = Baloo 2 (rounded,
/// friendly); body/UI = Nunito (readable). Derived from docs/DESIGN_SYSTEM.md.
class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isLight = b == Brightness.light;
    final bg = isLight ? FF.lBg : FF.dBg;
    final surface = isLight ? FF.lSurface : FF.dSurface;
    final text = isLight ? FF.lText : FF.dText;
    final primary = isLight ? FF.lPrimary : FF.dPrimary;
    final onPrimary = isLight ? Colors.white : const Color(0xFF1A1430);
    final tokens = isLight ? AppTokens.light : AppTokens.dark;

    final scheme = ColorScheme(
      brightness: b,
      primary: primary,
      onPrimary: onPrimary,
      secondary: primary,
      onSecondary: onPrimary,
      error: tokens.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: text,
    );

    // Baloo 2 for display/headline/title; Nunito for body/label.
    final base = ThemeData(brightness: b, useMaterial3: true);
    final heading = GoogleFonts.baloo2TextTheme(base.textTheme);
    final body = GoogleFonts.nunitoTextTheme(base.textTheme);
    final textTheme = TextTheme(
      displaySmall: heading.displaySmall?.copyWith(fontWeight: FontWeight.w600, color: text),
      headlineMedium: heading.headlineMedium?.copyWith(fontWeight: FontWeight.w600, color: text),
      headlineSmall: heading.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: text),
      titleLarge: heading.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: text),
      titleMedium: heading.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: text),
      bodyLarge: body.bodyLarge?.copyWith(color: text, height: 1.55),
      bodyMedium: body.bodyMedium?.copyWith(color: text, height: 1.55),
      bodySmall: body.bodySmall?.copyWith(color: tokens.textMuted),
      labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelMedium: body.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: tokens.textMuted),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      textTheme: textTheme,
      extensions: [tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      dividerColor: tokens.border,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(52),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FF.rButton)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: tokens.border),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FF.rButton)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: isLight ? FF.lPrimaryStrong : FF.dPrimaryStrong),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FF.rCard),
          side: BorderSide(color: tokens.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceMuted,
        hintStyle: TextStyle(color: tokens.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FF.rField),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FF.rField),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FF.rField),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: tokens.primarySoft,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: tokens.primarySoft,
        labelStyle: TextStyle(color: tokens.onPrimarySoft, fontWeight: FontWeight.w600),
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
    );
  }
}
