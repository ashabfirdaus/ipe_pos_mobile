import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/pos_models.dart';
import 'storage_service.dart';

class ApiService {
  ApiService._();

  static final http.Client _client = http.Client();

  /// Build full URI from endpoint and optional query parameters
  static Uri _buildUri(String endpoint, [Map<String, dynamic>? queryParams]) {
    String base = ApiConfig.baseUrl.trim();
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (!endpoint.startsWith('/')) {
      endpoint = '/$endpoint';
    }

    final fullUrl = '$base$endpoint';
    final parsed = Uri.parse(fullUrl);

    if (queryParams != null && queryParams.isNotEmpty) {
      final filteredParams = <String, String>{};
      queryParams.forEach((key, value) {
        if (value != null && value.toString().trim().isNotEmpty) {
          filteredParams[key] = value.toString().trim();
        }
      });
      return parsed.replace(queryParameters: {
        ...parsed.queryParameters,
        ...filteredParams,
      });
    }

    return parsed;
  }

  /// Get headers with optional authorization token
  static Future<Map<String, String>> _getHeaders({bool requiresAuth = true}) async {
    String? token;
    if (requiresAuth) {
      token = await StorageService.getAuthToken();
    }
    return ApiConfig.defaultHeaders(token: token);
  }

  /// Generic GET request
  static Future<ApiResponse<dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint, queryParams);
      final headers = await _getHeaders(requiresAuth: requiresAuth);

      debugPrint('[ApiService GET] $uri');
      final response = await _client
          .get(uri, headers: headers)
          .timeout(ApiConfig.connectTimeout);

      return _processResponse(response);
    } on SocketException catch (e) {
      debugPrint('[ApiService Error] SocketException: $e');
      return ApiResponse.error(
        message: 'Tidak dapat terhubung ke server (${ApiConfig.baseUrl}). Pastikan IP dan port server benar.',
        statusCode: 503,
      );
    } on TimeoutException {
      return ApiResponse.error(
        message: 'Koneksi ke server timeout (${ApiConfig.connectTimeout.inSeconds} detik). Cek koneksi Wi-Fi Anda.',
        statusCode: 408,
      );
    } catch (e) {
      debugPrint('[ApiService Error] $e');
      return ApiResponse.error(
        message: 'Terjadi kesalahan: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Generic POST request
  static Future<ApiResponse<dynamic>> post(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final encodedBody = body != null ? jsonEncode(body) : null;

      debugPrint('[ApiService POST] $uri | Body: $encodedBody');
      final response = await _client
          .post(uri, headers: headers, body: encodedBody)
          .timeout(ApiConfig.connectTimeout);

      return _processResponse(response);
    } on SocketException catch (e) {
      debugPrint('[ApiService Error] SocketException: $e');
      return ApiResponse.error(
        message: 'Tidak dapat terhubung ke server (${ApiConfig.baseUrl}). Periksa jaringan atau IP server.',
        statusCode: 503,
      );
    } on TimeoutException {
      return ApiResponse.error(
        message: 'Koneksi ke server timeout. Silakan coba kembali.',
        statusCode: 408,
      );
    } catch (e) {
      debugPrint('[ApiService Error] $e');
      return ApiResponse.error(
        message: 'Terjadi kesalahan: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  /// Response processor parser
  static ApiResponse<dynamic> _processResponse(http.Response response) {
    debugPrint('[ApiService Response ${response.statusCode}] ${response.body}');
    dynamic json;
    try {
      json = jsonDecode(response.body);
    } catch (_) {
      json = null;
    }

    final isSuccessStatus = response.statusCode >= 200 && response.statusCode < 300;

    if (json is Map<String, dynamic>) {
      final status = json['status']?.toString() ?? (isSuccessStatus ? 'success' : 'error');
      final message = json['message']?.toString() ??
          (isSuccessStatus ? 'Permintaan berhasil' : 'Permintaan gagal (${response.statusCode})');
      final data = json['data'] ?? json['result'] ?? json;
      final errors = json['errors'] ?? json['error'];

      if (isSuccessStatus && status != 'error' && status != 'failed') {
        return ApiResponse.success(
          data: data,
          message: message,
          status: status,
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          message: message,
          status: status,
          errors: errors,
          statusCode: response.statusCode,
        );
      }
    }

    if (isSuccessStatus) {
      return ApiResponse.success(
        data: json ?? response.body,
        statusCode: response.statusCode,
      );
    }

    return ApiResponse.error(
      message: 'Server mengembalikan status ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }

  // ==========================================
  // 1. AUTHENTICATION
  // ==========================================

  /// Login and store JWT token
  static Future<ApiResponse<UserModel>> login({
    required String username,
    required String password,
  }) async {
    final res = await post(
      ApiConfig.login,
      body: {
        'username': username,
        'password': password,
      },
      requiresAuth: false,
    );

    if (res.isSuccess && res.data != null) {
      final data = res.data;
      String? token;
      UserModel? user;

      if (data is Map<String, dynamic>) {
        token = data['access_token']?.toString() ?? data['token']?.toString();
        if (token != null && token.isNotEmpty) {
          await StorageService.saveAuthToken(token);
        }

        final userJson = data['user'] ?? data;
        if (userJson is Map<String, dynamic>) {
          user = UserModel.fromJson(userJson);
          await StorageService.saveUserData(jsonEncode(user.toJson()));
        }
      }

      return ApiResponse.success(
        data: user ?? UserModel(id: 1, name: username, username: username),
        message: res.message,
        statusCode: res.statusCode,
      );
    }

    return ApiResponse.error(
      message: res.message.isNotEmpty ? res.message : 'Username atau kata sandi salah.',
      errors: res.errors,
      statusCode: res.statusCode,
    );
  }

  /// Get current user profile
  static Future<ApiResponse<UserModel>> getProfile() async {
    final res = await get(ApiConfig.profile);
    if (res.isSuccess && res.data is Map<String, dynamic>) {
      final user = UserModel.fromJson(res.data as Map<String, dynamic>);
      await StorageService.saveUserData(jsonEncode(user.toJson()));
      return ApiResponse.success(data: user, message: res.message);
    }
    return ApiResponse.error(message: res.message, statusCode: res.statusCode);
  }

  /// Refresh JWT token
  static Future<ApiResponse<String>> refreshToken() async {
    final res = await post(ApiConfig.refreshToken);
    if (res.isSuccess && res.data is Map<String, dynamic>) {
      final token = res.data['access_token']?.toString();
      if (token != null && token.isNotEmpty) {
        await StorageService.saveAuthToken(token);
        return ApiResponse.success(data: token);
      }
    }
    return ApiResponse.error(message: res.message, statusCode: res.statusCode);
  }

  /// Logout
  static Future<ApiResponse<bool>> logout() async {
    try {
      await post(ApiConfig.logout);
    } catch (_) {}
    await StorageService.clearAuth();
    return ApiResponse.success(data: true, message: 'Berhasil logout');
  }

  // ==========================================
  // 2. POINT OF SALE (POS)
  // ==========================================

  /// Get initial master data for POS cashier screen
  static Future<ApiResponse<PosInitialDataModel>> getPosInitialData({
    int? branchId,
    int? warehouseId,
  }) async {
    final query = <String, dynamic>{};
    if (branchId != null) query['branch_id'] = branchId;
    if (warehouseId != null) query['warehouse_id'] = warehouseId;

    final res = await get(ApiConfig.posInitialData, queryParams: query);
    if (res.isSuccess && res.data is Map<String, dynamic>) {
      final model = PosInitialDataModel.fromJson(res.data as Map<String, dynamic>);
      return ApiResponse.success(data: model, message: res.message);
    }
    return ApiResponse.error(message: res.message, statusCode: res.statusCode);
  }

  /// Get active branches
  static Future<ApiResponse<List<BranchModel>>> getBranches() async {
    final res = await get(ApiConfig.posBranches);
    if (res.isSuccess) {
      final list = <BranchModel>[];
      final items = res.data is List ? res.data : (res.data is Map ? res.data['branches'] ?? res.data['data'] : []);
      if (items is List) {
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            list.add(BranchModel.fromJson(item));
          }
        }
      }
      return ApiResponse.success(data: list, message: res.message);
    }
    return ApiResponse.error(message: res.message, statusCode: res.statusCode);
  }

  /// Get active warehouses with optional branch filter
  static Future<ApiResponse<List<WarehouseModel>>> getWarehouses({int? branchId}) async {
    final query = <String, dynamic>{};
    if (branchId != null) query['branch_id'] = branchId;

    final res = await get(ApiConfig.posWarehouses, queryParams: query);
    if (res.isSuccess) {
      final list = <WarehouseModel>[];
      final items = res.data is List ? res.data : (res.data is Map ? res.data['warehouses'] ?? res.data['data'] : []);
      if (items is List) {
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            list.add(WarehouseModel.fromJson(item));
          }
        }
      }
      return ApiResponse.success(data: list, message: res.message);
    }
    return ApiResponse.error(message: res.message, statusCode: res.statusCode);
  }

  /// Get products with stock in warehouse
  static Future<ApiResponse<List<ProductModel>>> getProducts({
    int? warehouseId,
    int? branchId,
    String? search,
    int limit = 50,
  }) async {
    final query = <String, dynamic>{
      'limit': limit,
    };
    if (warehouseId != null) query['warehouse_id'] = warehouseId;
    if (branchId != null) query['branch_id'] = branchId;
    if (search != null && search.isNotEmpty) query['search'] = search;

    final res = await get(ApiConfig.posProducts, queryParams: query);
    if (res.isSuccess) {
      final list = <ProductModel>[];
      final items = res.data is List ? res.data : (res.data is Map ? res.data['products'] ?? res.data['data'] : []);
      if (items is List) {
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            list.add(ProductModel.fromJson(item));
          }
        }
      }
      return ApiResponse.success(data: list, message: res.message);
    }
    return ApiResponse.error(message: res.message, statusCode: res.statusCode);
  }

  /// Scan QR Code / Barcode to retrieve product & stock
  static Future<ApiResponse<ProductModel>> scanQr({
    required String qrcode,
    int? warehouseId,
    int? branchId,
  }) async {
    final body = <String, dynamic>{
      'qrcode': qrcode,
    };
    if (warehouseId != null) body['warehouse_id'] = warehouseId;
    if (branchId != null) body['branch_id'] = branchId;

    final res = await post(ApiConfig.posScanQr, body: body);
    if (res.isSuccess && res.data is Map<String, dynamic>) {
      final product = ProductModel.fromJson(res.data as Map<String, dynamic>);
      return ApiResponse.success(data: product, message: res.message);
    }
    return ApiResponse.error(message: res.message, statusCode: res.statusCode);
  }

  /// Save POS Cashier Invoice / Transaction
  static Future<ApiResponse<InvoiceModel>> saveInvoice(Map<String, dynamic> payload) async {
    final res = await post(ApiConfig.posInvoices, body: payload);
    if (res.isSuccess && res.data is Map<String, dynamic>) {
      final invoice = InvoiceModel.fromJson(res.data as Map<String, dynamic>);
      return ApiResponse.success(data: invoice, message: res.message);
    }
    return ApiResponse.error(message: res.message, errors: res.errors, statusCode: res.statusCode);
  }

  /// Get Invoices History with filters and pagination
  static Future<ApiResponse<List<InvoiceModel>>> getInvoices({
    int page = 1,
    int perPage = 15,
    int? branchId,
    int? warehouseId,
    int? status,
    String? search,
    String? date,
    String? startDate,
    String? endDate,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (branchId != null) query['branch_id'] = branchId;
    if (warehouseId != null) query['warehouse_id'] = warehouseId;
    if (status != null) query['status'] = status;
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (date != null && date.isNotEmpty) query['date'] = date;
    if (startDate != null && startDate.isNotEmpty) query['start_date'] = startDate;
    if (endDate != null && endDate.isNotEmpty) query['end_date'] = endDate;

    final res = await get(ApiConfig.posInvoices, queryParams: query);
    if (res.isSuccess) {
      final list = <InvoiceModel>[];
      final items = res.data is List ? res.data : (res.data is Map ? res.data['invoices'] ?? res.data['data'] : []);
      if (items is List) {
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            list.add(InvoiceModel.fromJson(item));
          }
        }
      }
      return ApiResponse.success(data: list, message: res.message);
    }
    return ApiResponse.error(message: res.message, statusCode: res.statusCode);
  }

  /// Get Invoice Detail by ID
  static Future<ApiResponse<InvoiceModel>> getInvoiceDetail(dynamic invoiceId) async {
    final res = await get(ApiConfig.posInvoiceDetail(invoiceId));
    if (res.isSuccess && res.data is Map<String, dynamic>) {
      final invoice = InvoiceModel.fromJson(res.data as Map<String, dynamic>);
      return ApiResponse.success(data: invoice, message: res.message);
    }
    return ApiResponse.error(message: res.message, statusCode: res.statusCode);
  }

  /// Void / Cancel POS Invoice
  static Future<ApiResponse<bool>> voidInvoice(dynamic invoiceId, String voidDesc) async {
    final res = await post(
      ApiConfig.posInvoiceVoid(invoiceId),
      body: {'void_desc': voidDesc},
    );
    if (res.isSuccess) {
      return ApiResponse.success(data: true, message: res.message);
    }
    return ApiResponse.error(message: res.message, statusCode: res.statusCode);
  }

  // ==========================================
  // 3. ITEM TRANSACTIONS
  // ==========================================

  /// Get Item Transaction Summary
  static Future<ApiResponse<ItemTransactionSummaryModel>> getItemTransactionSummary(dynamic itemId) async {
    final res = await get(ApiConfig.itemTransactionSummary(itemId));
    if (res.isSuccess && res.data is Map<String, dynamic>) {
      final summary = ItemTransactionSummaryModel.fromJson(res.data as Map<String, dynamic>);
      return ApiResponse.success(data: summary, message: res.message);
    }
    return ApiResponse.error(message: res.message, statusCode: res.statusCode);
  }

  /// Get Item Transaction Details List
  static Future<ApiResponse<List<ItemTransactionDetailModel>>> getItemTransactionDetails(dynamic itemId) async {
    final res = await get(ApiConfig.itemTransactionDetails(itemId));
    if (res.isSuccess) {
      final list = <ItemTransactionDetailModel>[];
      final items = res.data is List ? res.data : (res.data is Map ? res.data['details'] ?? res.data['data'] : []);
      if (items is List) {
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            list.add(ItemTransactionDetailModel.fromJson(item));
          }
        }
      }
      return ApiResponse.success(data: list, message: res.message);
    }
    return ApiResponse.error(message: res.message, statusCode: res.statusCode);
  }

  /// Get Item Total Transactions
  static Future<ApiResponse<dynamic>> getItemTransactionTotal(dynamic itemId) async {
    return await get(ApiConfig.itemTransactionTotal(itemId));
  }

  /// Get Item Transaction Rows Summary
  static Future<ApiResponse<dynamic>> getItemTransactionRowsSummary(dynamic itemId) async {
    return await get(ApiConfig.itemTransactionRowsSummary(itemId));
  }

  /// Get Item Total Transaction Rows
  static Future<ApiResponse<dynamic>> getItemTransactionTotalRows(dynamic itemId) async {
    return await get(ApiConfig.itemTransactionTotalRows(itemId));
  }

  // ==========================================
  // 4. PAYMENT NOTIFICATION
  // ==========================================

  /// Save Payment Notification Report
  static Future<ApiResponse<dynamic>> savePaymentNotification({
    required String paymentMethod,
    required double nominal,
    required String description,
  }) async {
    final body = {
      'payment_method': paymentMethod,
      'nominal': nominal,
      'description': description,
    };
    return await post(ApiConfig.savePaymentNotification, body: body);
  }
}
