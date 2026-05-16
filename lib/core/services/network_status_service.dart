import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/network/dio_client.dart';
import 'package:meal_app/core/services/offline_queue.dart';

/// Production-style online/offline signal.
///
/// - [hasDeviceConnectivity]: OS reports Wi‑Fi / mobile / ethernet.
/// - [isBackendReachable]: GET /health succeeded recently.
/// - [canAttemptApi]: true when device has network — cart/subscription calls should run
///   (do not block on /health alone).
/// - [isOnline]: device + backend — used for strict offline banner when both fail.
class NetworkStatusService with ChangeNotifier {
  NetworkStatusService._();

  static final NetworkStatusService instance = NetworkStatusService._();

  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _debounceTimer;
  Timer? _healthPollTimer;

  bool _hasDeviceConnectivity = true;
  bool _isBackendReachable = true;

  /// Device has a network interface (Wi‑Fi, mobile, etc.).
  bool get hasDeviceConnectivity => _hasDeviceConnectivity;

  /// Backend /health responded OK on last check.
  bool get isBackendReachable => _isBackendReachable;

  /// Prefer this for cart writes: attempt real API when the device has network.
  bool get canAttemptApi => _hasDeviceConnectivity;

  /// Legacy: both device network and health check passed.
  bool get isOnline => _hasDeviceConnectivity && _isBackendReachable;

  DioClient? _dioClient;
  bool _processingQueue = false;
  bool _refreshInFlight = false;

  final List<VoidCallback> _becameOnlineListeners = [];

  void attachDioClient(DioClient dioClient) {
    _dioClient ??= dioClient;
  }

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

  /// Force an immediate connectivity + health re-check (e.g. cart screen open).
  Future<void> refreshNow() => _refreshStatus();

  void _scheduleRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(_refreshStatus());
    });
  }

  Future<void> stop() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _healthPollTimer?.cancel();
    _healthPollTimer = null;
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _refreshStatus() async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    try {
      final hasDevice = await _checkDeviceConnectivity();
      final healthOk = hasDevice ? await _checkBackendHealth() : false;

      final prevDevice = _hasDeviceConnectivity;
      final prevReachable = _isBackendReachable;
      _hasDeviceConnectivity = hasDevice;
      _isBackendReachable = healthOk;

      if (prevDevice != _hasDeviceConnectivity || prevReachable != _isBackendReachable) {
        notifyListeners();
      }

      final wasFullyOffline = !prevDevice || !prevReachable;
      final nowCanSync = _hasDeviceConnectivity && _isBackendReachable;
      if (wasFullyOffline && nowCanSync) {
        await _processQueue();
        _notifyBecameOnline();
      } else if (_hasDeviceConnectivity && !prevReachable && _isBackendReachable) {
        // Device was on Wi‑Fi but /health failed; server came back.
        await _processQueue();
        _notifyBecameOnline();
      }

      _scheduleHealthPoll();
    } finally {
      _refreshInFlight = false;
    }
  }

  void _scheduleHealthPoll() {
    _healthPollTimer?.cancel();
    if (_hasDeviceConnectivity && !_isBackendReachable) {
      _healthPollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
        unawaited(_refreshStatus());
      });
    }
  }

  Future<bool> _checkDeviceConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  static bool _healthBodyOk(dynamic data) {
    if (data is Map) {
      final status = data['status']?.toString().toLowerCase();
      if (status == 'ok') return true;
    }
    if (data is String) {
      return data.toLowerCase().contains('ok');
    }
    return false;
  }

  Future<bool> _checkBackendHealth() async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        sendTimeout: const Duration(seconds: 4),
      ));
      final res = await dio.get(ApiEndpoints.health);
      if (res.statusCode == 200) {
        if (_healthBodyOk(res.data)) return true;
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
