import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  final FlutterSecureStorage _storage;

  SecureStorage() : _storage = const FlutterSecureStorage();

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  static const String _themeKey = 'theme_mode';
  static const String _phoneKey = 'phone_number';
  static const String _usernameKey = 'cached_username';

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> savePhoneNumber(String phone) async {
    await _storage.write(key: _phoneKey, value: phone);
  }

  Future<String?> getPhoneNumber() async {
    return await _storage.read(key: _phoneKey);
  }

  Future<void> saveUsername(String username) async {
    await _storage.write(key: _usernameKey, value: username);
  }

  Future<String?> getUsername() async {
    return await _storage.read(key: _usernameKey);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _phoneKey);
    await _storage.delete(key: _usernameKey);
  }

  Future<void> saveTheme(String theme) async {
    await _storage.write(key: _themeKey, value: theme);
  }

  Future<String?> getTheme() async {
    return await _storage.read(key: _themeKey);
  }
}

