import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class StorageService {
  StorageService._();

  static SharedPreferences? _prefs;
  static final Map<String, dynamic> _memoryFallback = <String, dynamic>{};

  /// Inisialisasi SharedPreferences dengan penanganan error yang aman (fallback ke memory jika channel belum siap)
  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('[StorageService] Peringatan: SharedPreferences native channel belum terhubung ($e). Menggunakan memory storage sementara.');
    }
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
