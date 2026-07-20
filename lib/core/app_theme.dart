import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final palette = isDark ? AppPalette.dark : AppPalette.light;

  final base = ColorScheme.fromSeed(
    seedColor: palette.primary,
    brightness: brightness,
  ).copyWith(
    primary: palette.primary,
    onPrimary: palette.onPrimary,
    primaryContainer: isDark ? const Color(0xFF1B2D22) : const Color(0xFFE3EEE6),
    onPrimaryContainer: isDark ? palette.primary : palette.primary,
    secondary: palette.gold,
    onSecondary: palette.onPrimary,
    surface: palette.cream,
    onSurface: palette.textPrimary,
    surfaceContainerHighest: palette.surfaceCardSolid,
    onSurfaceVariant: isDark ? const Color(0xFFB7C2BC) : const Color(0xFF4A5450),
    error: palette.danger,
    onError: Colors.white,
    errorContainer: isDark ? const Color(0xFF3A2320) : const Color(0xFFF4E0DC),
    onErrorContainer: palette.danger,
  );

  final loraText = GoogleFonts.loraTextTheme(
    ThemeData(brightness: brightness).textTheme,
  ).apply(
    bodyColor: palette.textPrimary,
    displayColor: palette.textPrimary,
  );

  return ThemeData(
    colorScheme: base,
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: palette.cream,
    textTheme: loraText,
    extensions: [palette],
    cardTheme: CardThemeData(
      elevation: 0,
      color: palette.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.cardBorder),
      ),
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: palette.textPrimary,
      titleTextStyle: GoogleFonts.lora(
        color: palette.textPrimary,
        fontSize: 26,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.cream,
      elevation: 0,
      shadowColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? palette.primary : palette.textPrimary.withValues(alpha: 0.45),
          size: 22,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.lora(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          color: selected ? palette.primary : palette.textPrimary.withValues(alpha: 0.45),
        );
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.lora(fontWeight: FontWeight.w600, fontSize: 15),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.textPrimary,
        side: BorderSide(color: palette.textPrimary.withValues(alpha: isDark ? 0.2 : 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.lora(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected) ? palette.onPrimary : palette.textPrimary.withValues(alpha: 0.5);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? palette.primary
            : Colors.transparent;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? palette.primary
            : palette.textPrimary.withValues(alpha: 0.25);
      }),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: palette.surfaceCard,
      selectedColor: palette.primary,
      labelStyle: GoogleFonts.lora(fontSize: 13, color: palette.textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: palette.cardBorder),
      ),
      side: BorderSide.none,
    ),
  );
}
