import 'package:flutter/material.dart';

import 'models.dart';

const brand = Color(0xFFFF5A36); // coral: energia
const teal = Color(0xFF14B8A6);
const green = Color(0xFF22C55E);
const amber = Color(0xFFF59E0B);
const red = Color(0xFFEF4444);

Color painColor(Pain p) => const [green, amber, red][p.index];

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: brand, brightness: brightness).copyWith(
    primary: brand,
    onPrimary: Colors.white,
    secondary: teal,
    surface: dark ? const Color(0xFF15171C) : const Color(0xFFF6F5F2),
    surfaceContainerLow: dark ? const Color(0xFF1D2027) : Colors.white,
    surfaceContainerHighest: dark ? const Color(0xFF2A2E37) : const Color(0xFFECEAE5),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Nunito');
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'Nunito', fontSize: 24, fontWeight: FontWeight.w900, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: brand.withValues(alpha: .16),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w700)),
    ),
    chipTheme: base.chipTheme.copyWith(labelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
