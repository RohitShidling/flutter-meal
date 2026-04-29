import 'package:dio/dio.dart';
import 'package:meal_app/core/models/lookup_models.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/network/dio_client.dart';

class LookupRepository {
  final DioClient _dioClient;

  LookupRepository(this._dioClient);

  Future<List<SchoolModel>> getSchools({String? search, int? page, int? limit}) async {
    try {
      final response = await _dioClient.dio.get(
        ApiEndpoints.schools,
        queryParameters: {
          if (search != null) 'search': search,
          if (page != null) 'page': page,
          if (limit != null) 'limit': limit,
        },
      );
      
      if (response.data['success'] == true) {
        final List schools = response.data['data']['schools'];
        return schools.map((s) => SchoolModel.fromJson(s)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<StandardModel>> getStandards() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.standards);
      if (response.data['success'] == true) {
        final List standards = response.data['data']['standards'];
        return standards.map((s) => StandardModel.fromJson(s)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<MealSizeModel>> getMealSizes() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.mealSizes);
      if (response.data['success'] == true) {
        final List sizes = response.data['data']['mealSizes'];
        return sizes.map((s) => MealSizeModel.fromJson(s)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<CorporateLocationModel>> getCorporateLocations() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.corporateLocations);
      if (response.data['success'] == true) {
        final List locations = response.data['data'];
        return locations.map((l) => CorporateLocationModel.fromJson(l)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  Future<List<Map<String, dynamic>>> getSubscriptions() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.subscriptions);
      if (response.data['success'] == true) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
