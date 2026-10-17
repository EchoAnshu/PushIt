import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/calibration.dart';

class CalibrationStore {
  static const _key = 'calibration_v1';

  static Future<CalibrationData?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      return null;
    }
    try {
      return CalibrationData.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(CalibrationData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
