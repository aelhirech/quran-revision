import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/freshness_engine.dart';
import '../core/strings.dart';

/// Couleur associée à un niveau de fraîcheur — utilisée par [FreshnessBadge]
/// et par tout affichage colorant du contenu (ex. chips "à surveiller") selon
/// la fraîcheur plutôt que d'afficher le badge lui-même.
Color freshnessColor(FreshnessLevel level, AppPalette palette) {
  switch (level) {
    case FreshnessLevel.hot:
      return palette.primary;
    case FreshnessLevel.cold:
      return palette.gold;
    case FreshnessLevel.frozen:
      return palette.danger;
  }
}

String freshnessLabel(FreshnessLevel level) {
  switch (level) {
    case FreshnessLevel.hot:
      return S.fraicheurRecente;
    case FreshnessLevel.cold:
      return S.fraicheurFroide;
    case FreshnessLevel.frozen:
      return S.fraicheurGelee;
  }
}

/// Badge pilule affichant le niveau de fraîcheur d'une sourate (label + couleur).
class FreshnessBadge extends StatelessWidget {
  final FreshnessLevel level;

  const FreshnessBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final color = freshnessColor(level, context.palette);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(freshnessLabel(level), style: TextStyle(fontSize: 10, color: color)),
    );
  }
}
