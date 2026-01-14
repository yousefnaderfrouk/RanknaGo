class PaymobConfig {
  // سيتم تحميلها من Firestore
  static String? apiKey;
  static String? hmacKey;

  // Integration IDs لكل طريقة دفع
  static int? cardIntegrationId; // MIGS
  static int? fawryIntegrationId; // Accept Kiosk
  static int? mobileWalletIntegrationId; // Mobile Wallet
  static int? iframeId; // IFrame ID للبطاقات (اختياري)

  // Base URLs
  static const String baseUrl = 'https://accept.paymob.com/api';
  static const String authUrl = '$baseUrl/auth/tokens';
  static const String orderUrl = '$baseUrl/ecommerce/orders';
  static const String paymentKeyUrl = '$baseUrl/acceptance/payment_keys';
  static const String fawryUrl = '$baseUrl/acceptance/payments/pay';

  // Test Mode
  static bool isTestMode = true;

  // Initialize from Firestore settings
  static void initialize(Map<String, dynamic>? settings) {
    if (settings == null) return;

    final paymobSettings = settings['paymobSettings'] as Map<String, dynamic>?;
    if (paymobSettings == null) return;

    // Clean API Key (remove whitespace and trim)
    final rawApiKey = paymobSettings['apiKey'] as String?;
    apiKey = rawApiKey?.trim().replaceAll(RegExp(r'\s+'), '');

    // Clean HMAC Key
    final rawHmacKey = paymobSettings['hmacKey'] as String?;
    hmacKey = rawHmacKey?.trim().replaceAll(RegExp(r'\s+'), '');

    final integrations =
        paymobSettings['integrations'] as Map<String, dynamic>?;
    if (integrations != null) {
      cardIntegrationId = integrations['card'] as int?;
      fawryIntegrationId = integrations['fawry'] as int?;
      mobileWalletIntegrationId = integrations['mobileWallet'] as int?;
      iframeId = integrations['iframeId'] as int?;
    }

    isTestMode = paymobSettings['isTestMode'] as bool? ?? true;
  }

  static bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;
}
