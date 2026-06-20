class Sourate {
  final int id;
  final String nameAr;
  final String nameFr;
  final int verses;

  const Sourate({
    required this.id,
    required this.nameAr,
    required this.nameFr,
    required this.verses,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameAr': nameAr,
        'nameFr': nameFr,
        'verses': verses,
      };

  factory Sourate.fromJson(Map<String, dynamic> j) => Sourate(
        id: j['id'],
        nameAr: j['nameAr'],
        nameFr: j['nameFr'],
        verses: j['verses'],
      );
}
