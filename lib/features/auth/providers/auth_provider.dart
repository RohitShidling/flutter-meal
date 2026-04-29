import 'package:flutter/material.dart';
import 'package:meal_app/features/auth/data/repositories/auth_repository.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository;

  AuthState _state = AuthState.initial;
  String _errorMessage = '';
  String _phoneNumber = '';

  AuthProvider(this._authRepository) {
    _checkAuthStatus();
  }

  AuthState get state => _state;
  String get errorMessage => _errorMessage;
  String get phoneNumber => _phoneNumber;

  Future<void> _checkAuthStatus() async {
    _state = AuthState.loading;
    notifyListeners();

    final isAuthenticated = await _authRepository.isAuthenticated();
    if (isAuthenticated) {
      _phoneNumber = await _authRepository.getPhoneNumber() ?? '';
      _state = AuthState.authenticated;
    } else {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> sendOtp(String phone) async {
    _state = AuthState.loading;
    _errorMessage = '';
    _phoneNumber = phone;
    notifyListeners();

    try {
      final success = await _authRepository.sendOtp(phone);
      if (success) {
        _state = AuthState.unauthenticated; // Still unauth, but ready for OTP
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to send OTP';
        _state = AuthState.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp(String code) async {
    _state = AuthState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final success = await _authRepository.verifyOtp(_phoneNumber, code);
      if (success) {
        _state = AuthState.authenticated;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Invalid OTP';
        _state = AuthState.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _state = AuthState.loading;
    notifyListeners();

    await _authRepository.logout();
    
    _state = AuthState.unauthenticated;
    _phoneNumber = '';
    notifyListeners();
  }
}
