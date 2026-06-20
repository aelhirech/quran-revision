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
    if (isWhole) return sourate.nameAr;
    return '${sourate.nameAr} (v.$verseStart–$verseEnd)';
  }

  Map<String, dynamic> toJson() => {
        'sourateId': sourate.id,
        'verseStart': verseStart,
        'verseEnd': verseEnd,
        'isWhole': isWhole,
      };
}
