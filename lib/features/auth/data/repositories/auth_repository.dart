import 'package:dio/dio.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/network/dio_client.dart';
import 'package:meal_app/core/storage/secure_storage.dart';

class AuthRepository {
  final DioClient _dioClient;
  final SecureStorage _secureStorage;

  AuthRepository(this._dioClient, this._secureStorage);

  Future<bool> sendOtp(String phoneNumber) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.sendOtp,
        data: {'phoneNumber': phoneNumber},
      );
      
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<bool> verifyOtp(String phoneNumber, String code) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.verifyOtp,
        data: {
          'phoneNumber': phoneNumber,
          'code': code,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        final accessToken = data['accessToken'];
        final refreshToken = data['refreshToken'];
        
        await _secureStorage.saveTokens(accessToken, refreshToken);
        await _secureStorage.savePhoneNumber(phoneNumber);
        return true;
      }
      return false;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

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

  String _handleError(DioException error) {
    if (error.response != null) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx
      if (error.response?.data != null && error.response?.data['message'] != null) {
         return error.response?.data['message'];
      }
      return 'Server error: ${error.response?.statusCode}';
    } else {
      // Something happened in setting up or sending the request that triggered an Error
      return 'Network error: Please check your connection.';
    }
  }
}
