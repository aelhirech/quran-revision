import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_config.dart';

class StorageService {
  static const _keyConfig = 'user_config';
  static const _keyCyclePosition = 'cycle_position';

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

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
