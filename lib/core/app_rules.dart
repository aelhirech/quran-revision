/// Seuils métier qui ne vivent pas dans un moteur dédié (`RevisionEngine`,
/// `FreshnessEngine`, `StreakEngine`). Chacun n'a aujourd'hui qu'un seul
/// point de lecture — ce n'est donc pas de la réutilisation qui justifie ce
/// fichier, mais l'auditabilité : avant Sprint 5, ces seuils étaient des
/// littéraux nus (`0.8`, `/ 2`, `< 5`) noyés dans du code de mise en page
/// (`docs/DOCUMENTATION_TECHNIQUE.md` §8.5 point 2) — un chiffre qui décrit
/// une règle métier doit être nommé et visible d'un coup d'œil, pas déduit
/// de son contexte d'affichage.
class AppRules {
  AppRules._();

  /// Seuil "bonne journée" (`HistoryCard`) : au-delà de ce pourcentage
  /// d'unités complétées, une journée est mise en avant visuellement.
  static const double goodDayThreshold = 0.8;

  /// Paliers de streak qui déclenchent le message "nouveau palier" au lieu
  /// du décompte classique (`PlanScreen`, écran de complétion).
  static const Set<int> streakMilestones = {7, 30, 100};

  /// Nombre maximum d'entrées "Tahiyyat al-Masjid" sélectionnables
  /// (`PrayerSelector`) — au-delà, compter les passages n'a plus de sens.
  static const int maxTahiyyatCount = 5;

  /// Fraction des rakaas proposée par défaut quand l'utilisateur déclare
  /// avoir fait "une part" plutôt que tout ou rien (modale d'engagement).
  static const double defaultPartialFraction = 0.5;
}
