import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;
import '../models/device.dart';

/// Service for discovering nearby devices via mDNS (Network Service Discovery).
/// Broadcasts this device on the local WiFi and discovers others running SendSnap.
class DiscoveryService {
  static const String _serviceType = '_sendsnap._tcp';

  nsd.Registration? _registration;
  nsd.Discovery? _discovery;
  String? _curDeviceName;

  final _devicesController = StreamController<List<NearbyDevice>>.broadcast();
  final Map<String, NearbyDevice> _discoveredDevices = {};

  int _broadcastPort = 0;
  bool _isBroadcasting = false;
  bool _isDiscovering = false;

  Stream<List<NearbyDevice>> get devicesStream => _devicesController.stream;
  List<NearbyDevice> get currentDevices => _discoveredDevices.values.toList();
  bool get isBroadcasting => _isBroadcasting;
  int get broadcastPort => _broadcastPort;

  /// Start broadcasting this device's name on the local network.
  Future<void> startBroadcast(String deviceName, int port) async {
    if (_isBroadcasting) return;

    try {
      _broadcastPort = port;
      _registration = await nsd.register(
        nsd.Service(
          name: deviceName,
          type: _serviceType,
          port: port,
        ),
      );
      _curDeviceName = deviceName;
      _isBroadcasting = true;
      debugPrint('[SendSnap] Broadcasting as "$deviceName" on port $port');
    } catch (e) {
      debugPrint('[SendSnap] Failed to start broadcast: $e');
      rethrow;
    }
  }

  /// Stop broadcasting this device.
  Future<void> stopBroadcast() async {
    if (!_isBroadcasting || _registration == null) return;

    try {
      await nsd.unregister(_registration!);
      _registration = null;
      _curDeviceName = null;
      _isBroadcasting = false;
      debugPrint('[SendSnap] Stopped broadcasting');
    } catch (e) {
      debugPrint('[SendSnap] Failed to stop broadcast: $e');
    }
  }

  /// Start discovering nearby devices running SendSnap.
  Future<void> startDiscovery() async {
    if (_isDiscovering) return;

    try {
      _discovery = await nsd.startDiscovery(_serviceType, autoResolve: true);
      _isDiscovering = true;
      debugPrint('[SendSnap] Started discovering nearby devices');

      _discovery!.addServiceListener((service, status) {
        // Filter out our own device
        if (service.name == _curDeviceName) return;

        final id = '${service.name}_${service.host}';

        if (status == nsd.ServiceStatus.found) {
          if (service.host != null && service.port != null) {
            final device = NearbyDevice(
              id: id,
              name: service.name ?? 'Unknown Device',
              ip: service.host!,
              port: service.port!,
            );
            _discoveredDevices[id] = device;
            _emitDevices();
            debugPrint('[SendSnap] Found: ${device.name} at ${device.ip}:${device.port}');
          }
        } else if (status == nsd.ServiceStatus.lost) {
          _discoveredDevices.remove(id);
          _emitDevices();
          debugPrint('[SendSnap] Lost: ${service.name}');
        }
      });
    } catch (e) {
      debugPrint('[SendSnap] Failed to start discovery: $e');
      rethrow;
    }
  }

  /// Stop discovering nearby devices.
  Future<void> stopDiscovery() async {
    if (!_isDiscovering || _discovery == null) return;

    try {
      await nsd.stopDiscovery(_discovery!);
      _discovery = null;
      _isDiscovering = false;
      _discoveredDevices.clear();
      _emitDevices();
      debugPrint('[SendSnap] Stopped discovery');
    } catch (e) {
      debugPrint('[SendSnap] Failed to stop discovery: $e');
    }
  }

  void _emitDevices() {
    _devicesController.add(_discoveredDevices.values.toList());
  }

  /// Clean up resources.
  Future<void> dispose() async {
    await stopBroadcast();
    await stopDiscovery();
    await _devicesController.close();
  }
}
