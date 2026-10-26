// Colors and the app theme (light and dark). Change colors here.

import 'package:flutter/material.dart';

// ---- brand palette (soft pastel, matches the reference UI) ----
const Color ink = Color(0xFF16161F);
const Color inkSoft = Color(0xFF5E5E70);
const Color lav = Color(0xFFBDBAF4); // primary accent / selected nav
const Color lavDeep = Color(0xFF7873D9);
const Color danger = Color(0xFFD64545);
const Color alertDot = Color(0xFFFF7A7A);

/// Pastel card colors. They stay pastel in dark mode (text on them is always ink).
enum Pastel { peach, lavender, mint, coral, pink, sky, butter }

extension PastelColor on Pastel {
  Color get color {
    switch (this) {
      case Pastel.peach:
        return const Color(0xFFFCE3CE);
      case Pastel.lavender:
        return const Color(0xFFD7D6FC);
      case Pastel.mint:
        return const Color(0xFFC2EEE6);
      case Pastel.coral:
        return const Color(0xFFFF9F9F);
      case Pastel.pink:
        return const Color(0xFFEBBFBF);
      case Pastel.sky:
        return const Color(0xFFCFE6FA);
      case Pastel.butter:
        return const Color(0xFFFFF0BF);
    }
  }
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final surface = dark ? const Color(0xFF1E2033) : Colors.white;
  final scheme = ColorScheme.fromSeed(seedColor: lav, brightness: b).copyWith(
    primary: dark ? lav : ink,
    onPrimary: dark ? ink : Colors.white,
    secondary: lav,
    onSecondary: ink,
    surface: surface,
    outlineVariant: dark ? const Color(0xFF2E3050) : const Color(0xFFE6E6EE),
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        dark ? const Color(0xFF13141F) : const Color(0xFFF5F5F8),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: scheme.onSurface,
      centerTitle: true,
      titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: dark ? lav : lavDeep, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? lav : ink,
        foregroundColor: dark ? ink : Colors.white,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
    ),
  );
}
