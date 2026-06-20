enum Prayer {
  // Prières obligatoires (fard)
  fajr,
  dhuhr,
  asr,
  maghrib,
  isha,
  // Sunna rawatib
  sunnaFajr,     // 2r avant Fajr
  sunnaDhuhrAv,  // 4r avant Dhouhr (ou 2r selon madhab)
  sunnaDhuhrAp,  // 2r après Dhouhr
  sunnaMaghrib,  // 2r après Maghrib
  sunnaIsha,     // 2r après Isha
  witr,              // 1 ou 3r après Isha
  tahiyyatMasjid,   // 2r en entrant à la mosquée
}

extension PrayerExtension on Prayer {
  String get nameFr {
    switch (this) {
      case Prayer.fajr:         return 'Fajr';
      case Prayer.dhuhr:        return 'Dhouhr';
      case Prayer.asr:          return 'Asr';
      case Prayer.maghrib:      return 'Maghrib';
      case Prayer.isha:         return "Isha";
      case Prayer.sunnaFajr:    return 'Sunna Fajr';
      case Prayer.sunnaDhuhrAv: return 'Sunna Dhouhr (avant)';
      case Prayer.sunnaDhuhrAp: return 'Sunna Dhouhr (après)';
      case Prayer.sunnaMaghrib: return 'Sunna Maghrib';
      case Prayer.sunnaIsha:    return "Sunna Isha";
      case Prayer.witr:         return 'Witr';
      case Prayer.tahiyyatMasjid: return 'Tahiyyat al-Masjid';
    }
  }

  String get nameFrShort {
    if (this == Prayer.tahiyyatMasjid) return 'Tahiyyat';
    if (this == Prayer.sunnaDhuhrAv) return 'Sunna Dhouhr (av.)';
    if (this == Prayer.sunnaDhuhrAp) return 'Sunna Dhouhr (ap.)';
    return nameFr;
  }

  String get nameEn {
    switch (this) {
      case Prayer.fajr:           return 'Fajr';
      case Prayer.dhuhr:          return 'Dhuhr';
      case Prayer.asr:            return 'Asr';
      case Prayer.maghrib:        return 'Maghrib';
      case Prayer.isha:           return 'Isha';
      case Prayer.sunnaFajr:      return 'Sunnah Fajr';
      case Prayer.sunnaDhuhrAv:   return 'Sunnah Dhuhr (before)';
      case Prayer.sunnaDhuhrAp:   return 'Sunnah Dhuhr (after)';
      case Prayer.sunnaMaghrib:   return 'Sunnah Maghrib';
      case Prayer.sunnaIsha:      return 'Sunnah Isha';
      case Prayer.witr:           return 'Witr';
      case Prayer.tahiyyatMasjid: return 'Tahiyyat al-Masjid';
    }
  }

  String get nameAr {
    switch (this) {
      case Prayer.fajr:         return 'الفجر';
      case Prayer.dhuhr:        return 'الظهر';
      case Prayer.asr:          return 'العصر';
      case Prayer.maghrib:      return 'المغرب';
      case Prayer.isha:         return 'العشاء';
      case Prayer.sunnaFajr:    return 'سنة الفجر';
      case Prayer.sunnaDhuhrAv: return 'سنة الظهر القبلية';
      case Prayer.sunnaDhuhrAp: return 'سنة الظهر البعدية';
      case Prayer.sunnaMaghrib: return 'سنة المغرب';
      case Prayer.sunnaIsha:    return 'سنة العشاء';
      case Prayer.witr:           return 'الوتر';
      case Prayer.tahiyyatMasjid: return 'تحية المسجد';
    }
  }

  /// Nombre total de rakaas de la prière
  int get rakaas {
    switch (this) {
      case Prayer.fajr:         return 2;
      case Prayer.dhuhr:        return 4;
      case Prayer.asr:          return 4;
      case Prayer.maghrib:      return 3;
      case Prayer.isha:         return 4;
      case Prayer.sunnaFajr:    return 2;
      case Prayer.sunnaDhuhrAv: return 4;
      case Prayer.sunnaDhuhrAp: return 2;
      case Prayer.sunnaMaghrib: return 2;
      case Prayer.sunnaIsha:    return 2;
      case Prayer.witr:           return 3;
      case Prayer.tahiyyatMasjid: return 2;
    }
  }

  /// Rakaas où l'on récite une sourate après Al-Fatiha.
  /// Pour les fard à 4 rakaas : seulement les 2 premiers.
  /// Pour Maghrib (3 rakaas fard) : les 2 premiers également.
  /// Pour toutes les sunna/nafl : tous les rakaas.
  int get suratRakaas {
    switch (this) {
      case Prayer.fajr:         return 2;
      case Prayer.dhuhr:        return 2;
      case Prayer.asr:          return 2;
      case Prayer.maghrib:      return 2;
      case Prayer.isha:         return 2;
      case Prayer.sunnaFajr:    return 2;
      case Prayer.sunnaDhuhrAv: return 4;
      case Prayer.sunnaDhuhrAp: return 2;
      case Prayer.sunnaMaghrib: return 2;
      case Prayer.sunnaIsha:    return 2;
      case Prayer.witr:           return 3;
      case Prayer.tahiyyatMasjid: return 2;
    }
  }

  bool get isTahiyyat => this == Prayer.tahiyyatMasjid;

  bool get isFard {
    return this == Prayer.fajr ||
        this == Prayer.dhuhr ||
        this == Prayer.asr ||
        this == Prayer.maghrib ||
        this == Prayer.isha;
  }
}
