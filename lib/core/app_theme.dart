import 'package:flutter/material.dart';

ThemeData buildAppTheme(TextTheme textTheme, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  const seed = Color(0xFFE85D93);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    surface: isDark ? const Color(0xFF21181D) : const Color(0xFFFFF6F9),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF130D10)
        : const Color(0xFFFFF3F7),
    textTheme: textTheme.apply(
      bodyColor: isDark ? Colors.white : const Color(0xFF23171D),
      displayColor: isDark ? Colors.white : const Color(0xFF23171D),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: isDark ? const Color(0xFF21181D) : const Color(0xFFFFFBFC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      margin: EdgeInsets.zero,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: isDark
          ? const Color(0xFF2A2025)
          : const Color(0xFFFFF6F9),
      shape: const RoundedRectangleBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF2A2025) : const Color(0xFFFFF8FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF4A323D) : const Color(0xFFF0C8D7),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF4A323D) : const Color(0xFFF0C8D7),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFE85D93)),
      ),
      hintStyle: TextStyle(
        color: isDark ? const Color(0xFFB693A1) : const Color(0xFFA07887),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFE85D93),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: isDark
          ? const Color(0xFF2A2025)
          : const Color(0xFFFFEAF1),
      selectedColor: const Color(0xFFC43E77),
      secondarySelectedColor: const Color(0xFFC43E77),
      side: BorderSide(
        color: isDark ? const Color(0xFFC43E77) : const Color(0xFFF2B6CB),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: TextStyle(
        color: isDark ? const Color(0xFFFFBBD3) : const Color(0xFFC43E77),
      ),
    ),
  );
}
