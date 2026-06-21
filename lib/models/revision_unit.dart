import '../core/quran_data.dart';
import 'sourate.dart';

class RevisionUnit {
  final Sourate sourate;
  final int verseStart;
  final int verseEnd;
  final bool isWhole;

  const RevisionUnit({
    required this.sourate,
    required this.verseStart,
    required this.verseEnd,
    required this.isWhole,
  });

  int get verseCount => verseEnd - verseStart + 1;

  String get label {
    final name = '${sourate.nameAr} · ${sourate.nameFr}';
    if (isWhole) return name;
    return '$name (v.$verseStart–$verseEnd)';
  }

  Map<String, dynamic> toJson() => {
        'sourateId': sourate.id,
        'verseStart': verseStart,
        'verseEnd': verseEnd,
        'isWhole': isWhole,
      };

  factory RevisionUnit.fromJson(Map<String, dynamic> j) {
    final id = j['sourateId'] as int;
    final sourate = allSourates.firstWhere((s) => s.id == id);
    return RevisionUnit(
      sourate: sourate,
      verseStart: j['verseStart'] as int,
      verseEnd: j['verseEnd'] as int,
      isWhole: j['isWhole'] as bool,
    );
  }
}
