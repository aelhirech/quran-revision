import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/freshness_engine.dart';
import '../core/strings.dart';

/// Label court (badge pilule).
String freshnessLabel(FreshnessLevel level) {
  switch (level) {
    case FreshnessLevel.neverRevised:
      return S.fraicheurJamais;
    case FreshnessLevel.partiallyRecent:
      return S.fraicheurPartielle;
    case FreshnessLevel.recent:
      return S.fraicheurRecente;
    case FreshnessLevel.oneMonth:
      return S.fraicheur1Mois;
    case FreshnessLevel.threeMonths:
      return S.fraicheur3Mois;
    case FreshnessLevel.sixMonths:
      return S.fraicheur6Mois;
    case FreshnessLevel.oneYear:
      return S.fraicheur1An;
  }
}

/// Label discret (phrase complète) — même donnée que [freshnessLabel], rendu
/// différent : texte discret en check-in/check-out plutôt qu'un badge coloré
/// (décision maquette Sprint 1 conservée).
String freshnessDiscreetLabel(FreshnessLevel level) {
  switch (level) {
    case FreshnessLevel.neverRevised:
      return S.fraicheurJamaisLabel;
    case FreshnessLevel.partiallyRecent:
      return S.fraicheurPartielleLabel;
    case FreshnessLevel.recent:
      return S.fraicheurRecenteLabel;
    case FreshnessLevel.oneMonth:
      return S.fraicheur1MoisLabel;
    case FreshnessLevel.threeMonths:
      return S.fraicheur3MoisLabel;
    case FreshnessLevel.sixMonths:
      return S.fraicheur6MoisLabel;
    case FreshnessLevel.oneYear:
      return S.fraicheur1AnLabel;
  }
}

/// Sous-titre de rakaa (`PrayerPlanCard`) : tout sauf "récente" — ce badge
/// signale "pas complètement à jour" en continu dans PlanScreen. Switch
/// exhaustif (pas un `==`/`||`) comme [freshnessLabel] —
/// ajouter un niveau à [FreshnessLevel] doit casser la compilation ici aussi,
/// pas retomber silencieusement sur `true`/`false`.
bool freshnessShowsBadge(FreshnessLevel level) {
  switch (level) {
    case FreshnessLevel.recent:
      return false;
    case FreshnessLevel.neverRevised:
    case FreshnessLevel.partiallyRecent:
    case FreshnessLevel.oneMonth:
    case FreshnessLevel.threeMonths:
    case FreshnessLevel.sixMonths:
    case FreshnessLevel.oneYear:
      return true;
  }
}

/// Badge pilule affichant le niveau de fraîcheur d'une sourate/sélection.
/// Neutral on purpose: color carries meaning only for levels and forgetting
/// risk (US-25).
class FreshnessBadge extends StatelessWidget {
  final FreshnessLevel level;

  const FreshnessBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: palette.cardBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(freshnessLabel(level), style: AppText.caption.copyWith(color: palette.textMuted)),
    );
  }
}
