import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/network/payment_repository.dart';
import 'package:meal_app/core/services/phonepe_service.dart';

/// Completes checkout after backend payment init — wallet-only or PhonePe SDK.
class WalletPaymentFlow {
  static Future<Map<String, dynamic>> completeAfterInit({
    required Map<String, dynamic> paymentData,
    required bool isSandbox,
    PaymentRepository? paymentRepository,
  }) async {
    final walletOnly = paymentData['walletOnly'] == true;
    final orderId = paymentData['orderId']?.toString() ?? '';

    if (walletOnly) {
      return {
        ...paymentData,
        'sdkStatus': 'SUCCESS',
        'sdkError': null,
      };
    }

    final paymentUrl = paymentData['paymentUrl']?.toString();
    final backendToken = paymentData['token']?.toString() ?? paymentData['orderToken']?.toString();
    final backendMerchantId = paymentData['merchantId']?.toString();

    if ((paymentUrl == null || paymentUrl.isEmpty) && backendToken == null) {
      throw Exception('Payment information not received from gateway');
    }

    final sdkResult = await PhonePeService.pay(
      orderId: orderId,
      paymentUrl: paymentUrl,
      backendToken: backendToken,
      backendMerchantId: backendMerchantId,
      isSandbox: isSandbox,
    );

    final status = sdkResult['status']?.toString() ?? 'FAILURE';
    final result = {
      ...paymentData,
      'sdkStatus': status,
      'sdkError': sdkResult['error'],
    };

    if (status != 'SUCCESS' && paymentRepository != null) {
      await abandonPendingPayment(paymentRepository, paymentData);
    }

    return result;
  }

  /// Refund wallet debited at initiate when user cancels or PhonePe does not succeed.
  static Future<void> abandonPendingPayment(
    PaymentRepository repository,
    Map<String, dynamic> paymentData,
  ) async {
    final orderId = paymentData['orderId']?.toString();
    final txnId = paymentData['merchantTransactionId']?.toString();
    if ((orderId == null || orderId.isEmpty) && (txnId == null || txnId.isEmpty)) {
      return;
    }
    try {
      await repository.abandonPendingPayment(
        orderId: orderId,
        merchantTransactionId: txnId,
      );
    } catch (_) {
      // Best-effort — status screen may retry abandon on back navigation.
    }
  }
}

/// Whether PhonePe SDK / webview should run for this init response.
bool paymentNeedsGateway(Map<String, dynamic> paymentData) {
  if (paymentData['walletOnly'] == true) return false;
  final url = paymentData['paymentUrl']?.toString() ?? '';
  final token = paymentData['token'] ?? paymentData['orderToken'];
  return url.isNotEmpty || token != null;
}

bool get defaultSandbox => ApiEndpoints.isSandboxPayment;
