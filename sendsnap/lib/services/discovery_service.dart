import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/device.dart';
import 'network_info_service.dart';
import 'http_transfer_client.dart';
import 'http_transfer_server.dart';

class DiscoveryService {
  static const int discoveryPort = 53317;
  static const String protocolTag = 'sendsnap-v1';
  static const String multicastGroup = '224.0.0.167';

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;
  Timer? _sweepTimer;
  NearbyDevice? _myDevice;
  bool _isSweeping = false;

  final Map<String, NearbyDevice> _discoveredDevices = {};

  // Callbacks
  Function(NearbyDevice)? onDeviceFound;
  Function(String)? onDeviceLost;

  List<NearbyDevice> get devices => _discoveredDevices.values.toList();

  Future<bool> startDiscovery({required NearbyDevice localDevice}) async {
    _myDevice = localDevice;
    _discoveredDevices.clear();

    await NetworkInfoService.acquireMulticastLock();

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
      );
      _socket!.broadcastEnabled = true;

      try {
        _socket!.joinMulticast(InternetAddress(multicastGroup));
      } catch (e) {
        debugPrint('[DiscoveryService] Multicast join note: $e');
      }

      _socket!.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            final datagram = _socket?.receive();
            if (datagram != null) {
              _handleIncomingDatagram(datagram);
            }
          }
        },
        onError: (e) {
          debugPrint('[DiscoveryService] Socket error: $e');
        },
      );

      // Send initial DISCOVER broadcast & multicast
      await _sendBroadcast('DISCOVER');

      // Periodic ANNOUNCE heartbeat via UDP
      _broadcastTimer?.cancel();
      _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _sendBroadcast('ANNOUNCE');
      });

      // Cleanup stale devices (> 15s no heartbeat)
      _cleanupTimer?.cancel();
      _cleanupTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        _cleanupStaleDevices();
      });

      // Active Subnet Sweep (Deterministic HTTP scan - bypasses router UDP filtering)
      _performSubnetSweep();
      _sweepTimer?.cancel();
      _sweepTimer = Timer.periodic(const Duration(seconds: 12), (_) {
        if (_discoveredDevices.isEmpty) {
          _performSubnetSweep();
        }
      });

      debugPrint('[DiscoveryService] Started discovery on port $discoveryPort for ${localDevice.name}');
      return true;
    } catch (e) {
      debugPrint('[DiscoveryService] Failed to start discovery: $e');
      return false;
    }
  }

  void _handleIncomingDatagram(Datagram datagram) {
    try {
      final message = utf8.decode(datagram.data);
      final json = jsonDecode(message) as Map<String, dynamic>;

      if (json['protocol'] != protocolTag) return;

      final type = json['type'] as String?;
      final deviceData = json['device'] as Map<String, dynamic>?;

      if (deviceData == null) return;

      final device = NearbyDevice.fromJson(deviceData);

      // Ignore our own broadcast
      if (_myDevice != null && (device.id == _myDevice!.id || (device.ip == _myDevice!.ip && device.ip != '0.0.0.0'))) {
        return;
      }

      // Update device IP with sender's actual IP from datagram if missing or 0.0.0.0
      final verifiedIp = (device.ip.isEmpty || device.ip == '0.0.0.0')
          ? datagram.address.address
          : device.ip;

      final updatedDevice = device.copyWith(
        ip: verifiedIp,
        lastSeen: DateTime.now(),
      );

      if (type == 'ANNOUNCE' || type == 'DISCOVER') {
        _discoveredDevices[updatedDevice.id] = updatedDevice;
        onDeviceFound?.call(updatedDevice);

        // If someone asked "DISCOVER", respond with our "ANNOUNCE" directly to them
        if (type == 'DISCOVER' && _myDevice != null) {
          _sendDirect(datagram.address, discoveryPort, 'ANNOUNCE');
        }
      } else if (type == 'BYE') {
        _discoveredDevices.remove(device.id);
        onDeviceLost?.call(device.id);
      }
    } catch (e) {
      // Malformed or unrelated packet
    }
  }

  Future<void> _sendBroadcast(String type) async {
    if (_socket == null || _myDevice == null) return;

    try {
      final broadcastIps = await NetworkInfoService.getBroadcastAddresses();
      final packetData = utf8.encode(jsonEncode({
        'protocol': protocolTag,
        'type': type,
        'device': _myDevice!.toJson(),
      }));

      for (final broadcastIp in broadcastIps) {
        try {
          _socket?.send(packetData, InternetAddress(broadcastIp), discoveryPort);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[DiscoveryService] Broadcast error: $e');
    }
  }

  void _sendDirect(InternetAddress address, int port, String type) {
    if (_socket == null || _myDevice == null) return;
    try {
      final packetData = utf8.encode(jsonEncode({
        'protocol': protocolTag,
        'type': type,
        'device': _myDevice!.toJson(),
      }));
      _socket?.send(packetData, address, port);
    } catch (e) {
      debugPrint('[DiscoveryService] Direct send error: $e');
    }
  }

  /// Concurrently sweeps the local /24 subnet over HTTP to discover receiving devices
  /// even when router drops UDP broadcast/multicast packets.
  Future<void> _performSubnetSweep() async {
    if (_isSweeping || _myDevice == null) return;
    _isSweeping = true;

    try {
      final localIp = _myDevice!.ip;
      final parts = localIp.split('.');
      if (parts.length != 4) return;
      final prefix = '${parts[0]}.${parts[1]}.${parts[2]}.';
      final myLastOctet = int.tryParse(parts[3]) ?? -1;

      final client = HttpTransferClient();
      const batchSize = 35;
      final hostIndices = List.generate(254, (i) => i + 1)
          .where((i) => i != myLastOctet)
          .toList();

      for (int i = 0; i < hostIndices.length; i += batchSize) {
        if (_socket == null) break;
        final batch = hostIndices.skip(i).take(batchSize);
        await Future.wait(batch.map((host) async {
          final targetIp = '$prefix$host';
          try {
            final dev = await client.ping(targetIp, HttpTransferServer.defaultPort);
            if (dev != null && dev.id != _myDevice!.id) {
              final verified = dev.copyWith(lastSeen: DateTime.now());
              _discoveredDevices[verified.id] = verified;
              onDeviceFound?.call(verified);
              debugPrint('[DiscoveryService] Discovered via subnet sweep: ${verified.name} at ${verified.ip}');
            }
          } catch (_) {}
        }));
        await Future.delayed(const Duration(milliseconds: 25));
      }
    } catch (e) {
      debugPrint('[DiscoveryService] Subnet sweep error: $e');
    } finally {
      _isSweeping = false;
    }
  }

  void triggerSubnetSweep() {
    _performSubnetSweep();
  }

  void _cleanupStaleDevices() {
    final now = DateTime.now();
    final toRemove = <String>[];

    for (final entry in _discoveredDevices.entries) {
      if (now.difference(entry.value.lastSeen).inSeconds > 15) {
        toRemove.add(entry.key);
      }
    }

    for (final id in toRemove) {
      _discoveredDevices.remove(id);
      onDeviceLost?.call(id);
    }
  }

  /// Manually add a device discovered by direct IP ping or QR code
  void registerManualDevice(NearbyDevice device) {
    _discoveredDevices[device.id] = device;
    onDeviceFound?.call(device);
  }

  Future<void> stopDiscovery() async {
    try {
      if (_socket != null && _myDevice != null) {
        await _sendBroadcast('BYE');
      }
    } catch (_) {}

    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _sweepTimer?.cancel();
    _sweepTimer = null;

    try {
      _socket?.close();
      _socket = null;
    } catch (_) {}

    _discoveredDevices.clear();
    await NetworkInfoService.releaseMulticastLock();
    debugPrint('[DiscoveryService] Stopped discovery');
  }
}
