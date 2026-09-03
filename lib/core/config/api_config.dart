class ApiConfig {
  ApiConfig._();

  // Base URLs according to environment
  static const String devBaseUrl = 'https://dev-api.ipe-pos.example.com/api/v1';
  static const String stagingBaseUrl = 'https://staging-api.ipe-pos.example.com/api/v1';
  static const String prodBaseUrl = 'https://api.ipe-pos.example.com/api/v1';

  // Active Base URL (change or switch dynamically based on environment)
  static String baseUrl = devBaseUrl;

  // Connection Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // Authentication & User Endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh-token';
  static const String profile = '/user/profile';
  static const String updateProfile = '/user/profile/update';

  // POS Core Endpoints
  static const String dashboard = '/pos/dashboard';
  static const String products = '/pos/products';
  static const String categories = '/pos/categories';
  static const String transactions = '/pos/transactions';
  static const String transactionDetail = '/pos/transactions/'; // append :id
  static const String createOrder = '/pos/orders/create';
  static const String cashDrawer = '/pos/cash-drawer';
  static const String shift = '/pos/shift';
  static const String reports = '/pos/reports';
  static const String notifications = '/notifications';

  // Standard Request Headers
  static Map<String, String> defaultHeaders({String? token}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }
}
