import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_config.dart';

class StorageService {
  static const _keyConfig = 'user_config';
  static const _keyCyclePosition = 'cycle_position';
  static const _keyLocale = 'locale';
  static const _keyNotifEnabled = 'notif_enabled';

  static Future<void> saveConfig(UserConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyConfig, jsonEncode(config.toJson()));
  }

  static Future<UserConfig?> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyConfig);
    if (raw == null) return null;
    return UserConfig.fromJson(jsonDecode(raw));
  }

  static Future<void> saveCyclePosition(int position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCyclePosition, position);
  }

  static Future<int> loadCyclePosition() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCyclePosition) ?? 0;
  }

  static Future<void> saveLocale(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, locale);
  }

  static Future<String> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocale) ?? 'fr';
  }

  static Future<void> saveNotifEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifEnabled, enabled);
  }

  static Future<bool> loadNotifEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotifEnabled) ?? true;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
