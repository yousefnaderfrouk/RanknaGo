import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../config/paymob_config.dart';

class PaymobService {
  String? _authToken;

  // 1. الحصول على Auth Token
  Future<String> _getAuthToken() async {
    if (_authToken != null) return _authToken!;

    if (!PaymobConfig.isConfigured) {
      throw Exception('Paymob API Key not configured');
    }

    try {
      if (PaymobConfig.apiKey == null || PaymobConfig.apiKey!.isEmpty) {
        throw Exception('API Key is null or empty');
      }

      // Clean API Key one more time before sending
      final cleanApiKey = PaymobConfig.apiKey!.trim().replaceAll(
        RegExp(r'\s+'),
        '',
      );

      print('🔑 Attempting to get Paymob auth token...');
      print('🔑 API Key length: ${cleanApiKey.length}');
      print(
        '🔑 API Key preview: ${cleanApiKey.substring(0, cleanApiKey.length > 30 ? 30 : cleanApiKey.length)}...',
      );
      print(
        '🔑 API Key ends with: ...${cleanApiKey.substring(cleanApiKey.length - 10)}',
      );
      print('🔑 Auth URL: ${PaymobConfig.authUrl}');
      print('🔑 Test Mode: ${PaymobConfig.isTestMode}');

      final response = await http.post(
        Uri.parse(PaymobConfig.authUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'api_key': cleanApiKey}),
      );

      print('📡 Paymob Auth Response - Status: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _authToken = data['token'] as String;
        print('✅ Paymob Auth Token obtained successfully');
        return _authToken!;
      } else {
        final errorBody = response.body;
        print('❌ Paymob Auth Error - Status: ${response.statusCode}');
        print('❌ Paymob Auth Error - Body: $errorBody');

        // Try to parse error message
        try {
          final errorData = jsonDecode(errorBody);
          if (errorData['detail'] != null) {
            throw Exception('Paymob API Error: ${errorData['detail']}');
          }
        } catch (_) {
          // If parsing fails, use raw body
        }

        throw Exception('Failed to get auth token: $errorBody');
      }
    } catch (e) {
      print('❌ Paymob Auth Exception: $e');
      throw Exception('Error getting auth token: $e');
    }
  }

  // 2. إنشاء Order
  Future<Map<String, dynamic>> createOrder({
    required double amount,
    required List<Map<String, dynamic>> items,
    required String currency,
  }) async {
    final token = await _getAuthToken();

    try {
      final response = await http.post(
        Uri.parse(PaymobConfig.orderUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'auth_token': token,
          'delivery_needed': false,
          'amount_cents': (amount * 100).toInt(),
          'currency': currency,
          'items': items,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create order: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating order: $e');
    }
  }

  // 3. الحصول على Payment Key للبطاقات
  Future<String> getCardPaymentKey({
    required int orderId,
    required double amount,
    required String currency,
    required Map<String, dynamic> billingData,
  }) async {
    final token = await _getAuthToken();

    if (PaymobConfig.cardIntegrationId == null) {
      throw Exception('Card Integration ID not configured');
    }

    try {
      final response = await http.post(
        Uri.parse(PaymobConfig.paymentKeyUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'auth_token': token,
          'amount_cents': (amount * 100).toInt(),
          'expiration': 3600,
          'order_id': orderId,
          'billing_data': billingData,
          'currency': currency,
          'integration_id': PaymobConfig.cardIntegrationId,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['token'] as String;
      } else {
        throw Exception('Failed to get payment key: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error getting payment key: $e');
    }
  }

  // 4. الحصول على Payment Key للـ Fawry
  Future<String> getFawryPaymentKey({
    required int orderId,
    required double amount,
    required String currency,
    required Map<String, dynamic> billingData,
  }) async {
    final token = await _getAuthToken();

    if (PaymobConfig.fawryIntegrationId == null) {
      throw Exception('Fawry Integration ID not configured');
    }

    try {
      final response = await http.post(
        Uri.parse(PaymobConfig.paymentKeyUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'auth_token': token,
          'amount_cents': (amount * 100).toInt(),
          'expiration': 3600,
          'order_id': orderId,
          'billing_data': billingData,
          'currency': currency,
          'integration_id': PaymobConfig.fawryIntegrationId,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['token'] as String;
      } else {
        throw Exception('Failed to get Fawry payment key: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error getting Fawry payment key: $e');
    }
  }

  // 5. الحصول على Payment Key للمحافظ الرقمية
  Future<String> getMobileWalletPaymentKey({
    required int orderId,
    required double amount,
    required String currency,
    required Map<String, dynamic> billingData,
  }) async {
    final token = await _getAuthToken();

    if (PaymobConfig.mobileWalletIntegrationId == null) {
      throw Exception('Mobile Wallet Integration ID not configured');
    }

    try {
      final response = await http.post(
        Uri.parse(PaymobConfig.paymentKeyUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'auth_token': token,
          'amount_cents': (amount * 100).toInt(),
          'expiration': 3600,
          'order_id': orderId,
          'billing_data': billingData,
          'currency': currency,
          'integration_id': PaymobConfig.mobileWalletIntegrationId,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['token'] as String;
      } else {
        throw Exception(
          'Failed to get Mobile Wallet payment key: ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error getting Mobile Wallet payment key: $e');
    }
  }

  // 6. التحقق من HMAC (للأمان)
  bool verifyHMAC({
    required Map<String, dynamic> data,
    required String receivedHMAC,
  }) {
    if (PaymobConfig.hmacKey == null) return false;

    final hmacString = data.entries
        .where((e) => e.key != 'hmac')
        .map((e) => '${e.key}=${e.value}')
        .join('&');

    final key = utf8.encode(PaymobConfig.hmacKey!);
    final bytes = utf8.encode(hmacString);
    final hmac = Hmac(sha512, key);
    final digest = hmac.convert(bytes);

    return digest.toString() == receivedHMAC;
  }

  // 7. إنشاء رابط الدفع للبطاقات
  String getCardPaymentUrl(String paymentKey) {
    // استخدام IFrame ID إذا كان متوفراً، وإلا استخدام Card Integration ID
    final iframeId = PaymobConfig.iframeId ?? PaymobConfig.cardIntegrationId;
    if (iframeId == null) {
      throw Exception('Card Integration ID or IFrame ID not configured');
    }
    return 'https://accept.paymob.com/api/acceptance/iframes/$iframeId?payment_token=$paymentKey';
  }

  // 8. إنشاء رابط الدفع للـ Fawry
  String getFawryPaymentUrl(String paymentKey) {
    return 'https://accept.paymob.com/api/acceptance/payments/pay?token=$paymentKey';
  }
}
