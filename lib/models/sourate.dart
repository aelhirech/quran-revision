class Sourate {
  final int id;
  final String nameAr;
  final String nameFr;
  final int verses;
  final int words;

  const Sourate({
    required this.id,
    required this.nameAr,
    required this.nameFr,
    required this.verses,
    required this.words,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameAr': nameAr,
        'nameFr': nameFr,
        'verses': verses,
        'words': words,
      };

  factory Sourate.fromJson(Map<String, dynamic> j) => Sourate(
        id: j['id'],
        nameAr: j['nameAr'],
        nameFr: j['nameFr'],
        verses: j['verses'],
        words: j['words'] ?? j['verses'] * 12,
      );

  /// True if [query] matches this surah's French name, Arabic name, or id —
  /// shared predicate for the search fields in `OnboardingScreen`,
  /// `SouratePickerSheet`, and `ProfileScreen`.
  bool matchesSearch(String query) =>
      nameFr.toLowerCase().contains(query.toLowerCase()) ||
      nameAr.contains(query) ||
      id.toString() == query;
}
