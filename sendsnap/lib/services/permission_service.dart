import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Manages runtime permissions for SendSnap.
class PermissionService {
  /// Request essential permissions (Storage / Media).
  /// Network discovery operates over local Wi-Fi without requiring location or Bluetooth.
  Future<bool> requestAllPermissions() async {
    final results = <Permission, PermissionStatus>{};

    if (Platform.isAndroid) {
      final androidVersion = await _getAndroidVersion();

      // Storage / Media permissions for picking files to share
      if (androidVersion >= 33) {
        results[Permission.photos] = await Permission.photos.request();
        results[Permission.videos] = await Permission.videos.request();
        results[Permission.audio] = await Permission.audio.request();
      } else if (androidVersion >= 30) {
        results[Permission.storage] = await Permission.storage.request();
      } else {
        results[Permission.storage] = await Permission.storage.request();
      }
    }

    for (final entry in results.entries) {
      debugPrint('[SendSnap] Permission ${entry.key}: ${entry.value}');
    }

    return true;
  }

  /// Check if we have storage read permission.
  Future<bool> hasStoragePermission() async {
    if (Platform.isAndroid) {
      final androidVersion = await _getAndroidVersion();
      if (androidVersion >= 30) {
        if (await Permission.manageExternalStorage.isGranted) return true;
      }
      if (androidVersion >= 33) {
        final photos = await Permission.photos.isGranted;
        final videos = await Permission.videos.isGranted;
        return photos || videos;
      } else {
        return await Permission.storage.isGranted;
      }
    }
    return true;
  }

  /// Check whether MANAGE_EXTERNAL_STORAGE (All Files Access) is granted on Android 11+.
  Future<bool> hasManageExternalStoragePermission() async {
    if (Platform.isAndroid) {
      final androidVersion = await _getAndroidVersion();
      if (androidVersion >= 30) {
        return await Permission.manageExternalStorage.isGranted;
      }
      return await Permission.storage.isGranted;
    }
    return true;
  }

  /// Request all files access (MANAGE_EXTERNAL_STORAGE) if needed for browsing internal storage
  Future<bool> requestStorageManagementIfNeeded() async {
    if (Platform.isAndroid) {
      final androidVersion = await _getAndroidVersion();
      if (androidVersion >= 30) {
        if (!await Permission.manageExternalStorage.isGranted) {
          final status = await Permission.manageExternalStorage.request();
          return status.isGranted;
        }
        return true;
      }
    }
    return true;
  }

  /// Check if network transfer permissions are ready.
  Future<bool> hasNearbyConnectionsPermissions() async {
    // Wi-Fi HTTP + UDP discovery does not require GPS or Bluetooth
    return true;
  }

  /// Location check (not strictly required for local Wi-Fi, returns true).
  Future<bool> ensureLocationEnabled() async {
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
      return 0;
    } catch (e) {
      debugPrint('[SendSnap] Error detecting Android version: $e');
      return 29;
    }
  }
}
