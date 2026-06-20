import '../models/prayer.dart';
import 'strings.dart';

/// Extension de présentation : nom de prière selon la locale active.
/// Séparé de prayer.dart pour garder les modèles sans dépendance UI.
extension PrayerL10n on Prayer {
  String get displayName => S.locale == 'en' ? nameEn : nameFr;
}
