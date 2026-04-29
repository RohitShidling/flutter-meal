import 'package:flutter/material.dart';
import 'package:meal_app/core/network/payment_repository.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/services/phonepe_service.dart';

/// Payment status returned after the SDK transaction completes.
enum PaymentStatus { none, processing, success, failure, interrupted }

class PaymentProvider with ChangeNotifier {
  final PaymentRepository _repository;

  PaymentProvider(this._repository);

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

  Future<void> fetchPaymentHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _paymentHistory = await _repository.getPaymentHistory();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Active Subscriptions ──────────────────────────────────────────────────

  Future<void> fetchActiveSubscriptions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _activeSubscriptions = await _repository.getActiveSubscriptions();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
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
        customRedirectUrl: ApiEndpoints.paymentStatusPage,
      );

      final String? paymentUrl = paymentData['paymentUrl'];
      final String orderId = paymentData['orderId'] ?? '';
      final String txnId = paymentData['merchantTransactionId'] ?? '';

      if (paymentUrl == null || paymentUrl.isEmpty) {
        throw Exception('Payment URL not received from gateway');
      }

      _lastTxnId = txnId;

      // Step 2: Trigger the native PhonePe SDK
      final sdkResult = await PhonePeService.pay(
        orderId: orderId,
        paymentUrl: paymentUrl,
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
      _error = e.toString().replaceAll('Exception:', '').trim();
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
      _error = e.toString();
      return null;
    }
  }

  void resetStatus() {
    _paymentStatus = PaymentStatus.none;
    _error = null;
    notifyListeners();
  }
}
