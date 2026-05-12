import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/providers/session_provider.dart';
import 'package:meal_app/core/storage/secure_storage.dart';

class DioClient {
  late Dio _dio;
  final SecureStorage _secureStorage;
  final SessionProvider? _sessionProvider;

  DioClient(this._secureStorage, {SessionProvider? sessionProvider})
      : _sessionProvider = sessionProvider {
    _dio = Dio(BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Never emit full HTTP logs in release builds to avoid leaking tokens/PII.
    if (!kReleaseMode) {
      _dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: false, // hides Authorization bearer token
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
      ));
    }

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final accessToken = await _secureStorage.getAccessToken();
        if (accessToken != null) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (_isTransientNetworkError(e)) {
          final retried = await _retryRequest(e.requestOptions);
          if (retried != null) {
            return handler.resolve(retried);
          }
        }

        if (e.response?.statusCode == 401) {
          // Don't try to refresh on the refresh endpoint itself — would loop forever.
          final isRefreshCall = e.requestOptions.path.contains(ApiEndpoints.refresh);
          if (isRefreshCall) {
            await _expireSession('Refresh token rejected by server.');
            return handler.next(e);
          }

          // Token might be expired, try to refresh
          final newAccessToken = await _refreshToken();
          if (newAccessToken != null) {
            // Update the original request with the new token
            e.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
            try {
              // Retry the request
              final response = await _dio.fetch(e.requestOptions);
              return handler.resolve(response);
            } catch (retryError) {
              return handler.next(e);
            }
          } else {
            // Refresh failed — clear tokens AND signal session expired so the
            // UI can force-route the user to the login screen.
            await _secureStorage.clearTokens();
            await _expireSession('Your session has expired. Please log in again.');
          }
        }
        return handler.next(e);
      },
    ));
  }

  Future<String?>? _refreshFuture;

  bool _isTransientNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout;
  }

  Future<Response<dynamic>?> _retryRequest(RequestOptions requestOptions) async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.isNotEmpty && results.every((r) => r == ConnectivityResult.none)) {
        return null;
      }
    } catch (_) {/* fall through */}

    const maxRetries = 1;
    var attempt = 0;
    while (attempt < maxRetries) {
      attempt += 1;
      await Future.delayed(Duration(milliseconds: 400 * attempt));
      try {
        return await _dio.fetch(requestOptions);
      } catch (e) {
        if (e is DioException && !_isTransientNetworkError(e)) {
          return null;
        }
      }
    }
    return null;
  }

  Future<String?> _refreshToken() async {
    if (_refreshFuture != null) {
      return _refreshFuture;
    }

    _refreshFuture = _performRefresh();
    try {
      final token = await _refreshFuture;
      return token;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<String?> _performRefresh() async {
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken == null) return null;

      // Note: We use a separate Dio instance to avoid infinite loops in interceptors
      final tokenDio = Dio(BaseOptions(baseUrl: ApiEndpoints.baseUrl));
      final response = await tokenDio.post(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        // Assume API returns similar structure to login
        final accessToken = response.data['data']['accessToken'];
        final newRefreshToken = response.data['data']['refreshToken'];
        await _secureStorage.saveTokens(accessToken, newRefreshToken);
        return accessToken;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Best-effort: clear tokens and notify the session provider once.
  /// All errors are swallowed so the original API error reaches the caller.
  Future<void> _expireSession(String reason) async {
    try {
      await _secureStorage.clearTokens();
    } catch (_) {/* ignore */}
    try {
      _sessionProvider?.expire(reason: reason);
    } catch (_) {/* ignore */}
  }

  Dio get dio => _dio;
}
