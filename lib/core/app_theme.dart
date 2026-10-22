import 'package:flutter/material.dart';
import 'app_colors.dart';

/// The six text styles of the app, without color: add it with
/// `copyWith(color: context.palette.…)`. Arabic text keeps its own fonts.
class AppText {
  static const family = 'Outfit';

  static const screenTitle = TextStyle(
    fontFamily: family,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 40 / 28,
    letterSpacing: -0.4,
  );
  // Shown in capitals: the caller applies `.toUpperCase()`.
  static const sectionTitle = TextStyle(
    fontFamily: family,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 2,
  );
  static const cardTitle = TextStyle(fontFamily: family, fontSize: 17, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontFamily: family, fontSize: 15, fontWeight: FontWeight.w400);
  static const caption = TextStyle(fontFamily: family, fontSize: 13, fontWeight: FontWeight.w400);
  static const bigNumber = TextStyle(fontFamily: family, fontSize: 56, fontWeight: FontWeight.w700);
}

/// Shape of every `Card`. Public so that a card with a state border derives
/// it (`copyWith(side: …)`) instead of restating the radius.
RoundedRectangleBorder cardShape(AppPalette palette) => RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: palette.cardBorder),
    );

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final palette = isDark ? AppPalette.dark : AppPalette.light;

  final base = ColorScheme.fromSeed(
    seedColor: palette.primary,
    brightness: brightness,
  ).copyWith(
    primary: palette.primary,
    onPrimary: palette.onPrimary,
    primaryContainer: palette.primaryContainer,
    onPrimaryContainer: isDark ? palette.primary : palette.primary,
    secondary: palette.gold,
    onSecondary: palette.onPrimary,
    surface: palette.cream,
    onSurface: palette.textPrimary,
    surfaceContainerHighest: palette.surfaceCardSolid,
    onSurfaceVariant: palette.onSurfaceVariant,
    error: palette.danger,
    onError: palette.onDanger,
    errorContainer: palette.dangerContainer,
    onErrorContainer: palette.danger,
  );

  final roleText = ThemeData(brightness: brightness)
      .textTheme
      .copyWith(
        headlineMedium: AppText.screenTitle,
        labelSmall: AppText.sectionTitle,
        titleMedium: AppText.cardTitle,
        bodyLarge: AppText.body,
        bodyMedium: AppText.body,
        bodySmall: AppText.caption,
        displayMedium: AppText.bigNumber,
      )
      .apply(
        fontFamily: AppText.family,
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
      );

  return ThemeData(
    colorScheme: base,
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: palette.cream,
    textTheme: roleText,
    extensions: [palette],
    cardTheme: CardThemeData(
      elevation: 0,
      // Cards sit in padded lists like the Container-based cards around them;
      // Material's default 4px margin shifted them out of alignment.
      margin: EdgeInsets.zero,
      color: palette.surfaceCard,
      shape: cardShape(palette),
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: palette.textPrimary,
      titleTextStyle: TextStyle(
        fontFamily: AppText.family,
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
        return TextStyle(
          fontFamily: AppText.family,
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
        textStyle: const TextStyle(fontFamily: AppText.family, fontWeight: FontWeight.w600, fontSize: 15),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.textPrimary,
        side: BorderSide(color: palette.textPrimary.withValues(alpha: isDark ? 0.2 : 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: AppText.family, fontWeight: FontWeight.w600, fontSize: 14),
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
      labelStyle: TextStyle(fontFamily: AppText.family, fontSize: 13, color: palette.textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: palette.cardBorder),
      ),
      side: BorderSide.none,
    ),
  );
}
