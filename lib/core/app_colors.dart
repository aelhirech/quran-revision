import 'package:flutter/material.dart';

/// Semantic design tokens for the "Mus'haf" (light) / "Tahajjud" (dark)
/// art direction. Registered on [ThemeData.extensions] in `app_theme.dart`.
class AppPalette extends ThemeExtension<AppPalette> {
  final Color cream;
  final Color surfaceCard;
  final Color surfaceCardSolid;
  final Color cardBorder;
  final Color primary;
  final Color onPrimary;
  final Color gold;
  final Color goldDark;
  final Color textPrimary;
  final Color textMuted;
  final Color danger;
  final Color ctaShadow;
  final bool isDark;

  const AppPalette({
    required this.cream,
    required this.surfaceCard,
    required this.surfaceCardSolid,
    required this.cardBorder,
    required this.primary,
    required this.onPrimary,
    required this.gold,
    required this.goldDark,
    required this.textPrimary,
    required this.textMuted,
    required this.danger,
    required this.ctaShadow,
    required this.isDark,
  });

  static const light = AppPalette(
    cream: Color(0xFFF7F2E8),
    surfaceCard: Color(0x80FFFFFF),
    surfaceCardSolid: Color(0xFFFFFDF6),
    cardBorder: Color(0x2E1E2B22),
    primary: Color(0xFF14442B),
    onPrimary: Color(0xFFF7F2E8),
    gold: Color(0xFFB8923E),
    goldDark: Color(0xFF8C6D2A),
    textPrimary: Color(0xFF1E2B22),
    textMuted: Color(0x991E2B22),
    danger: Color(0xFF8C2F23),
    ctaShadow: Color(0xFFB8923E),
    isDark: false,
  );

  static const dark = AppPalette(
    cream: Color(0xFF0E1410),
    surfaceCard: Color(0x08FFFFFF),
    surfaceCardSolid: Color(0x08FFFFFF),
    cardBorder: Color(0x1AFFFFFF),
    primary: Color(0xFF86E0A8),
    onPrimary: Color(0xFF0E1410),
    gold: Color(0xFFC9A85C),
    goldDark: Color(0xFFC9A85C),
    textPrimary: Color(0xFFF2F7F3),
    textMuted: Color(0x99F2F7F3),
    danger: Color(0xFF8C2F23),
    ctaShadow: Color(0xFF86E0A8),
    isDark: true,
  );

  @override
  AppPalette copyWith({
    Color? cream,
    Color? surfaceCard,
    Color? surfaceCardSolid,
    Color? cardBorder,
    Color? primary,
    Color? onPrimary,
    Color? gold,
    Color? goldDark,
    Color? textPrimary,
    Color? textMuted,
    Color? danger,
    Color? ctaShadow,
    bool? isDark,
  }) {
    return AppPalette(
      cream: cream ?? this.cream,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceCardSolid: surfaceCardSolid ?? this.surfaceCardSolid,
      cardBorder: cardBorder ?? this.cardBorder,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      gold: gold ?? this.gold,
      goldDark: goldDark ?? this.goldDark,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      danger: danger ?? this.danger,
      ctaShadow: ctaShadow ?? this.ctaShadow,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      cream: Color.lerp(cream, other.cream, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceCardSolid: Color.lerp(surfaceCardSolid, other.surfaceCardSolid, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldDark: Color.lerp(goldDark, other.goldDark, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      ctaShadow: Color.lerp(ctaShadow, other.ctaShadow, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension AppPaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
