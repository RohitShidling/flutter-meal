import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OfflineQueue {
  OfflineQueue._();

  static const _queueKey = 'offline:queue:v1';

  static Future<List<Map<String, dynamic>>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  static Future<void> _save(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode(items));
  }

  /// Enqueue a request for later replay when online.
  ///
  /// Expected shape:
  /// - method: GET|POST|PUT|PATCH|DELETE
  /// - path: API path (e.g. /api/client/children)
  /// - data: request body (optional)
  static Future<void> enqueue({
    required String method,
    required String path,
    Map<String, dynamic>? data,
  }) async {
    final items = await _load();
    items.add(<String, dynamic>{
      'method': method.toUpperCase(),
      'path': path,
      if (data != null) 'data': data,
      'enqueuedAt': DateTime.now().toIso8601String(),
    });
    await _save(items);
  }

  static Future<int> pendingCount() async {
    final items = await _load();
    return items.length;
  }

  /// Process queued requests. Best-effort:
  /// - Stops on first failure (keeps remaining queue).
  /// - Removes items that succeed.
  static Future<int> process({
    required Future<dynamic> Function(String method, String path, Map<String, dynamic>? data) executor,
  }) async {
    final items = await _load();
    var processed = 0;
    final remaining = <Map<String, dynamic>>[];

    for (final item in items) {
      final method = (item['method'] ?? '').toString().toUpperCase();
      final path = (item['path'] ?? '').toString();
      final dataRaw = item['data'];
      final data = dataRaw is Map ? Map<String, dynamic>.from(dataRaw) : null;

      if (method.isEmpty || path.isEmpty) {
        // drop corrupt entries
        processed += 1;
        continue;
      }

      try {
        await executor(method, path, data);
        processed += 1;
      } catch (_) {
        remaining.add(item);
        // keep the rest as well
        final idx = items.indexOf(item);
        for (var j = idx + 1; j < items.length; j++) {
          remaining.add(items[j]);
        }
        break;
      }
    }

    await _save(remaining);
    return processed;
  }
}

