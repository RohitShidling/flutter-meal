import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiEndpoints {
  static String get baseUrl {
    final env = dotenv.env['ENVIRONMENT'] ?? 'development';
    
    if (env == 'production') {
      return dotenv.env['API_BASE_URL_PRODUCTION'] ?? '';
    }

    String domain;
    if (Platform.isAndroid) {
      domain = dotenv.env['API_BASE_URL_ANDROID'] ?? 'http://10.0.2.2:3000';
    } else {
      domain = dotenv.env['API_BASE_URL_IOS'] ?? 'http://localhost:3000';
    }
    return domain;
  }

  // Auth
  static const String sendOtp = '/api/client/auth/send-otp';
  static const String verifyOtp = '/api/client/auth/verify-otp';
  static const String logout = '/api/client/auth/logout';
  static const String refresh = '/api/client/auth/refresh';
  static const String me = '/api/client/auth/me';

  // Children
  static const String children = '/api/client/children';
  static String child(String id) => '/api/client/children/$id';

  // Profiles
  static const String parentProfile = '/api/client/parent/profile';
  static const String professionalProfile = '/api/client/professional/profile';
  static const String teacherProfile = '/api/client/teacher/profile';

  // Lookup
  static const String schools = '/api/common/schools';
  static const String mealSizes = '/api/common/lookup/meal-sizes';
  static const String standards = '/api/common/lookup/standards';
  static const String corporateLocations = '/api/common/corporate-locations';
  static const String subscriptions = '/api/common/subscriptions';

  // Payment
  static const String initiatePayment = '/api/client/payment/initiate';
  static String paymentStatus(String txnId) => '/api/client/payment/status/$txnId';
  static const String paymentHistory = '/api/client/payment/history';
  static const String activeSubscriptions = '/api/client/payment/active-subscriptions';
  static String get paymentStatusPage => '$baseUrl/api/client/payment/status-page';
}

