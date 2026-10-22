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
  final Color primaryContainer;
  final Color onSurfaceVariant;
  final Color onDanger;
  final Color dangerContainer;
  /// Not yet played, then levels 1 to 4 (cool hues, green to night blue).
  final List<Color> levelTints;
  /// Reserved for "at risk of being forgotten": no other meaning may use it.
  final Color risk;
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
    required this.primaryContainer,
    required this.onSurfaceVariant,
    required this.onDanger,
    required this.dangerContainer,
    required this.levelTints,
    required this.risk,
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
    goldDark: Color(0xFF806226),
    textPrimary: Color(0xFF1E2B22),
    textMuted: Color(0xFF5A635D),
    danger: Color(0xFF8C2F23),
    ctaShadow: Color(0xFFB8923E),
    primaryContainer: Color(0xFFE3EEE6),
    onSurfaceVariant: Color(0xFF4A5450),
    onDanger: Colors.white,
    dangerContainer: Color(0xFFF4E0DC),
    levelTints: [
      Color(0xFF8E8571),
      Color(0xFF3C8F62),
      Color(0xFF24909B),
      Color(0xFF2F5FB3),
      Color(0xFF2E2A78),
    ],
    risk: Color(0xFFC2571F),
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
    danger: Color(0xFFF28B7D),
    ctaShadow: Color(0xFF86E0A8),
    primaryContainer: Color(0xFF1B2D22),
    onSurfaceVariant: Color(0xFFB7C2BC),
    // White on the light dark-theme danger would fall below 2:1.
    onDanger: Color(0xFF0E1410),
    dangerContainer: Color(0xFF3A2320),
    levelTints: [
      // Mockup gray #4A524D lightened: it reached only 2.3:1 on the background
      // and 2.2:1 on a card.
      Color(0xFF626A65),
      Color(0xFF4FA873),
      Color(0xFF45B5C2),
      Color(0xFF6C97F0),
      Color(0xFF7B6CF0),
    ],
    risk: Color(0xFFF0936B),
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
    Color? primaryContainer,
    Color? onSurfaceVariant,
    Color? onDanger,
    Color? dangerContainer,
    List<Color>? levelTints,
    Color? risk,
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
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      onDanger: onDanger ?? this.onDanger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      levelTints: levelTints ?? this.levelTints,
      risk: risk ?? this.risk,
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
      primaryContainer: Color.lerp(primaryContainer, other.primaryContainer, t)!,
      onSurfaceVariant: Color.lerp(onSurfaceVariant, other.onSurfaceVariant, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      levelTints: [
        for (var i = 0; i < levelTints.length; i++)
          Color.lerp(levelTints[i], other.levelTints[i], t)!,
      ],
      risk: Color.lerp(risk, other.risk, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension AppPaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
