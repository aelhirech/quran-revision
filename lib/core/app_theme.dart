import 'package:flutter/material.dart';
import 'app_colors.dart';

ThemeData buildAppTheme() {
  const green = AppColors.green;
  const greenLight = AppColors.greenLight;
  const bg = AppColors.bg;

  final base = ColorScheme.fromSeed(
    seedColor: green,
    brightness: Brightness.light,
  ).copyWith(
    primary: green,
    onPrimary: Colors.white,
    primaryContainer: AppColors.greenContainer,
    onPrimaryContainer: green,
    secondary: greenLight,
    surface: Colors.white,
    onSurface: const Color(0xFF111311),
    surfaceContainerHighest: bg,
    onSurfaceVariant: const Color(0xFF4A5450),
  );

  return ThemeData(
    colorScheme: base,
    useMaterial3: true,
    scaffoldBackgroundColor: bg,
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: Colors.black.withValues(alpha: 0.06),
      surfaceTintColor: Colors.transparent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Color(0xFF111311),
      titleTextStyle: TextStyle(
        color: Color(0xFF111311),
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      indicatorColor: AppColors.greenContainer,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: green,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        elevation: 0,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: bg,
      selectedColor: AppColors.greenContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
    ),
  );
}
