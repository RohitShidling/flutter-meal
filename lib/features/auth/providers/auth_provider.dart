import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meal_app/core/services/network_status_service.dart';
import 'package:meal_app/features/auth/data/repositories/auth_repository.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }
enum AuthMode { login, register }

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository;

  AuthState _state = AuthState.initial;
  AuthMode _authMode = AuthMode.login;
  String _errorMessage = '';
  String _phoneNumber = '';
  String _username = '';
  bool _isProfileLoading = false;
  bool _pendingDashboardRefresh = false;

  AuthProvider(this._authRepository) {
    _checkAuthStatus();
  }

  AuthState get state => _state;
  AuthMode get authMode => _authMode;
  String get errorMessage => _errorMessage;
  String get phoneNumber => _phoneNumber;
  String get username => _username;
  bool get isProfileLoading => _isProfileLoading;

  void setAuthMode(AuthMode mode) {
    _authMode = mode;
    _errorMessage = '';
    notifyListeners();
  }

  Future<void> _checkAuthStatus() async {
    // Stay on [initial] until we know the session — so the splash can paint.
    // [loading] is reserved for user-triggered actions (OTP, etc.).
    final isAuthenticated = await _authRepository.isAuthenticated();
    if (isAuthenticated) {
      _phoneNumber = await _authRepository.getPhoneNumber() ?? '';
      _username = await _authRepository.getUsername() ?? '';
      _state = AuthState.authenticated;
      notifyListeners();
      // Offline-first: never block cold start on /auth/me — paint home from
      // cache immediately, then revalidate quietly when reachable.
      unawaited(refreshMeProfile(silent: true));
    } else {
      _state = AuthState.unauthenticated;
      notifyListeners();
    }
  }

  /// After OTP login/register, home should force-refresh dashboard APIs once.
  void markPendingDashboardRefresh() {
    _pendingDashboardRefresh = true;
  }

  bool consumePendingDashboardRefresh() {
    if (!_pendingDashboardRefresh) return false;
    _pendingDashboardRefresh = false;
    return true;
  }

  // ─── LOGIN FLOW ────────────────────────────────────────────────────────────

  Future<bool> loginSendOtp(String phone) async {
    _state = AuthState.loading;
    _errorMessage = '';
    _phoneNumber = phone;
    notifyListeners();

    try {
      final success = await _authRepository.loginSendOtp(phone);
      if (success) {
        _state = AuthState.unauthenticated;
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

  Future<bool> loginVerifyOtp(String code) async {
    _state = AuthState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final success = await _authRepository.loginVerifyOtp(_phoneNumber, code);
      if (success) {
        markPendingDashboardRefresh();
        await refreshMeProfile(silent: true, forceNetwork: true);
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

  // ─── REGISTER FLOW ────────────────────────────────────────────────────────

  Future<bool> registerSendOtp(String phone, String username) async {
    _state = AuthState.loading;
    _errorMessage = '';
    _phoneNumber = phone;
    _username = username;
    notifyListeners();

    try {
      final success = await _authRepository.registerSendOtp(phone, username);
      if (success) {
        _state = AuthState.unauthenticated;
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

  Future<bool> registerVerifyOtp(String code) async {
    _state = AuthState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final success = await _authRepository.registerVerifyOtp(_phoneNumber, _username, code);
      if (success) {
        markPendingDashboardRefresh();
        await refreshMeProfile(silent: true, forceNetwork: true);
        _state = AuthState.authenticated;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Invalid OTP or registration failed';
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

  // ─── LOGOUT ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    _state = AuthState.loading;
    notifyListeners();

    await _authRepository.logout();
    
    _state = AuthState.unauthenticated;
    _phoneNumber = '';
    _username = '';
    _authMode = AuthMode.login;
    notifyListeners();
  }

  Future<void> refreshMeProfile({bool silent = false, bool forceNetwork = false}) async {
    if (!silent) {
      _isProfileLoading = true;
      notifyListeners();
    }
    try {
      if (!forceNetwork && !NetworkStatusService.instance.isOnline) {
        final cached = await _authRepository.getUsername();
        if (cached != null && cached.trim().isNotEmpty) {
          _username = cached.trim();
        }
        return;
      }
      final liveUsername = await _authRepository.fetchCurrentUsername();
      if (liveUsername != null && liveUsername.trim().isNotEmpty) {
        _username = liveUsername.trim();
      }
    } finally {
      _isProfileLoading = false;
      notifyListeners();
    }
  }
}
