class ApiConfig {
  ApiConfig._();

  // Single source of truth for Base API URL
  static const String baseUrl = 'https://app.intipangan.com/api';
  static const String defaultBaseUrl = baseUrl;

  // Connection Timeouts
  static const Duration connectTimeout = Duration(seconds: 20);

  // 1. Authentication Endpoints
  static const String login = '/auth/login';
  static const String profile = '/auth/me';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';

  // 2. Point of Sale (POS) Endpoints
  static const String posInitialData = '/pos/initial-data';
  static const String posBranches = '/pos/branches';
  static const String posWarehouses = '/pos/warehouses';
  static const String posProducts = '/pos/products';
  static const String posScanQr = '/pos/scan-qr';
  static const String posInvoices = '/pos/invoices';
  static String posInvoiceDetail(dynamic id) => '/pos/invoices/$id';
  static String posInvoiceVoid(dynamic id) => '/pos/invoices/$id/void';

  // 3. Item Transactions Endpoints
  static String itemTransactionSummary(dynamic itemId) =>
      '/item/$itemId/transaction-summary';
  static String itemTransactionDetails(dynamic itemId) =>
      '/item/$itemId/transaction-details';
  static String itemTransactionTotal(dynamic itemId) =>
      '/item/$itemId/transaction-total';
  static String itemTransactionRowsSummary(dynamic itemId) =>
      '/item/$itemId/transaction-rows-summary';
  static String itemTransactionTotalRows(dynamic itemId) =>
      '/item/$itemId/transaction-total-rows';

  // 4. Payment Notification Endpoint
  static const String savePaymentNotification = '/save_payment_notification';

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
