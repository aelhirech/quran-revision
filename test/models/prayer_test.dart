import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/models/prayer.dart';

void main() {
  // Verrou anti-transcription (Phase 6 Sprint 5) : la table de métadonnées de
  // prayer.dart remplace 6 switchs parallèles par une seule source — ce test
  // rejoue les valeurs de ces switchs pour garantir qu'aucune n'a été
  // déplacée ou mal recopiée en construisant la table.
  const expected = <Prayer, ({
    String fr, String frShort, String en, String ar,
    int rakaas, int suratRakaas, bool isFard, bool isTahiyyat,
  })>{
    Prayer.sunnaFajr: (
      fr: 'Sunna Fajr', frShort: 'Sunna Fajr',
      en: 'Sunnah Fajr', ar: 'سنة الفجر',
      rakaas: 2, suratRakaas: 2, isFard: false, isTahiyyat: false,
    ),
    Prayer.fajr: (
      fr: 'Fajr', frShort: 'Fajr',
      en: 'Fajr', ar: 'الفجر',
      rakaas: 2, suratRakaas: 2, isFard: true, isTahiyyat: false,
    ),
    Prayer.duha: (
      fr: 'Doha', frShort: 'Doha',
      en: 'Duha', ar: 'الضحى',
      rakaas: 2, suratRakaas: 2, isFard: false, isTahiyyat: false,
    ),
    Prayer.sunnaDhuhrAv: (
      fr: 'Sunna Dhouhr (avant)', frShort: 'Sunna Dhouhr (av.)',
      en: 'Sunnah Dhuhr (before)', ar: 'سنة الظهر القبلية',
      rakaas: 4, suratRakaas: 4, isFard: false, isTahiyyat: false,
    ),
    Prayer.dhuhr: (
      fr: 'Dhouhr', frShort: 'Dhouhr',
      en: 'Dhuhr', ar: 'الظهر',
      rakaas: 4, suratRakaas: 2, isFard: true, isTahiyyat: false,
    ),
    Prayer.sunnaDhuhrAp: (
      fr: 'Sunna Dhouhr (après)', frShort: 'Sunna Dhouhr (ap.)',
      en: 'Sunnah Dhuhr (after)', ar: 'سنة الظهر البعدية',
      rakaas: 2, suratRakaas: 2, isFard: false, isTahiyyat: false,
    ),
    Prayer.asr: (
      fr: 'Asr', frShort: 'Asr',
      en: 'Asr', ar: 'العصر',
      rakaas: 4, suratRakaas: 2, isFard: true, isTahiyyat: false,
    ),
    Prayer.maghrib: (
      fr: 'Maghrib', frShort: 'Maghrib',
      en: 'Maghrib', ar: 'المغرب',
      rakaas: 3, suratRakaas: 2, isFard: true, isTahiyyat: false,
    ),
    Prayer.sunnaMaghrib: (
      fr: 'Sunna Maghrib', frShort: 'Sunna Maghrib',
      en: 'Sunnah Maghrib', ar: 'سنة المغرب',
      rakaas: 2, suratRakaas: 2, isFard: false, isTahiyyat: false,
    ),
    Prayer.isha: (
      fr: 'Isha', frShort: 'Isha',
      en: 'Isha', ar: 'العشاء',
      rakaas: 4, suratRakaas: 2, isFard: true, isTahiyyat: false,
    ),
    Prayer.sunnaIsha: (
      fr: 'Sunna Isha', frShort: 'Sunna Isha',
      en: 'Sunnah Isha', ar: 'سنة العشاء',
      rakaas: 2, suratRakaas: 2, isFard: false, isTahiyyat: false,
    ),
    Prayer.witr: (
      fr: 'Witr', frShort: 'Witr',
      en: 'Witr', ar: 'الوتر',
      rakaas: 3, suratRakaas: 3, isFard: false, isTahiyyat: false,
    ),
    Prayer.tahiyyatMasjid: (
      fr: 'Tahiyyat al-Masjid', frShort: 'Tahiyyat',
      en: 'Tahiyyat al-Masjid', ar: 'تحية المسجد',
      rakaas: 2, suratRakaas: 2, isFard: false, isTahiyyat: true,
    ),
  };

  test('chaque valeur de Prayer a une entrée, et toutes les valeurs correspondent aux anciens switchs', () {
    expect(expected.length, Prayer.values.length);

    for (final p in Prayer.values) {
      final e = expected[p]!;
      expect(p.nameFr, e.fr, reason: '${p.name}.nameFr');
      expect(p.nameFrShort, e.frShort, reason: '${p.name}.nameFrShort');
      expect(p.nameEn, e.en, reason: '${p.name}.nameEn');
      expect(p.nameAr, e.ar, reason: '${p.name}.nameAr');
      expect(p.rakaas, e.rakaas, reason: '${p.name}.rakaas');
      expect(p.suratRakaas, e.suratRakaas, reason: '${p.name}.suratRakaas');
      expect(p.isFard, e.isFard, reason: '${p.name}.isFard');
      expect(p.isTahiyyat, e.isTahiyyat, reason: '${p.name}.isTahiyyat');
    }
  });

  test('suratRakaas ne dépasse jamais rakaas (règle métier implicite)', () {
    for (final p in Prayer.values) {
      expect(p.suratRakaas, lessThanOrEqualTo(p.rakaas), reason: p.name);
    }
  });

  test('exactement 5 prières fard : Fajr, Dhouhr, Asr, Maghrib, Isha', () {
    final fards = Prayer.values.where((p) => p.isFard).toSet();
    expect(fards, {Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha});
  });
}
