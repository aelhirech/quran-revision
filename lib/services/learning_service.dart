import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/learning_progress.dart';

class LearningService {
  static const _key = 'learning_progress_v1';

  static Future<List<LearningProgress>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => LearningProgress.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveAll(List<LearningProgress> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  static Future<void> upsert(LearningProgress updated) async {
    final all = await loadAll();
    final idx = all.indexWhere((p) => p.sourate.id == updated.sourate.id);
    if (idx >= 0) {
      all[idx] = updated;
    } else {
      all.add(updated);
    }
    await saveAll(all);
  }

  static Future<void> remove(int sourateId) async {
    final all = await loadAll();
    all.removeWhere((p) => p.sourate.id == sourateId);
    await saveAll(all);
  }
}
