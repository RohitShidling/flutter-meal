import 'package:meal_app/core/network/dio_client.dart';
import 'package:meal_app/core/network/api_endpoints.dart';

class PaymentRepository {
  final DioClient _dioClient;

  PaymentRepository(this._dioClient);

  Future<Map<String, dynamic>> initiatePayment({
    required String subscriptionId,
    required String entityType,
    required String entityId,
    String? customRedirectUrl,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.initiatePayment,
        data: {
          'subscriptionId': subscriptionId,
          'entityType': entityType,
          'entityId': entityId,
          if (customRedirectUrl != null) 'customRedirectUrl': customRedirectUrl,
        },
      );

      if (response.data['success'] == true) {
        return response.data['data'];
      } else {
        throw response.data['message'] ?? 'Failed to initiate payment';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getPaymentStatus(String txnId) async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.paymentStatus(txnId));
      if (response.data['success'] == true) {
        return response.data['data'];
      } else {
        throw response.data['message'] ?? 'Failed to get payment status';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getPaymentHistory() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.paymentHistory);
      if (response.data['success'] == true) {
        return response.data['data'] ?? [];
      } else {
        throw response.data['message'] ?? 'Failed to fetch payment history';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getActiveSubscriptions() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.activeSubscriptions);
      if (response.data['success'] == true) {
        return response.data['data'] ?? [];
      } else {
        throw response.data['message'] ?? 'Failed to fetch active subscriptions';
      }
    } catch (e) {
      rethrow;
    }
  }
}
