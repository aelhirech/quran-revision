import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/learning_progress.dart';
import '../models/student_profile.dart';

/// Gère les profils élèves et leur progression d'apprentissage séparée.
/// La clé de stockage de progression est préfixée par l'id du profil.
class StudentService {
  static const _profilesKey = 'student_profiles_v1';

  static String _progressKey(String profileId) =>
      'learning_progress_${profileId}_v1';

  // ── Profils ────────────────────────────────────────────────────────────────

  static Future<List<StudentProfile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);
    if (raw == null) return [];
    return StudentProfile.listFromJson(raw);
  }

  static Future<void> saveProfiles(List<StudentProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profilesKey, StudentProfile.listToJson(profiles));
  }

  static Future<StudentProfile> addProfile(String name) async {
    final profiles = await loadProfiles();
    final profile = StudentProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
    );
    profiles.add(profile);
    await saveProfiles(profiles);
    return profile;
  }

  static Future<void> removeProfile(String profileId) async {
    final profiles = await loadProfiles();
    profiles.removeWhere((p) => p.id == profileId);
    await saveProfiles(profiles);
    // Nettoie la progression associée
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_progressKey(profileId));
  }

  static Future<void> renameProfile(String profileId, String newName) async {
    final profiles = await loadProfiles();
    final idx = profiles.indexWhere((p) => p.id == profileId);
    if (idx == -1) return;
    profiles[idx] = StudentProfile(id: profileId, name: newName);
    await saveProfiles(profiles);
  }

  // ── Progression d'apprentissage par profil ─────────────────────────────────

  static Future<List<LearningProgress>> loadProgress(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_progressKey(profileId));
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => LearningProgress.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveProgress(
      String profileId, List<LearningProgress> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _progressKey(profileId),
      jsonEncode(items.map((p) => p.toJson()).toList()),
    );
  }

  static Future<void> upsertProgress(
      String profileId, LearningProgress updated) async {
    final items = await loadProgress(profileId);
    final idx = items.indexWhere((p) => p.sourate.id == updated.sourate.id);
    if (idx == -1) {
      items.add(updated);
    } else {
      items[idx] = updated;
    }
    await saveProgress(profileId, items);
  }

  static Future<void> removeProgress(String profileId, int sourateId) async {
    final items = await loadProgress(profileId);
    items.removeWhere((p) => p.sourate.id == sourateId);
    await saveProgress(profileId, items);
  }
}
