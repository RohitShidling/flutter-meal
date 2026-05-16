import 'package:meal_app/core/network/dio_client.dart';
import 'package:meal_app/core/network/api_endpoints.dart';

class PaymentRepository {
  final DioClient _dioClient;

  PaymentRepository(this._dioClient);

  Future<Map<String, dynamic>> initiatePayment({
    required String subscriptionId,
    required String entityType,
    required String entityId,
    required bool includeSaturday,
    String? startDate,
    String? customRedirectUrl,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.initiatePayment,
        data: {
          'subscriptionId': subscriptionId,
          'entityType': entityType,
          'entityId': entityId,
          'includeSaturday': includeSaturday,
          if (startDate != null) 'startDate': startDate,
          if (customRedirectUrl != null) 'redirectUrl': customRedirectUrl,
        },
      );

      if (response.data['success'] == true) {
        return response.data['data'];
      } else {
        throw response.data['message']?.toString() ?? 'Failed to initiate payment';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchMealSizeUpgradeOptions({
    required String entityType,
    required String entityId,
  }) async {
    final response = await _dioClient.dio.get(
      ApiEndpoints.mealSizeUpgradeOptions,
      queryParameters: {
        'entityType': entityType,
        'entityId': entityId,
      },
    );
    if (response.data['success'] == true) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    throw response.data['message']?.toString() ?? 'Failed to load upgrade options';
  }

  Future<List<dynamic>> fetchMealSizeUpgradePrices() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.mealSizeUpgradePrices);
      if (response.data['success'] == true) {
        return response.data['data'] ?? [];
      }
      throw response.data['message']?.toString() ?? 'Failed to load upgrade prices';
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> initiateMealSizeUpgrade({
    required String entityType,
    required String entityId,
    required int toMealSizeId,
    String? customRedirectUrl,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.initiateMealSizeUpgrade,
        data: {
          'entityType': entityType,
          'entityId': entityId,
          'toMealSizeId': toMealSizeId,
          if (customRedirectUrl != null) 'redirectUrl': customRedirectUrl,
        },
      );
      if (response.data['success'] == true) {
        return response.data['data'];
      }
      throw response.data['message']?.toString() ?? 'Failed to initiate upgrade payment';
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> checkoutCart({String? redirectUrl}) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.checkoutCart,
        data: {
          if (redirectUrl != null) 'redirectUrl': redirectUrl,
        },
      );

      if (response.data['success'] == true) {
        return response.data['data'];
      } else {
        throw response.data['message']?.toString() ?? 'Failed to checkout cart';
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
        throw response.data['message']?.toString() ?? 'Failed to get payment status';
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
        throw response.data['message']?.toString() ?? 'Failed to fetch payment history';
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
        throw response.data['message']?.toString() ?? 'Failed to fetch active subscriptions';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> forceSync(String txnId) async {
    try {
      final response = await _dioClient.dio.post(ApiEndpoints.forceSync(txnId));
      if (response.data['success'] == true) {
        return response.data;
      } else {
        throw response.data['message']?.toString() ?? 'Failed to sync payment';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.subscriptionStatus);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getSubscriptionAlerts() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.subscriptionAlerts);
      if (response.data['success'] == true) {
        return response.data['alerts'] ?? [];
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }
}
