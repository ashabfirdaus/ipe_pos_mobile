import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class DeviceInfoModel {
  final String deviceName;
  final String deviceBrand;
  final String deviceModel;
  final String osName;
  final String osVersion;
  final String deviceId;
  final String appVersion;

  DeviceInfoModel({
    required this.deviceName,
    required this.deviceBrand,
    required this.deviceModel,
    required this.osName,
    required this.osVersion,
    required this.deviceId,
    required this.appVersion,
  });

  Map<String, dynamic> toMap() {
    return {
      'device_name': deviceName,
      'device_brand': deviceBrand,
      'device_model': deviceModel,
      'os_name': osName,
      'os_version': osVersion,
      'device_id': deviceId,
      'app_version': appVersion,
    };
  }

  @override
  String toString() => '$deviceBrand $deviceModel ($osName $osVersion)';
}

class DeviceInfoService {
  DeviceInfoService._();

  static DeviceInfoModel? _cachedInfo;
  static final DeviceInfoPlugin _plugin = DeviceInfoPlugin();

  /// Mengambil informasi perangkat saat ini (dengan memory cache)
  static Future<DeviceInfoModel> getDeviceInfo() async {
    if (_cachedInfo != null) return _cachedInfo!;

    String deviceName = 'Unknown Device';
    String deviceBrand = 'Unknown';
    String deviceModel = 'Unknown';
    String osName = 'Unknown OS';
    String osVersion = '';
    String deviceId = '';
    final appVersion = '${AppConfig.appVersion}+${AppConfig.buildNumber}';

    try {
      if (kIsWeb) {
        final webInfo = await _plugin.webBrowserInfo;
        deviceName = webInfo.browserName.name;
        deviceBrand = webInfo.vendor ?? 'Web';
        deviceModel = webInfo.userAgent ?? 'Browser';
        osName = 'Web';
        osVersion = webInfo.platform ?? '';
        deviceId = 'web_${webInfo.userAgent?.hashCode ?? 0}';
      } else if (Platform.isAndroid) {
        final androidInfo = await _plugin.androidInfo;
        deviceBrand = androidInfo.brand.toUpperCase();
        deviceModel = androidInfo.model;
        deviceName = '$deviceBrand $deviceModel';
        osName = 'Android';
        osVersion = '${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await _plugin.iosInfo;
        deviceBrand = 'Apple';
        deviceModel = iosInfo.utsname.machine;
        deviceName = iosInfo.name;
        osName = iosInfo.systemName;
        osVersion = iosInfo.systemVersion;
        deviceId = iosInfo.identifierForVendor ?? '';
      } else if (Platform.isMacOS) {
        final macInfo = await _plugin.macOsInfo;
        deviceBrand = 'Apple';
        deviceModel = macInfo.model;
        deviceName = macInfo.computerName;
        osName = 'macOS';
        osVersion = '${macInfo.majorVersion}.${macInfo.minorVersion}';
        deviceId = macInfo.systemGUID ?? '';
      } else if (Platform.isWindows) {
        final winInfo = await _plugin.windowsInfo;
        deviceBrand = 'PC';
        deviceModel = winInfo.productName;
        deviceName = winInfo.computerName;
        osName = 'Windows';
        osVersion = '${winInfo.majorVersion}.${winInfo.minorVersion}';
        deviceId = winInfo.deviceId;
      } else if (Platform.isLinux) {
        final linuxInfo = await _plugin.linuxInfo;
        deviceBrand = 'Linux';
        deviceModel = linuxInfo.name;
        deviceName = linuxInfo.prettyName;
        osName = 'Linux';
        osVersion = linuxInfo.version ?? '';
        deviceId = linuxInfo.machineId ?? '';
      }
    } catch (e) {
      debugPrint('[DeviceInfoService] Gagal membaca device info: $e');
    }

    _cachedInfo = DeviceInfoModel(
      deviceName: deviceName,
      deviceBrand: deviceBrand,
      deviceModel: deviceModel,
      osName: osName,
      osVersion: osVersion,
      deviceId: deviceId,
      appVersion: appVersion,
    );

    return _cachedInfo!;
  }
}
