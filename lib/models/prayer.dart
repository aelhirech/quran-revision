enum Prayer {
  // Ordre chronologique de la journée (tahiyyatMasjid est hors-chrono,
  // ajouté séparément selon le nombre d'entrées à la mosquée — voir
  // HomeScreen._effectivePrayers)
  sunnaFajr,     // 2r avant Fajr
  fajr,
  duha,          // 2r+ après le lever du soleil, avant Dhouhr
  sunnaDhuhrAv,  // 4r avant Dhouhr (ou 2r selon madhab)
  dhuhr,
  sunnaDhuhrAp,  // 2r après Dhouhr
  asr,
  maghrib,
  sunnaMaghrib,  // 2r après Maghrib
  isha,
  sunnaIsha,     // 2r après Isha
  witr,              // 1 ou 3r après Isha
  tahiyyatMasjid,   // 2r en entrant à la mosquée
}

/// Métadonnées d'une prière — une ligne par valeur de [Prayer]. Remplace
/// (Phase 6 Sprint 5) 6 switchs parallèles qui répétaient la même
/// énumération : toute donnée par prière vit ici, à un seul endroit, plutôt
/// que d'être éparpillée sur 6 blocs à garder synchronisés à la main.
///
/// Contrepartie assumée : un `switch` sur `Prayer` est vérifié exhaustif par
/// l'analyseur Dart à la compilation ; une entrée manquante dans cette table
/// ne l'est pas — elle échouerait au premier accès (`_meta[this]!`).
/// `test/models/prayer_test.dart` couvre les 13 valeurs pour compenser.
/// [frShort] : `null` = identique à [fr] (cas de 10 prières sur 13) — évite
/// de recopier deux fois la même chaîne pour un unique nom court, régression
/// repérée en revue de code par rapport à l'ancien `nameFrShort` qui
/// retombait déjà sur `nameFr` par défaut.
typedef _PrayerMeta = ({String fr, String? frShort, String en, String ar, int rakaas, int suratRakaas});

const Map<Prayer, _PrayerMeta> _meta = {
  Prayer.sunnaFajr: (fr: 'Sunna Fajr', frShort: null, en: 'Sunnah Fajr', ar: 'سنة الفجر', rakaas: 2, suratRakaas: 2),
  Prayer.fajr: (fr: 'Fajr', frShort: null, en: 'Fajr', ar: 'الفجر', rakaas: 2, suratRakaas: 2),
  Prayer.duha: (fr: 'Doha', frShort: null, en: 'Duha', ar: 'الضحى', rakaas: 2, suratRakaas: 2),
  Prayer.sunnaDhuhrAv: (fr: 'Sunna Dhouhr (avant)', frShort: 'Sunna Dhouhr (av.)', en: 'Sunnah Dhuhr (before)', ar: 'سنة الظهر القبلية', rakaas: 4, suratRakaas: 4),
  Prayer.dhuhr: (fr: 'Dhouhr', frShort: null, en: 'Dhuhr', ar: 'الظهر', rakaas: 4, suratRakaas: 2),
  Prayer.sunnaDhuhrAp: (fr: 'Sunna Dhouhr (après)', frShort: 'Sunna Dhouhr (ap.)', en: 'Sunnah Dhuhr (after)', ar: 'سنة الظهر البعدية', rakaas: 2, suratRakaas: 2),
  Prayer.asr: (fr: 'Asr', frShort: null, en: 'Asr', ar: 'العصر', rakaas: 4, suratRakaas: 2),
  Prayer.maghrib: (fr: 'Maghrib', frShort: null, en: 'Maghrib', ar: 'المغرب', rakaas: 3, suratRakaas: 2),
  Prayer.sunnaMaghrib: (fr: 'Sunna Maghrib', frShort: null, en: 'Sunnah Maghrib', ar: 'سنة المغرب', rakaas: 2, suratRakaas: 2),
  Prayer.isha: (fr: 'Isha', frShort: null, en: 'Isha', ar: 'العشاء', rakaas: 4, suratRakaas: 2),
  Prayer.sunnaIsha: (fr: 'Sunna Isha', frShort: null, en: 'Sunnah Isha', ar: 'سنة العشاء', rakaas: 2, suratRakaas: 2),
  Prayer.witr: (fr: 'Witr', frShort: null, en: 'Witr', ar: 'الوتر', rakaas: 3, suratRakaas: 3),
  Prayer.tahiyyatMasjid: (fr: 'Tahiyyat al-Masjid', frShort: 'Tahiyyat', en: 'Tahiyyat al-Masjid', ar: 'تحية المسجد', rakaas: 2, suratRakaas: 2),
};

/// Les 5 prières fard (obligatoires) — les seules dont dépend `isFard`.
const _fardPrayers = {Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha};

extension PrayerExtension on Prayer {
  _PrayerMeta get _m => _meta[this]!;

  String get nameFr => _m.fr;
  String get nameFrShort => _m.frShort ?? _m.fr;
  String get nameEn => _m.en;
  String get nameAr => _m.ar;

  /// Nombre total de rakaas de la prière
  int get rakaas => _m.rakaas;

  /// Rakaas où l'on récite une sourate après Al-Fatiha.
  /// Pour les fard à 4 rakaas : seulement les 2 premiers.
  /// Pour Maghrib (3 rakaas fard) : les 2 premiers également.
  /// Pour toutes les sunna/nafl : tous les rakaas.
  int get suratRakaas => _m.suratRakaas;

  bool get isTahiyyat => this == Prayer.tahiyyatMasjid;
  bool get isFard => _fardPrayers.contains(this);
}
