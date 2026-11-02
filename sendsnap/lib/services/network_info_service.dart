import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NetworkInfoService {
  static const _channel = MethodChannel('com.the356company.sendsnap/file_utils');

  /// Acquires Android Wi-Fi multicast lock to ensure incoming UDP broadcast packets are received.
  static Future<void> acquireMulticastLock() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('acquireMulticastLock');
      } catch (e) {
        debugPrint('[NetworkInfo] acquireMulticastLock error: $e');
      }
    }
  }

  /// Releases Android Wi-Fi multicast lock.
  static Future<void> releaseMulticastLock() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('releaseMulticastLock');
      } catch (e) {
        debugPrint('[NetworkInfo] releaseMulticastLock error: $e');
      }
    }
  }

  /// Returns the best local IPv4 address for P2P sharing.
  static Future<String?> getLocalIpAddress() async {
    final ips = await getLocalIpAddresses();
    if (ips.isEmpty) return null;
    return ips.first;
  }

  /// Returns all available local IPv4 addresses, prioritizing Wi-Fi/LAN over mobile data.
  static Future<List<String>> getLocalIpAddresses() async {
    final wifiList = <String>[];
    final otherList = <String>[];

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        final isWifiOrLan = name.startsWith('wlan') ||
            name.startsWith('ap') ||
            name.startsWith('eth') ||
            name.startsWith('en') ||
            name.startsWith('wl') ||
            name.contains('wlan');

        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('127.') || ip.startsWith('169.254.')) {
            continue;
          }

          // Exclude cellular CG-NAT (100.64.0.0/10)
          if (ip.startsWith('100.') && name.contains('rmnet')) {
            continue;
          }

          if (isWifiOrLan || ip.startsWith('192.168.')) {
            wifiList.add(ip);
          } else {
            otherList.add(ip);
          }
        }
      }
    } catch (e) {
      debugPrint('[NetworkInfo] getLocalIpAddresses error: $e');
    }

    // Return Wi-Fi / Hotspot IPs first, then fallbacks
    return [...wifiList, ...otherList];
  }

  /// Calculates potential broadcast and multicast addresses for subnet and global broadcast.
  static Future<List<String>> getBroadcastAddresses() async {
    final addresses = <String>{
      '255.255.255.255',
      '224.0.0.1',
      '224.0.0.167',
    };
    final localIps = await getLocalIpAddresses();

    for (final ip in localIps) {
      final parts = ip.split('.');
      if (parts.length == 4) {
        // Standard /24 subnet broadcast (e.g. 192.168.1.255 or 192.168.43.255 hotspot)
        addresses.add('${parts[0]}.${parts[1]}.${parts[2]}.255');
      }
    }

    return addresses.toList();
  }

  /// Returns the current operating system platform identifier.
  static String getPlatformName() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}
