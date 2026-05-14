import 'package:flutter/material.dart';
import 'package:meal_app/core/network/payment_repository.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/services/phonepe_service.dart';
import 'package:meal_app/core/storage/local_cache.dart';
import 'package:meal_app/core/utils/error_handler.dart';

/// Payment status returned after the SDK transaction completes.
enum PaymentStatus { none, processing, success, failure, interrupted }

class PaymentProvider with ChangeNotifier {
  final PaymentRepository _repository;
  final LocalCache _cache;
  static const _historyCacheKey = 'cache_payment_history_v1';
  static const _activeCacheKey = 'cache_active_subscriptions_v1';

  PaymentProvider(this._repository, this._cache) {
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    try {
      final cachedHistory = await _cache.loadJson(_historyCacheKey);
      if (cachedHistory != null) {
        _paymentHistory = (cachedHistory['items'] as List? ?? const []).toList();
      }
      final cachedActive = await _cache.loadJson(_activeCacheKey);
      if (cachedActive != null) {
        _activeSubscriptions = (cachedActive['items'] as List? ?? const []).toList();
      }
      notifyListeners();
    } catch (_) {}
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  PaymentStatus _paymentStatus = PaymentStatus.none;
  PaymentStatus get paymentStatus => _paymentStatus;

  String? _lastTxnId;
  String? get lastTxnId => _lastTxnId;

  List<dynamic> _paymentHistory = [];
  List<dynamic> get paymentHistory => _paymentHistory;

  List<dynamic> _activeSubscriptions = [];
  List<dynamic> get activeSubscriptions => _activeSubscriptions;

  // ─── Payment History ───────────────────────────────────────────────────────

  Future<void> fetchPaymentHistory({bool silent = false}) async {
    bool hasCachedData = false;
    final cached = await _cache.loadJson(_historyCacheKey);
    if (cached != null && _paymentHistory.isEmpty) {
      _paymentHistory = (cached['items'] as List? ?? const []).toList();
      hasCachedData = _paymentHistory.isNotEmpty;
      notifyListeners();
    } else if (_paymentHistory.isNotEmpty) {
      hasCachedData = true;
    }

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      _paymentHistory = await _repository.getPaymentHistory();
      await _cache.saveJson(_historyCacheKey, {'items': _paymentHistory});
    } catch (e) {
      // Keep showing cached history in offline mode; only show hard error if nothing cached.
      _error = hasCachedData ? null : ErrorHandler.getErrorMessage(e);
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // ─── Active Subscriptions ──────────────────────────────────────────────────

  Future<void> fetchActiveSubscriptions({bool silent = false}) async {
    bool hasCachedData = false;
    final cached = await _cache.loadJson(_activeCacheKey);
    if (cached != null && _activeSubscriptions.isEmpty) {
      _activeSubscriptions = (cached['items'] as List? ?? const []).toList();
      hasCachedData = _activeSubscriptions.isNotEmpty;
      notifyListeners();
    } else if (_activeSubscriptions.isNotEmpty) {
      hasCachedData = true;
    }

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      _activeSubscriptions = await _repository.getActiveSubscriptions();
      await _cache.saveJson(_activeCacheKey, {'items': _activeSubscriptions});
    } catch (e) {
      // Keep showing cached plans in offline mode; only show hard error if nothing cached.
      _error = hasCachedData ? null : ErrorHandler.getErrorMessage(e);
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // ─── Checkout via PhonePe SDK ──────────────────────────────────────────────

  /// Full checkout flow:
  /// 1. Call backend to initiate the payment order → get paymentUrl + orderId
  /// 2. Pass the paymentUrl to [PhonePeService.pay] which drives the native SDK
  /// 3. Return the SDK status (SUCCESS / FAILURE / INTERRUPTED)
  Future<Map<String, dynamic>?> initiateCheckout({
    required String subscriptionId,
    required String entityType,
    required String entityId,
    required bool includeSaturday,
    String? startDate,
    bool isSandbox = true, // set false for production
  }) async {
    _isLoading = true;
    _paymentStatus = PaymentStatus.processing;
    _error = null;
    notifyListeners();

    try {
      // Step 1: Create the order on the backend
      final paymentData = await _repository.initiatePayment(
        subscriptionId: subscriptionId,
        entityType: entityType,
        entityId: entityId,
        includeSaturday: includeSaturday,
        startDate: startDate,
        customRedirectUrl: ApiEndpoints.paymentStatusPage,
      );

      final String? paymentUrl = paymentData['paymentUrl'];
      final String orderId = paymentData['orderId'] ?? '';
      final String txnId = paymentData['merchantTransactionId'] ?? '';
      final String? backendToken = paymentData['token'] ?? paymentData['orderToken'];
      final String? backendMerchantId = paymentData['merchantId'];

      if ((paymentUrl == null || paymentUrl.isEmpty) && backendToken == null) {
        throw Exception('Payment information not received from gateway');
      }

      _lastTxnId = txnId;

      // Step 2: Trigger the native PhonePe SDK
      final sdkResult = await PhonePeService.pay(
        orderId: orderId,
        paymentUrl: paymentUrl,
        backendToken: backendToken,
        backendMerchantId: backendMerchantId,
        isSandbox: isSandbox,
      );

      // Step 3: Map SDK status to enum
      final status = sdkResult['status'] as String? ?? 'FAILURE';
      if (status == 'SUCCESS') {
        _paymentStatus = PaymentStatus.success;
      } else if (status == 'INTERRUPTED') {
        _paymentStatus = PaymentStatus.interrupted;
      } else {
        _paymentStatus = PaymentStatus.failure;
      }

      return {
        ...paymentData,
        'sdkStatus': status,
        'sdkError': sdkResult['error'],
      };
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      _paymentStatus = PaymentStatus.failure;
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Status Polling ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> checkStatus(String txnId) async {
    try {
      return await _repository.getPaymentStatus(txnId);
    } catch (e) {
      _error = ErrorHandler.getErrorMessage(e);
      return null;
    }
  }

  void resetStatus() {
    _paymentStatus = PaymentStatus.none;
    _error = null;
    notifyListeners();
  }
}
