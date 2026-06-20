enum Prayer { fajr, dhuhr, asr, maghrib, isha }

extension PrayerExtension on Prayer {
  String get nameFr {
    switch (this) {
      case Prayer.fajr:
        return 'Fajr';
      case Prayer.dhuhr:
        return 'Dhouhr';
      case Prayer.asr:
        return 'Asr';
      case Prayer.maghrib:
        return 'Maghrib';
      case Prayer.isha:
        return 'Isha';
    }
  }

  String get nameAr {
    switch (this) {
      case Prayer.fajr:
        return 'الفجر';
      case Prayer.dhuhr:
        return 'الظهر';
      case Prayer.asr:
        return 'العصر';
      case Prayer.maghrib:
        return 'المغرب';
      case Prayer.isha:
        return 'العشاء';
    }
  }

  int get rakaas {
    switch (this) {
      case Prayer.fajr:
        return 2;
      case Prayer.dhuhr:
        return 4;
      case Prayer.asr:
        return 4;
      case Prayer.maghrib:
        return 3;
      case Prayer.isha:
        return 4;
    }
  }
}
