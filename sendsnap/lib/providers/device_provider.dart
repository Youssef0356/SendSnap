import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:math';
import 'dart:async';
import '../models/device.dart';
import '../services/nearby_service.dart';
import '../services/permission_service.dart';
import '../services/network_info_service.dart';

class DeviceProvider with ChangeNotifier {
  final NearbyService _nearbyService = NearbyService();
  final PermissionService _permissionService = PermissionService();
  
  String _displayName = 'User';
  String? _localIp;
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  String? _lastError;
  
  final Map<String, NearbyDevice> _foundDevices = {};
  NearbyDevice? _connectedDevice;
  
  String get displayName => _displayName;
  String? get localIp => _localIp;
  bool get isAdvertising => _isAdvertising;
  bool get getIsDiscovering => _isDiscovering;
  bool get isDiscovering => _isDiscovering;
  List<NearbyDevice> get nearbyDevices => _foundDevices.values.toList();
  NearbyDevice? get connectedDevice => _connectedDevice;
  String? get lastError => _lastError;

  NearbyService get nearbyService => _nearbyService;

  DeviceProvider() {
    _loadDisplayName();
    _refreshLocalIp();
    _setupNearbyCallbacks();
  }

  Future<void> _refreshLocalIp() async {
    _localIp = await NetworkInfoService.getLocalIpAddress();
    notifyListeners();
  }

  void _setupNearbyCallbacks() {
    _nearbyService.onDeviceFound = (device) {
      _foundDevices[device.id] = device;
      notifyListeners();
    };

    _nearbyService.onDeviceLost = (id) {
      _foundDevices.remove(id);
      notifyListeners();
    };

    _nearbyService.onConnectionInitiated = (id, deviceName) async {
      debugPrint('[DeviceProvider] Handshake initiated with $deviceName ($id)');
    };

    _nearbyService.onConnectionResult = (id, success) {
      debugPrint('[DeviceProvider] Connection result: $id -> $success');
      if (success) {
        _connectedDevice = _foundDevices[id] ?? NearbyDevice(
          id: id,
          name: 'Device',
          ip: '',
          port: 53318,
        );
      } else {
        _connectedDevice = null;
      }
      notifyListeners();
    };

    _nearbyService.onDisconnected = (id) {
      if (_connectedDevice?.id == id) {
        _connectedDevice = null;
      }
      notifyListeners();
    };
  }

  Future<void> _loadDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    String? saved = prefs.getString('display_name');
    if (saved != null && saved.isNotEmpty) {
      _displayName = saved;
    } else {
      try {
        if (Platform.isAndroid) {
          final info = await DeviceInfoPlugin().androidInfo;
          _displayName = '${info.brand} ${info.model}';
        } else if (Platform.isIOS) {
          final info = await DeviceInfoPlugin().iosInfo;
          _displayName = info.name;
        } else if (Platform.isWindows) {
          final info = await DeviceInfoPlugin().windowsInfo;
          _displayName = info.computerName;
        } else {
          _displayName = 'Device ${Random().nextInt(999)}';
        }
      } catch (_) {
        _displayName = 'User ${Random().nextInt(999)}';
      }
      await prefs.setString('display_name', _displayName);
    }
    notifyListeners();
  }

  Future<void> updateDisplayName(String name) async {
    _displayName = name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('display_name', _displayName);
    notifyListeners();
  }

  Future<bool> _ensureNetworkReady() async {
    _lastError = null;
    await _refreshLocalIp();

    if (_localIp == null || _localIp!.isEmpty) {
      _lastError = 'No Wi-Fi or hotspot connection found. Please connect both devices to the same Wi-Fi network or enable a Personal Hotspot.';
      debugPrint('[DeviceProvider] No local IP found');
      return false;
    }
    return true;
  }

  Future<void> toggleAdvertising() async {
    if (_isAdvertising) {
      _isAdvertising = false;
      notifyListeners();
      await _nearbyService.stopAll();
    } else {
      if (!await _ensureNetworkReady()) {
        notifyListeners();
        return;
      }

      _isAdvertising = true;
      _isDiscovering = false;
      _lastError = null;
      notifyListeners();

      try {
        await _nearbyService.stopAll();
        bool success = await _nearbyService.startAdvertising(_displayName);
        if (!success) {
          _isAdvertising = false;
          _lastError = 'Failed to start receiver service. Please check network permissions.';
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[DeviceProvider] Advertising error: $e');
        _isAdvertising = false;
        _lastError = 'Receiver failed: $e';
        notifyListeners();
      }
    }
  }

  Future<void> toggleDiscovery() async {
    if (_isDiscovering) {
      _isDiscovering = false;
      notifyListeners();
      await _nearbyService.stopAll();
    } else {
      if (!await _ensureNetworkReady()) {
        notifyListeners();
        return;
      }

      // Check storage permission for sending files
      await _permissionService.requestAllPermissions();

      _isDiscovering = true;
      _isAdvertising = false;
      _foundDevices.clear();
      _lastError = null;
      notifyListeners();

      try {
        await _nearbyService.stopAll();
        bool success = await _nearbyService.startDiscovery(_displayName);
        if (!success) {
          _isDiscovering = false;
          _lastError = 'Failed to start discovery. Please try again.';
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[DeviceProvider] Discovery error: $e');
        _isDiscovering = false;
        _lastError = 'Discovery failed: $e';
        notifyListeners();
      }
    }
  }

  /// Manually connect to a device by IP address (useful if UDP broadcast is isolated by a router)
  Future<bool> connectByIp(String ip, {int port = 53318}) async {
    final dev = await connectAndGetDevice(ip, port: port);
    return dev != null;
  }

  /// Pings a remote device by IP and adds it to discovered devices
  Future<NearbyDevice?> connectAndGetDevice(String ip, {int port = 53318}) async {
    final remoteDevice = await _nearbyService.httpClient.ping(ip, port);
    if (remoteDevice != null) {
      _foundDevices[remoteDevice.id] = remoteDevice;
      _nearbyService.addManualDevice(remoteDevice);
      notifyListeners();
      return remoteDevice;
    }
    return null;
  }

  Future<void> stopAll() async {
    await _nearbyService.stopAll();
    _isAdvertising = false;
    _isDiscovering = false;
    _foundDevices.clear();
    _lastError = null;
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  Future<bool> requestConnectionAndWait(String endpointId) async {
    try {
      final success = await _nearbyService.requestConnection(_displayName, endpointId);
      return success;
    } catch (e) {
      debugPrint('[DeviceProvider] requestConnectionAndWait error: $e');
      return false;
    }
  }
}
