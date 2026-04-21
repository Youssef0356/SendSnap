import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
/// Manages runtime permissions for SendSnap.
class PermissionService {
  /// Check and request all required permissions.
  /// Returns true if all critical permissions are granted.
  Future<bool> requestAllPermissions() async {
    final results = <Permission, PermissionStatus>{};

    if (Platform.isAndroid) {
      final androidVersion = await _getAndroidVersion();

      // ── Location (REQUIRED for Nearby Connections on all Android versions) ──
      // Nearby Connections uses BLE + WiFi Direct which need location on Android.
      // On Android 12+ fine location is still required by GMS Nearby.
      results[Permission.location] = await Permission.location.request();
      
      // ── Bluetooth (Android 12+) ──
      if (androidVersion >= 31) {
        results[Permission.bluetoothScan] = await Permission.bluetoothScan.request();
        results[Permission.bluetoothConnect] = await Permission.bluetoothConnect.request();
        results[Permission.bluetoothAdvertise] = await Permission.bluetoothAdvertise.request();
      } else {
        results[Permission.bluetooth] = await Permission.bluetooth.request();
      }

      // ── Nearby WiFi Devices (Android 13+) ──
      if (androidVersion >= 33) {
        results[Permission.nearbyWifiDevices] =
            await Permission.nearbyWifiDevices.request();
      }

      // ── Storage / Media ──
      if (androidVersion >= 33) {
        // Android 13+ uses granular media permissions
        results[Permission.photos] = await Permission.photos.request();
        results[Permission.videos] = await Permission.videos.request();
        results[Permission.audio] = await Permission.audio.request();
      } else if (androidVersion >= 30) {
        // Android 11-12
        results[Permission.manageExternalStorage] =
            await Permission.manageExternalStorage.request();
      } else {
        // Android 10 and below - needs legacy storage permission
        results[Permission.storage] = await Permission.storage.request();
      }
    }

    // Diagnostic logging
    for (final entry in results.entries) {
      debugPrint('[SendSnap] Permission ${entry.key}: ${entry.value}');
    }

    // Return true only if core permissions are granted
    bool locationOk = await hasLocationPermission();
    bool storageOk = await hasStoragePermission();
    bool bluetoothOk = true;
    if (Platform.isAndroid) {
      final v = await _getAndroidVersion();
      if (v >= 31) {
        bluetoothOk = await Permission.bluetoothScan.isGranted && 
                      await Permission.bluetoothConnect.isGranted &&
                      await Permission.bluetoothAdvertise.isGranted;
      }
    }
    
    debugPrint('[SendSnap] Permission summary — location: $locationOk, storage: $storageOk, bluetooth: $bluetoothOk');
    return locationOk && storageOk && bluetoothOk;
  }

  /// Check if location permission is granted (required for Nearby Connections).
  Future<bool> hasLocationPermission() async {
    if (Platform.isAndroid) {
      return await Permission.location.isGranted;
    }
    return true;
  }

  /// Ensure location services (GPS) are enabled on the device.
  /// Nearby Connections requires location services to be ON.
  Future<bool> ensureLocationEnabled() async {
    if (Platform.isAndroid) {
      if (!await Permission.location.serviceStatus.isEnabled) {
        debugPrint('[SendSnap] Location services are DISABLED — Nearby Connections will fail');
        return false;
      }
    }
    return true;
  }

  /// Check if we have storage read permission.
  Future<bool> hasStoragePermission() async {
    if (Platform.isAndroid) {
      final androidVersion = await _getAndroidVersion();
      if (androidVersion >= 33) {
        return await Permission.photos.isGranted;
      } else if (androidVersion >= 30) {
        return await Permission.manageExternalStorage.isGranted;
      } else {
        return await Permission.storage.isGranted;
      }
    }
    return true;
  }

  /// Check if nearby WiFi devices permission is granted (Android 13+).
  Future<bool> hasNearbyDevicesPermission() async {
    if (Platform.isAndroid) {
      final androidVersion = await _getAndroidVersion();
      if (androidVersion >= 33) {
        return await Permission.nearbyWifiDevices.isGranted;
      }
    }
    return true; // Not required on older versions
  }

  /// Check if ALL permissions needed for Nearby Connections are granted.
  Future<bool> hasNearbyConnectionsPermissions() async {
    if (!Platform.isAndroid) return true;
    
    final androidVersion = await _getAndroidVersion();
    
    // Location is always required for Nearby Connections
    if (!await Permission.location.isGranted) {
      debugPrint('[SendSnap] Missing location permission');
      return false;
    }
    
    // Bluetooth permissions for Android 12+
    if (androidVersion >= 31) {
      if (!await Permission.bluetoothScan.isGranted ||
          !await Permission.bluetoothConnect.isGranted ||
          !await Permission.bluetoothAdvertise.isGranted) {
        debugPrint('[SendSnap] Missing bluetooth permissions');
        return false;
      }
    }
    
    // Nearby WiFi for Android 13+
    if (androidVersion >= 33) {
      if (!await Permission.nearbyWifiDevices.isGranted) {
        debugPrint('[SendSnap] Missing nearbyWifiDevices permission');
        return false;
      }
    }
    
    return true;
  }

  /// Open app settings so user can manually grant permissions.
  Future<void> openSettings() async {
    await openAppSettings();
  }

  Future<int> _getAndroidVersion() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        return androidInfo.version.sdkInt;
      }
      return 0; // Not Android
    } catch (e) {
      debugPrint('[SendSnap] Error detecting Android version: $e');
      return 29; // Safer fallback for older logic
    }
  }
}
