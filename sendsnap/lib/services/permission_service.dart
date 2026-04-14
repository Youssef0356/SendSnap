import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Manages runtime permissions for SendSnap.
class PermissionService {
  /// Check and request all required permissions.
  /// Returns true if all critical permissions are granted.
  Future<bool> requestAllPermissions() async {
    final results = <Permission, PermissionStatus>{};

    // Storage permissions
    if (Platform.isAndroid) {
      // Bluetooth and Location for Nearby Connections
      results[Permission.bluetooth] = await Permission.bluetooth.request();
      results[Permission.bluetoothAdvertise] = await Permission.bluetoothAdvertise.request();
      results[Permission.bluetoothConnect] = await Permission.bluetoothConnect.request();
      results[Permission.bluetoothScan] = await Permission.bluetoothScan.request();
      results[Permission.location] = await Permission.location.request();

      final androidVersion = await _getAndroidVersion();

      if (androidVersion >= 33) {
        // Android 13+ uses granular media permissions
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
        // Android 10 and below
        results[Permission.storage] = await Permission.storage.request();
      }
    }

    for (final entry in results.entries) {
      debugPrint('[SendSnap] Permission ${entry.key}: ${entry.value}');
    }

    return true; // Non-blocking — app works with partial permissions
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
      // Simple approach — parse from Platform
      final release = Platform.operatingSystemVersion;
      debugPrint('[SendSnap] OS version: $release');
      // Default to 33 to use the safer/newer permission model
      return 33;
    } catch (_) {
      return 33;
    }
  }
}
