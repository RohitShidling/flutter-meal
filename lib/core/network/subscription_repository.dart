import 'package:dio/dio.dart';
import 'package:meal_app/core/models/subscription_model.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/network/dio_client.dart';

class SubscriptionRepository {
  final DioClient _dioClient;

  SubscriptionRepository(this._dioClient);

  Future<List<SubscriptionModel>> getSubscriptions() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.subscriptions);
      if (response.data['success'] == true) {
        final List data = response.data['data'];
        return data.map((s) => SubscriptionModel.fromJson(s)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<SubscriptionModel?> getSubscriptionById(String id) async {
    try {
      final response = await _dioClient.dio.get('${ApiEndpoints.subscriptions}/$id');
      if (response.data['success'] == true) {
        return SubscriptionModel.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }
}
