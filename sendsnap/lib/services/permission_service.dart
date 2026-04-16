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

      // Permissions required for discovery and networking
      results[Permission.location] = await Permission.location.request();
      
      if (androidVersion >= 33) {
        // Android 13+ uses granular media permissions + Nearby WiFi
        results[Permission.photos] = await Permission.photos.request();
        results[Permission.videos] = await Permission.videos.request();
        results[Permission.audio] = await Permission.audio.request();
        results[Permission.nearbyWifiDevices] =
            await Permission.nearbyWifiDevices.request();
      } else if (androidVersion >= 30) {
        // Android 11-12
        results[Permission.manageExternalStorage] =
            await Permission.manageExternalStorage.request();
      } else {
        // Android 10 and below - needs legacy storage permission
        results[Permission.storage] = await Permission.storage.request();
      }

      // Bluetooth is no longer required for the mDNS + TCP method.
      // We keep these lines commented out in case they're needed for legacy/offline mode.
      /*
      results[Permission.bluetooth] = await Permission.bluetooth.request();
      results[Permission.bluetoothAdvertise] = await Permission.bluetoothAdvertise.request();
      results[Permission.bluetoothConnect] = await Permission.bluetoothConnect.request();
      results[Permission.bluetoothScan] = await Permission.bluetoothScan.request();
      */
    }

    // Diagnostic logging
    for (final entry in results.entries) {
      debugPrint('[SendSnap] Permission ${entry.key}: ${entry.value}');
    }

    // Return true only if the primary storage/media category is granted
    return await hasStoragePermission();
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
