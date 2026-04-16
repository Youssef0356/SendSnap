import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:flutter_multicast_lock/flutter_multicast_lock.dart';
import '../models/device.dart';

/// Service for discovering nearby devices via mDNS (Network Service Discovery).
class DiscoveryService {
  static const String _serviceType = '_sendsnap._tcp';

  nsd.Registration? _registration;
  nsd.Discovery? _discovery;
  String? _curDeviceName;
  Set<String> _localAddresses = const {};
  Timer? _reannounceTimer;
  final FlutterMulticastLock _multicastLock = FlutterMulticastLock();

  final _devicesController = StreamController<List<NearbyDevice>>.broadcast();
  final Map<String, NearbyDevice> _discoveredDevices = {};

  int _broadcastPort = 0;
  bool _isBroadcasting = false;
  bool _isDiscovering = false;

  Stream<List<NearbyDevice>> get devicesStream => _devicesController.stream;
  List<NearbyDevice> get currentDevices => _discoveredDevices.values.toList();
  bool get isBroadcasting => _isBroadcasting;
  int get broadcastPort => _broadcastPort;

  Future<void> _acquireMulticastLock() async {
    if (Platform.isAndroid) {
      try {
        await _multicastLock.acquireMulticastLock();
        debugPrint('[SendSnap] MulticastLock acquired');
      } catch (e) {
        debugPrint('[SendSnap] Failed to acquire MulticastLock: $e');
      }
    }
  }

  Future<void> _releaseMulticastLock() async {
    if (Platform.isAndroid) {
      try {
        await _multicastLock.releaseMulticastLock();
        debugPrint('[SendSnap] MulticastLock released');
      } catch (e) {
        debugPrint('[SendSnap] Failed to release MulticastLock: $e');
      }
    }
  }

  Future<void> startBroadcast(String deviceName, int port) async {
    if (_isBroadcasting) return;

    try {
      await _acquireMulticastLock();
      await _refreshLocalAddresses();
      _broadcastPort = port;
      _registration = await nsd.register(
        nsd.Service(name: deviceName, type: _serviceType, port: port),
      );
      _curDeviceName = deviceName;
      _isBroadcasting = true;
      debugPrint('[SendSnap] Broadcasting as "$deviceName" on port $port');

      _reannounceTimer?.cancel();
      _reannounceTimer = Timer.periodic(const Duration(seconds: 45), (_) async {
        if (_isBroadcasting) {
          debugPrint('[SendSnap] Re-announcing service...');
          final name = _curDeviceName;
          final p = _broadcastPort;
          await stopBroadcast();
          if (name != null) await startBroadcast(name, p);
        }
      });
    } catch (e) {
      debugPrint('[SendSnap] Failed to start broadcast: $e');
      await _releaseMulticastLock();
      rethrow;
    }
  }

  Future<void> stopBroadcast() async {
    if (!_isBroadcasting || _registration == null) return;

    try {
      _reannounceTimer?.cancel();
      _reannounceTimer = null;
      await nsd.unregister(_registration!);
      _registration = null;
      _curDeviceName = null;
      _isBroadcasting = false;
      debugPrint('[SendSnap] Stopped broadcasting');
      
      if (!_isDiscovering) await _releaseMulticastLock();
    } catch (e) {
      debugPrint('[SendSnap] Failed to stop broadcast: $e');
    }
  }

  Future<void> startDiscovery() async {
    if (_isDiscovering) return;

    try {
      await _acquireMulticastLock();
      await _refreshLocalAddresses();
      _discovery = await nsd.startDiscovery(_serviceType, autoResolve: true);
      _isDiscovering = true;
      debugPrint('[SendSnap] Started discovering nearby devices');

      _discovery!.addServiceListener((service, status) {
        // FIX: filter self by name+port, not just IP.
        // mDNS often resolves hostnames as ".local" strings, not raw IPs,
        // so IP-based matching frequently fails. Name+port is reliable.
        if (_isOwnService(service)) {
          debugPrint('[SendSnap] Ignoring own service: ${service.name}');
          return;
        }

        // Use name+host as a stable composite key. If host is null (unresolved),
        // we skip the device rather than adding it with a bad IP.
        if (service.host == null || service.port == null) return;

        final id = '${service.name}_${service.host}';

        if (status == nsd.ServiceStatus.found) {
          // Prefer raw IP address over hostname if available
          String ip = service.host!;
          if (service.addresses != null && service.addresses!.isNotEmpty) {
            final ipv4 = service.addresses!.firstWhere(
              (a) => a.type == InternetAddressType.IPv4,
              orElse: () => service.addresses!.first,
            );
            ip = ipv4.address;
          }

          final device = NearbyDevice(
            id: id,
            name: service.name ?? 'Unknown Device',
            ip: ip,
            port: service.port!,
          );
          _discoveredDevices[id] = device;
          _emitDevices();
          debugPrint(
            '[SendSnap] Found: ${device.name} at ${device.ip}:${device.port}',
          );
        } else if (status == nsd.ServiceStatus.lost) {
          _discoveredDevices.remove(id);
          _emitDevices();
          debugPrint('[SendSnap] Lost: ${service.name}');
        }
      });
    } catch (e) {
      debugPrint('[SendSnap] Failed to start discovery: $e');
      if (!_isBroadcasting) await _releaseMulticastLock();
      rethrow;
    }
  }

  Future<void> stopDiscovery() async {
    if (!_isDiscovering || _discovery == null) return;

    try {
      await nsd.stopDiscovery(_discovery!);
      _discovery = null;
      _isDiscovering = false;
      _discoveredDevices.clear();
      _emitDevices();
      debugPrint('[SendSnap] Stopped discovery');
      
      if (!_isBroadcasting) await _releaseMulticastLock();
    } catch (e) {
      debugPrint('[SendSnap] Failed to stop discovery: $e');
    }
  }

  void _emitDevices() {
    if (!_devicesController.isClosed) {
      _devicesController.add(_discoveredDevices.values.toList());
    }
  }

  /// FIX: primary check is name match (most reliable).
  /// Falls back to IP+port check for edge cases.
  bool _isOwnService(nsd.Service service) {
    // Name match — this is the most reliable signal
    final normalizedServiceName = service.name?.toLowerCase().trim() ?? '';
    final normalizedOwnName = _curDeviceName?.toLowerCase().trim() ?? '';

    if (normalizedOwnName.isNotEmpty &&
        normalizedServiceName == normalizedOwnName) {
      return true;
    }

    // Secondary: IP + port check (works when mDNS resolves raw IPs)
    final host = service.host;
    if (host != null && service.port == _broadcastPort) {
      if (_localAddresses.contains(host)) return true;
    }

    return false;
  }

  Future<void> _refreshLocalAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      _localAddresses = interfaces
          .expand((iface) => iface.addresses)
          .map((addr) => addr.address)
          .toSet();
      debugPrint('[SendSnap] Local addresses: $_localAddresses');
    } catch (e) {
      debugPrint('[SendSnap] Failed to read local interfaces: $e');
      _localAddresses = const {};
    }
  }

  Future<void> dispose() async {
    await stopBroadcast();
    await stopDiscovery();
    await _releaseMulticastLock();
    if (!_devicesController.isClosed) {
      await _devicesController.close();
    }
  }
}
