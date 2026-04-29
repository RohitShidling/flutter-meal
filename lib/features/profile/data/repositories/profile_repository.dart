import 'package:dio/dio.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/network/dio_client.dart';
import 'package:meal_app/features/profile/data/models/profile_models.dart';

class ProfileRepository {
  final DioClient _dioClient;

  ProfileRepository(this._dioClient);

  // Teacher Profile
  Future<TeacherProfileModel?> getTeacherProfile() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.teacherProfile);
      if (response.data['success'] == true && response.data['data'] != null) {
        return TeacherProfileModel.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveTeacherProfile(TeacherProfileModel profile, {bool isUpdate = false}) async {
    try {
      final response = isUpdate 
        ? await _dioClient.dio.put(ApiEndpoints.teacherProfile, data: profile.toJson())
        : await _dioClient.dio.post(ApiEndpoints.teacherProfile, data: profile.toJson());
      return response.data['success'] == true;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteTeacherProfile() async {
    try {
      final response = await _dioClient.dio.delete(ApiEndpoints.teacherProfile);
      return response.data['success'] == true;
    } catch (e) {
      rethrow;
    }
  }

  // Professional Profile
  Future<ProfessionalProfileModel?> getProfessionalProfile() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.professionalProfile);
      if (response.data['success'] == true && response.data['data'] != null) {
        return ProfessionalProfileModel.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveProfessionalProfile(ProfessionalProfileModel profile, {bool isUpdate = false}) async {
    try {
      final response = isUpdate 
        ? await _dioClient.dio.put(ApiEndpoints.professionalProfile, data: profile.toJson())
        : await _dioClient.dio.post(ApiEndpoints.professionalProfile, data: profile.toJson());
      return response.data['success'] == true;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getProfileStatus() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.me);
      if (response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
