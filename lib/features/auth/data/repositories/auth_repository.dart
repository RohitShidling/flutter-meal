import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/network/dio_client.dart';
import 'package:meal_app/core/storage/secure_storage.dart';

class AuthRepository {
  final DioClient _dioClient;
  final SecureStorage _secureStorage;

  static const int _maxUsernameFromJwtChars = 128;

  AuthRepository(this._dioClient, this._secureStorage);

  // ─── LOGIN FLOW (existing user) ────────────────────────────────────────────

  Future<bool> loginSendOtp(String phoneNumber) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.loginSendOtp,
        data: {'phoneNumber': phoneNumber},
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<bool> loginVerifyOtp(String phoneNumber, String code) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.loginVerifyOtp,
        data: {
          'phoneNumber': phoneNumber,
          'code': code,
        },
      );

      if ((response.statusCode == 200 || response.statusCode == 201) && response.data['success'] == true) {
        final data = response.data['data'];
        final accessToken = data['accessToken'];
        final refreshToken = data['refreshToken'];
        final userName = data['user']?['username']?.toString();
        
        await _secureStorage.saveTokens(accessToken, refreshToken);
        await _secureStorage.savePhoneNumber(phoneNumber);
        if (userName != null && userName.trim().isNotEmpty) {
          await _secureStorage.saveUsername(userName.trim());
        }
        return true;
      }
      return false;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── REGISTER FLOW (new user) ──────────────────────────────────────────────

  Future<bool> registerSendOtp(String phoneNumber, String username, bool consentAccepted) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.registerSendOtp,
        data: {
          'phoneNumber': phoneNumber,
          'username': username,
          'consentAccepted': consentAccepted,
        },
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<bool> registerVerifyOtp(String phoneNumber, String username, String code, bool consentAccepted) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.registerVerifyOtp,
        data: {
          'phoneNumber': phoneNumber,
          'username': username,
          'code': code,
          'consentAccepted': consentAccepted,
        },
      );

      if ((response.statusCode == 200 || response.statusCode == 201) && response.data['success'] == true) {
        final data = response.data['data'];
        final accessToken = data['accessToken'];
        final refreshToken = data['refreshToken'];
        final userName = data['user']?['username']?.toString() ?? username;
        
        await _secureStorage.saveTokens(accessToken, refreshToken);
        await _secureStorage.savePhoneNumber(phoneNumber);
        if (userName.trim().isNotEmpty) {
          await _secureStorage.saveUsername(userName.trim());
        }
        return true;
      }
      return false;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── COMMON ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await _dioClient.dio.post(ApiEndpoints.logout);
    } catch (e) {
      // Even if API fails, clear local tokens
    } finally {
      await _secureStorage.clearTokens();
    }
  }

  Future<bool> isAuthenticated() async {
    final token = await _secureStorage.getAccessToken();
    return token != null;
  }

  Future<String?> getPhoneNumber() async {
    return await _secureStorage.getPhoneNumber();
  }

  Future<String?> getUsername() async {
    final cached = await _secureStorage.getUsername();
    if (cached != null && cached.trim().isNotEmpty) {
      return cached.trim();
    }
    final token = await _secureStorage.getAccessToken();
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      final raw = decoded['username'];
      if (raw is! String) return null;
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      if (trimmed.length > _maxUsernameFromJwtChars) {
        return trimmed.substring(0, _maxUsernameFromJwtChars);
      }
      return trimmed;
    } catch (e) {
      return null;
    }
  }

  Future<String?> fetchCurrentUsername() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.me);
      final userName = response.data['data']?['user']?['username']?.toString();
      if (userName != null && userName.trim().isNotEmpty) {
        await _secureStorage.saveUsername(userName.trim());
        return userName.trim();
      }
      return await getUsername();
    } on DioException {
      // Offline/network fallback to cached username.
      return await getUsername();
    }
  }

  String _handleError(DioException error) {
    if (error.response != null) {
      final data = error.response?.data;
      if (data != null && data is Map) {
        // Check for 'message' field first
        if (data['message'] != null) {
          return data['message'].toString();
        }
        // Check for 'errors' array
        if (data['errors'] != null && data['errors'] is List && (data['errors'] as List).isNotEmpty) {
          return (data['errors'] as List).join(', ');
        }
      }
      return 'Server error: ${error.response?.statusCode}';
    } else {
      return 'Network error: Please check your connection.';
    }
  }
}
