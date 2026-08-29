import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/learning_progress.dart';
import '../models/riwaya.dart';
import 'riwaya_key.dart';

/// Progression de mémorisation du profil principal — un parcours indépendant
/// par riwaya (Hafs et Warsh ne partagent pas la même progression, voir
/// [Riwaya]).
class LearningService {
  static const _key = 'learning_progress_v1';

  static String _keyFor(Riwaya riwaya) => riwayaKey(_key, riwaya);

  static Future<List<LearningProgress>> loadAll(Riwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(riwaya));
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => LearningProgress.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveAll(List<LearningProgress> items, Riwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyFor(riwaya), jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  static Future<void> upsert(LearningProgress updated, Riwaya riwaya) async {
    final all = await loadAll(riwaya);
    final idx = all.indexWhere((p) => p.sourate.id == updated.sourate.id);
    if (idx >= 0) {
      all[idx] = updated;
    } else {
      all.add(updated);
    }
    await saveAll(all, riwaya);
  }

  static Future<void> remove(int sourateId, Riwaya riwaya) async {
    final all = await loadAll(riwaya);
    all.removeWhere((p) => p.sourate.id == sourateId);
    await saveAll(all, riwaya);
  }

  /// Migration one-shot : avant l'ajout des parcours par riwaya, cette
  /// progression était unique et implicitement Hafs.
  static Future<void> migrateLegacyTrackData() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_key)) {
      await prefs.setString(_keyFor(Riwaya.hafs), prefs.getString(_key)!);
      await prefs.remove(_key);
    }
  }
}
