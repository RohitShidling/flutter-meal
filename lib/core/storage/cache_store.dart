import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CacheStore {
  CacheStore._();

  static const _prefix = 'cache:';

  static String _k(String key) => '$_prefix$key';

  static Future<void> setJson(String key, Object? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_k(key));
      return;
    }
    await prefs.setString(_k(key), jsonEncode(value));
  }

  static Future<dynamic> getJson(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_k(key));
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}

