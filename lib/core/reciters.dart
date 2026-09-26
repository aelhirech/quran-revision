import '../models/riwaya.dart';

/// A recitation voice available on `quran.ksu.edu.sa` for a given riwaya.
/// [folder] is the mp3 directory segment used by the site (see
/// [audioTrackUrls]).
class Reciter {
  final String id;
  final String folder;
  final String nameAr;
  final String nameFr;
  final Riwaya riwaya;

  const Reciter({
    required this.id,
    required this.folder,
    required this.nameAr,
    required this.nameFr,
    required this.riwaya,
  });
}

const String _baseMp3Url = 'https://quran.ksu.edu.sa/ayat/mp3';

/// Catalog reverse-engineered from `js/engine.js` (`quraa_map`) on
/// `quran.ksu.edu.sa` (US-9, 2026-09-26) — the site has no documented public
/// API, risk accepted by user decision (see docs/USER_STORIES.md). Each
/// reciter belongs to exactly one riwaya (US-9 exclusion "no cross-riwaya
/// reciter"): the three Warsh entries (husary.w/dosary/yasin) are the only
/// voices marked "(Warsh)" on the site — the rest of the KSU catalog
/// recites in Hafs.
const List<Reciter> kReciters = [
  // Hafs
  Reciter(id: 'husary.t', folder: 'Hussary.teacher_64kbps', nameAr: 'الحصري (المعلم)', nameFr: 'Al-Husary (professeur)', riwaya: Riwaya.hafs),
  Reciter(id: 'husary', folder: 'Husary_64kbps', nameAr: 'الحصري', nameFr: 'Al-Husary', riwaya: Riwaya.hafs),
  Reciter(id: 'huzaify', folder: 'Hudhaify_64kbps', nameAr: 'الحذيفي', nameFr: 'Al-Huthaify', riwaya: Riwaya.hafs),
  Reciter(id: 'sudais', folder: 'Abdurrahmaan_As-Sudais_64kbps', nameAr: 'عبد الرحمن السديس', nameFr: 'Abdul Rahman Al-Sudais', riwaya: Riwaya.hafs),
  Reciter(id: 'shuraym', folder: 'Saood_ash-Shuraym_64kbps', nameAr: 'سعود الشريم', nameFr: 'Saud Al-Shuraim', riwaya: Riwaya.hafs),
  Reciter(id: 'maher', folder: 'Maher_AlMuaiqly_64kbps', nameAr: 'ماهر المعيقلي', nameFr: 'Maher Al-Muaiqly', riwaya: Riwaya.hafs),
  Reciter(id: 'ghamidi', folder: 'Ghamadi_40kbps', nameAr: 'سعد الغامدي', nameFr: 'Saad Al-Ghamidi', riwaya: Riwaya.hafs),
  Reciter(id: 'qatami', folder: 'Nasser_Alqatami_128kbps', nameAr: 'ناصر القطامي', nameFr: 'Nasser Al-Qatami', riwaya: Riwaya.hafs),
  Reciter(id: 'jibreel', folder: 'Muhammad_Jibreel_64kbps', nameAr: 'محمد جبريل', nameFr: 'Mohammed Jibril', riwaya: Riwaya.hafs),
  Reciter(id: 'shatree', folder: 'Abu_Bakr_Ash-Shaatree_64kbps', nameAr: 'أبو بكر الشاطري', nameFr: 'Abou Bakr Al-Shatri', riwaya: Riwaya.hafs),
  Reciter(id: 'ajamy', folder: 'Ahmed_ibn_Ali_al-Ajamy_64kbps', nameAr: 'أحمد العجمي', nameFr: 'Ahmad Al-Ajmy', riwaya: Riwaya.hafs),
  Reciter(id: 'afasy', folder: 'Alafasy_64kbps', nameAr: 'مشاري العفاسي', nameFr: 'Mishary Al-Afasy', riwaya: Riwaya.hafs),
  Reciter(id: 'basfar', folder: 'Abdullah_Basfar_64kbps', nameAr: 'عبد الله بصفر', nameFr: 'Abdullah Basfar', riwaya: Riwaya.hafs),
  Reciter(id: 'absulbasit', folder: 'Abdul_Basit_Murattal_64kbps', nameAr: 'عبد الباسط عبد الصمد', nameFr: 'Abdul Basit', riwaya: Riwaya.hafs),
  Reciter(id: 'minshawy', folder: 'Minshawy_Murattal_128kbps', nameAr: 'المنشاوي', nameFr: 'Al-Minshawi', riwaya: Riwaya.hafs),
  Reciter(id: 'ayyoub', folder: 'Muhammad_Ayyoub_64kbps', nameAr: 'محمد أيوب', nameFr: 'Muhammad Ayyoub', riwaya: Riwaya.hafs),
  Reciter(id: 'rifai', folder: 'Hani_Rifai_192kbps', nameAr: 'هاني الرفاعي', nameFr: 'Hani Al-Rifai', riwaya: Riwaya.hafs),
  Reciter(id: 'qasim', folder: 'Muhsin_Al_Qasim_192kbps', nameAr: 'عبد المحسن القاسم', nameFr: 'Abdul Mohsen Al-Qasim', riwaya: Riwaya.hafs),
  Reciter(id: 'yaser', folder: 'Yasser_Ad-Dussary_128kbps', nameAr: 'ياسر الدوسري', nameFr: 'Yasser Al-Dosari', riwaya: Riwaya.hafs),
  Reciter(id: 'fares', folder: 'Fares_Abbad_64kbps', nameAr: 'فارس عباد', nameFr: 'Fares Abbad', riwaya: Riwaya.hafs),
  Reciter(id: 'salamah', folder: 'Yaser_Salamah_128kbps', nameAr: 'ياسر سلامة', nameFr: 'Yasser Salamah', riwaya: Riwaya.hafs),
  Reciter(id: 'mostafa', folder: 'Mostafa_Ismail_128kbps', nameAr: 'مصطفى إسماعيل', nameFr: 'Mostafa Ismail', riwaya: Riwaya.hafs),
  Reciter(id: 'jaber', folder: 'Ali_Jaber_64kbps', nameAr: 'علي عبد الله جابر', nameFr: 'Ali Abdullah Jaber', riwaya: Riwaya.hafs),
  Reciter(id: 'ayman', folder: 'Ayman_Sowaid_64kbps', nameAr: 'أيمن سويد', nameFr: 'Ayman Sowaid', riwaya: Riwaya.hafs),
  Reciter(id: 'tablawy', folder: 'Mohammad_al_Tablaway_64kbps', nameAr: 'الطبلاوي', nameFr: 'Al-Tablawi', riwaya: Riwaya.hafs),
  Reciter(id: 'tunaiji', folder: 'tunaiji_64kbps', nameAr: 'خليفة الطنيجي', nameFr: 'Khalifa Al-Tunaiji', riwaya: Riwaya.hafs),
  Reciter(id: 'awwad', folder: 'Abdullaah_3awwaad_Al-Juhaynee_128kbps', nameAr: 'عبد الله عواد الجهني', nameFr: 'Abdullah Awwad Al-Juhani', riwaya: Riwaya.hafs),

  // Warsh
  Reciter(id: 'husary.w', folder: 'warsh_husary_64kbps', nameAr: 'الحصري (ورش)', nameFr: 'Al-Husary (Warsh)', riwaya: Riwaya.warsh),
  Reciter(id: 'dosary', folder: 'warsh_dossary_128kbps', nameAr: 'إبراهيم الدوسري (ورش)', nameFr: 'Ibrahim Al-Dossary (Warsh)', riwaya: Riwaya.warsh),
  Reciter(id: 'yasin', folder: 'warsh_yassin_64kbps', nameAr: 'ياسين الجزائري (ورش)', nameFr: 'Yassine Al-Jazairi (Warsh)', riwaya: Riwaya.warsh),
];

List<Reciter> recitersFor(Riwaya riwaya) =>
    kReciters.where((r) => r.riwaya == riwaya).toList(growable: false);

Reciter? reciterById(String id) {
  for (final r in kReciters) {
    if (r.id == id) return r;
  }
  return null;
}

/// Default reciter for a riwaya — first in the list, deterministic.
Reciter defaultReciterFor(Riwaya riwaya) => recitersFor(riwaya).first;

/// Pure: one mp3 URL per verse of [surahId] between [ayahStart] and
/// [ayahEnd], in [reciter]'s voice. Format `{base}/{folder}/{surah}{ayah}.mp3`
/// (3 digits each), reverse-engineered from `js/engine.js` — no network call
/// here, just URL construction.
List<String> audioTrackUrls(Reciter reciter, int surahId, int ayahStart, int ayahEnd) {
  final surah = surahId.toString().padLeft(3, '0');
  return [
    for (var ayah = ayahStart; ayah <= ayahEnd; ayah++)
      '$_baseMp3Url/${reciter.folder}/$surah${ayah.toString().padLeft(3, '0')}.mp3',
  ];
}
