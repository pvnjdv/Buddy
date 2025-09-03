// lib/services/device_info_service.dart
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

class DeviceInfoService {
  static final DeviceInfoService _instance = DeviceInfoService._internal();
  factory DeviceInfoService() => _instance;
  DeviceInfoService._internal();

  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  final NetworkInfo _networkInfo = NetworkInfo();

  /// Get comprehensive device information for all platforms
  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      Map<String, dynamic> deviceData = {};

      // Get network information
      try {
        final wifiIP = await _networkInfo.getWifiIP();
        deviceData['ip_address'] = wifiIP ?? '127.0.0.1';
      } catch (e) {
        deviceData['ip_address'] = '127.0.0.1';
      }

      // Platform-specific device information
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        deviceData.addAll({
          'platform': 'Android',
          'device_type': 'mobile',
          'hostname': androidInfo.device,
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'manufacturer': androidInfo.manufacturer,
          'android_version': androidInfo.version.release,
          'sdk_version': androidInfo.version.sdkInt,
          'architecture': _getAndroidArchitecture(androidInfo),
          'display': '${androidInfo.display}',
          'fingerprint': androidInfo.fingerprint,
          'hardware': androidInfo.hardware,
          'product': androidInfo.product,
          'supported_abis': androidInfo.supportedAbis,
          'is_physical_device': androidInfo.isPhysicalDevice,
        });
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        deviceData.addAll({
          'platform': 'iOS',
          'device_type': 'mobile',
          'hostname': iosInfo.name,
          'model': iosInfo.model,
          'system_name': iosInfo.systemName,
          'system_version': iosInfo.systemVersion,
          'identifier_for_vendor': iosInfo.identifierForVendor,
          'localized_model': iosInfo.localizedModel,
          'machine': iosInfo.utsname.machine,
          'architecture': iosInfo.utsname.machine,
          'is_physical_device': iosInfo.isPhysicalDevice,
        });
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfoPlugin.windowsInfo;
        deviceData.addAll({
          'platform': 'Windows',
          'device_type': 'desktop',
          'hostname': windowsInfo.computerName,
          'display_version': windowsInfo.displayVersion,
          'edition_id': windowsInfo.editionId,
          'install_date': windowsInfo.installDate.toIso8601String(),
          'product_id': windowsInfo.productId,
          'product_name': windowsInfo.productName,
          'registered_owner': windowsInfo.registeredOwner,
          'release_id': windowsInfo.releaseId,
          'system_memory_in_megabytes': windowsInfo.systemMemoryInMegabytes,
        });
      } else if (Platform.isLinux) {
        final linuxInfo = await _deviceInfoPlugin.linuxInfo;
        deviceData.addAll({
          'platform': 'Linux',
          'device_type': 'desktop',
          'hostname': linuxInfo.name,
          'machine_id': linuxInfo.machineId,
          'build_id': linuxInfo.buildId,
          'id': linuxInfo.id,
          'id_like': linuxInfo.idLike?.join(', '),
          'name': linuxInfo.name,
          'pretty_name': linuxInfo.prettyName,
          'variant': linuxInfo.variant,
          'variant_id': linuxInfo.variantId,
          'version': linuxInfo.version,
          'version_codename': linuxInfo.versionCodename,
          'version_id': linuxInfo.versionId,
        });
      } else if (Platform.isMacOS) {
        final macOsInfo = await _deviceInfoPlugin.macOsInfo;
        deviceData.addAll({
          'platform': 'macOS',
          'device_type': 'desktop',
          'hostname': macOsInfo.computerName,
          'arch': macOsInfo.arch,
          'model': macOsInfo.model,
          'kernel_version': macOsInfo.kernelVersion,
          'os_release': macOsInfo.osRelease,
          'major_version': macOsInfo.majorVersion,
          'minor_version': macOsInfo.minorVersion,
          'patch_version': macOsInfo.patchVersion,
          'system_guid': macOsInfo.systemGUID,
        });
      } else {
        // Web or other platforms
        deviceData.addAll({
          'platform': Platform.operatingSystem,
          'device_type': 'web',
          'hostname': 'web-device',
          'version': Platform.operatingSystemVersion,
        });
      }

      // Add common Flutter/Dart information
      deviceData.addAll({
        'dart_version': Platform.version,
        'operating_system': Platform.operatingSystem,
        'operating_system_version': Platform.operatingSystemVersion,
        'locale': Platform.localeName,
      });

      return deviceData;
    } catch (e) {
      print('Error getting device info: $e');
      return {
        'platform': Platform.operatingSystem,
        'device_type': 'unknown',
        'hostname': 'unknown-device',
        'ip_address': '127.0.0.1',
        'error': e.toString(),
      };
    }
  }

  /// Get device capabilities based on platform
  Map<String, bool> getDeviceCapabilities() {
    if (Platform.isAndroid || Platform.isIOS) {
      return {
        'screen_share': true,
        'remote_control': false, // Limited on mobile
        'file_transfer': true,
        'command_execution': false, // Restricted on mobile
        'input_control': false, // Not available on mobile
        'webcam': true,
        'microphone': true,
        'gps': true,
        'accelerometer': true,
        'push_notifications': true,
      };
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return {
        'screen_share': true,
        'remote_control': true,
        'file_transfer': true,
        'command_execution': true,
        'input_control': true,
        'webcam': true,
        'microphone': true,
        'gps': false,
        'accelerometer': false,
        'push_notifications': true,
      };
    } else {
      // Web platform
      return {
        'screen_share': false,
        'remote_control': false,
        'file_transfer': true,
        'command_execution': false,
        'input_control': false,
        'webcam': true,
        'microphone': true,
        'gps': true,
        'accelerometer': false,
        'push_notifications': true,
      };
    }
  }

  /// Get a simplified device identifier
  String getDeviceIdentifier() {
    final platform = Platform.operatingSystem;
    final hostname = Platform.localHostname;
    return '${platform.toLowerCase()}_$hostname';
  }

  /// Check if device is mobile
  bool isMobile() {
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Check if device is desktop
  bool isDesktop() {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  /// Check if device is web
  bool isWeb() {
    return Platform.environment.containsKey('FLUTTER_WEB');
  }

  /// Get platform display name
  String getPlatformDisplayName() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    return Platform.operatingSystem;
  }

  /// Helper method to determine Android architecture
  String _getAndroidArchitecture(AndroidDeviceInfo androidInfo) {
    final abis = androidInfo.supportedAbis;
    if (abis.contains('arm64-v8a')) return 'arm64';
    if (abis.contains('armeabi-v7a')) return 'arm32';
    if (abis.contains('x86_64')) return 'x64';
    if (abis.contains('x86')) return 'x86';
    return 'unknown';
  }
}
