import 'package:shared_preferences/shared_preferences.dart';
import '../core/reciters.dart';
import '../models/riwaya.dart';
import 'riwaya_key.dart';

/// Audio preferences (US-9/US-10) — never `ayah_facts` nor `UserConfig`:
/// listening is passive and must not touch the revision cycle.
class AudioPrefs {
  static const _keyReciter = 'audio_reciter';
  static const _keyPendingDownloads = 'audio_pending_downloads';
  static const _keyAllowMobile = 'audio_allow_mobile_download';

  /// Reciter chosen for loop playback — per riwaya: a Hafs reciter has no
  /// business waking up on the Warsh track.
  static Future<void> saveReciter(Riwaya riwaya, String reciterId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(riwayaKey(_keyReciter, riwaya), reciterId);
  }

  /// The saved reciter, or the riwaya's default when none (or one no longer
  /// in the catalog) is saved.
  static Future<Reciter> chosenReciter(Riwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(riwayaKey(_keyReciter, riwaya));
    return (saved != null ? reciterById(saved) : null) ?? defaultReciterFor(riwaya);
  }

  /// Download intents still to complete, oldest first: `'reciterId'` for a
  /// whole reciter, `'reciterId:surahId'` for one surah. Global, not per
  /// riwaya: the files on disk aren't either.
  static Future<List<String>> loadPendingDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyPendingDownloads) ?? const [];
  }

  static Future<void> savePendingDownloads(List<String> intents) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyPendingDownloads, intents);
  }

  static Future<bool> loadAllowMobileDownload() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAllowMobile) ?? false;
  }

  static Future<void> saveAllowMobileDownload(bool allow) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAllowMobile, allow);
  }
}
