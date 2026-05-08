import 'dart:convert';
import 'dart:io';
import 'dart:developer' as dev;
import 'package:phonepe_payment_sdk/phonepe_payment_sdk.dart';

/// Wraps the official PhonePe Flutter SDK.
///
/// The backend returns a [paymentUrl] like:
///   https://mercury-uat.phonepe.com/transact/uat_v3?token=<JWT>&routingKey=W
///
/// This service extracts the JWT token and merchantId from the URL,
/// builds the SDK request payload, and starts the transaction.
class PhonePeService {
  PhonePeService._();

  // iOS app URL scheme for return-to-app deep link (must match Info.plist CFBundleURLSchemes)
  static const String _appSchema = 'buuttii';

  /// Extracts the JWT token from the paymentUrl query parameter.
  static String _extractToken(String paymentUrl) {
    try {
      final uri = Uri.parse(paymentUrl);
      return uri.queryParameters['token'] ?? '';
    } catch (e) {
      return '';
    }
  }

  /// Decodes the JWT payload (Base64url) to extract merchantId.
  static Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return {};
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final bytes = base64Url.decode(normalized);
      return json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (e) {
      dev.log('JWT decode error: $e');
      return {};
    }
  }

  /// Initializes the PhonePe SDK and starts the payment transaction.
  ///
  /// Returns a map with keys:
  ///   - `status`: "SUCCESS" | "FAILURE" | "INTERRUPTED"
  ///   - `error`: error message if any
  ///
  /// Throws if [paymentUrl] or [orderId] are invalid.
  static Future<Map<String, dynamic>> pay({
    required String orderId,
    String? paymentUrl,
    String? backendToken,
    String? backendMerchantId,
    required bool isSandbox,
  }) async {
    final token = backendToken ?? (paymentUrl != null ? _extractToken(paymentUrl) : '');
    if (token.isEmpty) {
      throw Exception('Invalid payment configuration: token not found');
    }

    final jwtPayload = _decodeJwt(token);
    final merchantId = backendMerchantId ?? (jwtPayload['merchantId'] as String?) ?? '';
    if (merchantId.isEmpty) {
      throw Exception('Could not extract merchantId from payment token');
    }

    final environment = isSandbox ? 'SANDBOX' : 'PRODUCTION';

    dev.log('PhonePe init started: env=$environment, orderId=$orderId');

    // Step 1: Initialize the SDK
    final bool initialized = await PhonePePaymentSdk.init(
      environment,
      merchantId,
      orderId, // flowId — unique per user journey
      false,   // enableLogs — set true only for debugging
    );

    if (!initialized) {
      throw Exception('PhonePe SDK initialization failed');
    }

    // Step 2: Build the request payload
    final Map<String, dynamic> payload = {
      'orderId': orderId,
      'merchantId': merchantId,
      'token': token,
      'paymentMode': {'type': 'PAY_PAGE'},
    };
    final String request = json.encode(payload);

    dev.log('PhonePe startTransaction invoked');

    String schema = '';
    if (Platform.isIOS) {
      schema = _appSchema;
    }
    
    // Step 3: Start transaction — SDK opens PhonePe app or web page
    final Map<dynamic, dynamic>? response =
        await PhonePePaymentSdk.startTransaction(request, schema);

    dev.log('PhonePe response received: hasResponse=${response != null}');

    if (response == null) {
      return {'status': 'INTERRUPTED', 'error': 'User cancelled or no response'};
    }

    return {
      'status': response['status']?.toString() ?? 'FAILURE',
      'error': response['error']?.toString() ?? '',
    };
  }
}
