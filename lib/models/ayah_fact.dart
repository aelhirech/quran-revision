import 'riwaya.dart';

enum AyahFactType { learn, revise }

/// Une ligne de la table de faits par verset (Phase 6) — remplace
/// `sessions`/`sourate_sessions` (granularité sourate) et `LearningProgress`
/// (granularité "Set de versets appris") par un seul grain atomique : un
/// verset, un jour, un type de fait.
class AyahFact {
  final String userId;
  final String date; // YYYY-MM-DD
  final Riwaya riwaya;
  final int surahId;
  final int ayahId;
  final AyahFactType type;
  final bool reach;
  final bool needsWork;
  final bool checkedOut;

  const AyahFact({
    this.userId = 'local',
    required this.date,
    required this.riwaya,
    required this.surahId,
    required this.ayahId,
    required this.type,
    this.reach = false,
    this.needsWork = false,
    this.checkedOut = false,
  });

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'date': date,
        'riwaya': riwaya.name,
        'surah_id': surahId,
        'ayah_id': ayahId,
        'type': type.name,
        'reach': reach ? 1 : 0,
        'needs_work': needsWork ? 1 : 0,
        'checked_out': checkedOut ? 1 : 0,
      };

  factory AyahFact.fromMap(Map<String, dynamic> m) => AyahFact(
        userId: m['user_id'] as String,
        date: m['date'] as String,
        riwaya: Riwaya.values.byName(m['riwaya'] as String),
        surahId: m['surah_id'] as int,
        ayahId: m['ayah_id'] as int,
        type: AyahFactType.values.byName(m['type'] as String),
        reach: (m['reach'] as int) != 0,
        needsWork: (m['needs_work'] as int) != 0,
        checkedOut: (m['checked_out'] as int) != 0,
      );
}
