import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../config/app_config.dart';

class StorageService {
  StorageService._();

  static SharedPreferences? _prefs;
  static final Map<String, dynamic> _memoryFallback = <String, dynamic>{};

  static const String keyCustomBaseUrl = 'custom_base_url';
  static const String keySelectedBranchId = 'selected_branch_id';
  static const String keySelectedWarehouseId = 'selected_warehouse_id';

  /// Inisialisasi SharedPreferences dengan penanganan error yang aman
  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final savedBaseUrl = _prefs?.getString(keyCustomBaseUrl);
      if (savedBaseUrl != null && savedBaseUrl.trim().isNotEmpty) {
        ApiConfig.baseUrl = savedBaseUrl.trim();
      }
    } catch (e) {
      debugPrint('[StorageService] Peringatan: $e');
    }
  }

  // --- Base URL Config ---
  static Future<bool> saveBaseUrl(String url) async {
    ApiConfig.baseUrl = url.trim();
    _memoryFallback[keyCustomBaseUrl] = url.trim();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      return (await _prefs?.setString(keyCustomBaseUrl, url.trim())) ?? true;
    } catch (_) {
      return true;
    }
  }

  static String getBaseUrl() {
    return _prefs?.getString(keyCustomBaseUrl) ?? ApiConfig.baseUrl;
  }

  // --- Auth Token Management ---

  /// Simpan Auth Token
  static Future<bool> saveAuthToken(String token) async {
    _memoryFallback[AppConfig.keyAuthToken] = token;
    _memoryFallback[AppConfig.keyIsLoggedIn] = true;

    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setBool(AppConfig.keyIsLoggedIn, true);
      return (await _prefs?.setString(AppConfig.keyAuthToken, token)) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Ambil Auth Token yang tersimpan
  static Future<String?> getAuthToken() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      return _prefs?.getString(AppConfig.keyAuthToken) ?? _memoryFallback[AppConfig.keyAuthToken] as String?;
    } catch (_) {
      return _memoryFallback[AppConfig.keyAuthToken] as String?;
    }
  }

  /// Cek apakah user sudah login & memiliki token
  static Future<bool> hasValidToken() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  /// Simpan data user opsional (nama, email, role, dsb.)
  static Future<bool> saveUserData(String jsonString) async {
    _memoryFallback[AppConfig.keyUserData] = jsonString;

    try {
      _prefs ??= await SharedPreferences.getInstance();
      return (await _prefs?.setString(AppConfig.keyUserData, jsonString)) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Ambil data user
  static Future<String?> getUserData() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      return _prefs?.getString(AppConfig.keyUserData) ?? _memoryFallback[AppConfig.keyUserData] as String?;
    } catch (_) {
      return _memoryFallback[AppConfig.keyUserData] as String?;
    }
  }

  // --- POS Branch & Warehouse Selection Cache ---
  static Future<void> saveSelectedBranch(int branchId) async {
    _memoryFallback[keySelectedBranchId] = branchId;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setInt(keySelectedBranchId, branchId);
    } catch (_) {}
  }

  static int? getSelectedBranch() {
    return _prefs?.getInt(keySelectedBranchId) ?? _memoryFallback[keySelectedBranchId] as int?;
  }

  static Future<void> saveSelectedWarehouse(int warehouseId) async {
    _memoryFallback[keySelectedWarehouseId] = warehouseId;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setInt(keySelectedWarehouseId, warehouseId);
    } catch (_) {}
  }

  static int? getSelectedWarehouse() {
    return _prefs?.getInt(keySelectedWarehouseId) ?? _memoryFallback[keySelectedWarehouseId] as int?;
  }

  /// Hapus token dan sesi login (Logout)
  static Future<void> clearAuth() async {
    _memoryFallback.remove(AppConfig.keyAuthToken);
    _memoryFallback.remove(AppConfig.keyRefreshToken);
    _memoryFallback.remove(AppConfig.keyUserData);
    _memoryFallback[AppConfig.keyIsLoggedIn] = false;

    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.remove(AppConfig.keyAuthToken);
      await _prefs?.remove(AppConfig.keyRefreshToken);
      await _prefs?.remove(AppConfig.keyUserData);
      await _prefs?.setBool(AppConfig.keyIsLoggedIn, false);
    } catch (_) {}
  }
}
