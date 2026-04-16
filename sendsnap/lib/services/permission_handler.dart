import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionHandler {
  static final List<Permission> requiredPermissions = [
    Permission.bluetooth,
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
    Permission.location,
  ];

  static Future<bool> requestAllPermissions() async {
    try {
      // 1. Initial request for common permissions
      await requiredPermissions.request();

      // 2. Specialized Android 12+ / 13+ permissions
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        final sdk = info.version.sdkInt;

        if (sdk >= 31) {
          // Android 12+ needs Bluetooth Scan/Advertise/Connect explicitly
          // Already in REQUIRED_PERMISSIONS, but for clarity:
          await [
            Permission.bluetoothScan,
            Permission.bluetoothAdvertise,
            Permission.bluetoothConnect,
          ].request();
        }
        
        if (sdk >= 33) {
          // Android 13+ needs Nearby Wifi Devices
          await Permission.nearbyWifiDevices.request();
        }

        if (sdk >= 30) {
          // Android 11+ might need Manage External Storage for some paths
          // though typically not needed for standard Downloads folder
          // await Permission.manageExternalStorage.request();
        } else {
          await Permission.storage.request();
        }
      }

      return await checkPermissions();
    } catch (e) {
      print('Permission request error: $e');
      return false;
    }
  }

  static Future<bool> checkPermissions() async {
    try {
      bool allGranted = true;
      for (final p in requiredPermissions) {
        if (!await p.isGranted) {
          allGranted = false;
          break;
        }
      }
      
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        if (info.version.sdkInt >= 33) {
          if (!await Permission.nearbyWifiDevices.isGranted) allGranted = false;
        }
      }

      return allGranted;
    } catch (e) {
      print('Permission check error: $e');
      return false;
    }
  }
}
