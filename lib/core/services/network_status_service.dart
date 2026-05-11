import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/network/dio_client.dart';
import 'package:meal_app/core/services/offline_queue.dart';

/// Production-style online/offline signal.
///
/// - Uses OS connectivity as the primary signal.
/// - Confirms backend reachability with **GET /health** (no JWT — avoids 401 spam).
/// - Debounces rapid connectivity events (no repeated pings every few seconds).
/// - Replays queued write-actions when connectivity returns and notifies listeners
///   so the UI can refresh authenticated data.
class NetworkStatusService with ChangeNotifier {
  NetworkStatusService._();

  static final NetworkStatusService instance = NetworkStatusService._();

  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _debounceTimer;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  DioClient? _dioClient;
  bool _processingQueue = false;
  bool _refreshInFlight = false;

  final List<VoidCallback> _becameOnlineListeners = [];

  void attachDioClient(DioClient dioClient) {
    _dioClient ??= dioClient;
  }

  /// Called when we transition from offline → online (after queue replay starts).
  void addBecameOnlineListener(VoidCallback listener) {
    if (!_becameOnlineListeners.contains(listener)) {
      _becameOnlineListeners.add(listener);
    }
  }

  void removeBecameOnlineListener(VoidCallback listener) {
    _becameOnlineListeners.remove(listener);
  }

  void _notifyBecameOnline() {
    final copy = List<VoidCallback>.from(_becameOnlineListeners);
    for (final cb in copy) {
      try {
        cb();
      } catch (_) {/* ignore */}
    }
  }

  Future<void> start() async {
    await _refreshStatus();

    _sub ??= _connectivity.onConnectivityChanged.listen((_) {
      _scheduleRefresh();
    });
  }

  void _scheduleRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(_refreshStatus());
    });
  }

  Future<void> stop() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _refreshStatus() async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    try {
      final online = await _checkOnline();
      final prev = _isOnline;
      _isOnline = online;
      if (prev != _isOnline) {
        notifyListeners();
      }

      if (!prev && _isOnline) {
        await _processQueue();
        _notifyBecameOnline();
      }
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<bool> _checkOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (!hasNetwork) return false;
    } catch (_) {
      // Fall through to HTTP check
    }

    // Use /health — never use authenticated routes here (would 401 and spam logs).
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
        sendTimeout: const Duration(seconds: 3),
      ));
      final res = await dio.get(ApiEndpoints.health);
      if (res.statusCode == 200 && res.data is Map && res.data['status'] == 'ok') {
        return true;
      }
      return res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 500;
    } catch (_) {
      return false;
    }
  }

  Future<void> _processQueue() async {
    if (_processingQueue) return;
    final dioClient = _dioClient;
    if (dioClient == null) return;

    _processingQueue = true;
    try {
      await OfflineQueue.process(
        executor: (method, path, data) async {
          final options = Options(method: method);
          return await dioClient.dio.request(path, data: data, options: options);
        },
      );
    } catch (e) {
      if (kDebugMode) {
        // ignore in release; queue remains for next reconnect
      }
    } finally {
      _processingQueue = false;
    }
  }
}
