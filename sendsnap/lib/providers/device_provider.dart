import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:math';
import 'dart:async';
import '../models/device.dart';
import '../services/nearby_service.dart';
import '../services/permission_service.dart';

class DeviceProvider with ChangeNotifier {
  final NearbyService _nearbyService = NearbyService();
  final PermissionService _permissionService = PermissionService();
  
  String _displayName = 'User';
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  String? _lastError; // Surface errors to UI
  
  final Map<String, NearbyDevice> _foundDevices = {};
  NearbyDevice? _connectedDevice;
  Completer<bool>? _connectionCompleter;
  String? _pendingConnectionId;
  
  String get displayName => _displayName;
  bool get isAdvertising => _isAdvertising;
  bool get getIsDiscovering => _isDiscovering;
  bool get isDiscovering => _isDiscovering;
  List<NearbyDevice> get nearbyDevices => _foundDevices.values.toList();
  NearbyDevice? get connectedDevice => _connectedDevice;
  String? get lastError => _lastError;

  NearbyService get nearbyService => _nearbyService;

  DeviceProvider() {
    _loadDisplayName();
    _setupNearbyCallbacks();
  }

  void _setupNearbyCallbacks() {
    _nearbyService.onDeviceFound = (device) {
      _foundDevices[device.endpointId] = device;
      notifyListeners();
    };

    _nearbyService.onDeviceLost = (id) {
      _foundDevices.remove(id);
      notifyListeners();
    };

    _nearbyService.onConnectionInitiated = (id, deviceName) async {
      // Auto-accept connection from both sender and receiver sides
      // Nearby Connections requires both endpoints to accept
      debugPrint('[DeviceProvider] Auto-accepting connection from $deviceName ($id)');
      await _nearbyService.acceptConnection(id);
    };

    _nearbyService.onConnectionResult = (id, success) {
      debugPrint('[DeviceProvider] Connection result: $id -> $success');
      if (success) {
        // Try to find the device by endpoint id, or create a temporary one
        _connectedDevice = _foundDevices[id] ?? NearbyDevice(
          endpointId: id,
          endpointName: 'Device',
          serviceId: 'com.the356company.sendsnap',
        );
      } else {
        _connectedDevice = null;
      }
      // Complete the pending connection future if waiting
      if (_pendingConnectionId == id && _connectionCompleter != null) {
        _connectionCompleter!.complete(success);
        _connectionCompleter = null;
        _pendingConnectionId = null;
      }
      notifyListeners();
    };

    _nearbyService.onDisconnected = (id) {
      if (_connectedDevice?.endpointId == id) {
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
      // Default to device model
      try {
        if (Platform.isAndroid) {
          final info = await DeviceInfoPlugin().androidInfo;
          _displayName = '${info.brand} ${info.model}';
        } else {
          _displayName = 'Generic Device';
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

  /// Ensure all permissions required for Nearby Connections are granted.
  /// Returns true if ready, false otherwise (sets _lastError with reason).
  Future<bool> _ensureNearbyPermissions() async {
    _lastError = null;
    
    // Check if all Nearby Connections permissions are granted
    if (!await _permissionService.hasNearbyConnectionsPermissions()) {
      debugPrint('[DeviceProvider] Missing Nearby Connections permissions, requesting...');
      bool granted = await _permissionService.requestAllPermissions();
      if (!granted) {
        _lastError = 'Required permissions were denied. Please enable Location, Bluetooth, and Storage in Settings.';
        debugPrint('[DeviceProvider] Permission request denied');
        return false;
      }
      // Double-check after requesting
      if (!await _permissionService.hasNearbyConnectionsPermissions()) {
        _lastError = 'Location permission is required for device discovery. Please enable it in Settings.';
        return false;
      }
    }
    
    // Check if location services are enabled
    if (!await _permissionService.ensureLocationEnabled()) {
      _lastError = 'Location services (GPS) must be enabled for device discovery.';
      debugPrint('[DeviceProvider] Location services disabled');
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
      // Check permissions first BEFORE showing any UI state changes
      if (!await _ensureNearbyPermissions()) {
        notifyListeners(); // notify so UI can show _lastError
        return;
      }

      // Immediate feedback
      _isAdvertising = true;
      _isDiscovering = false;
      _lastError = null;
      notifyListeners();

      // Background work
      try {
        await _nearbyService.stopAll();
        
        bool success = await _nearbyService.startAdvertising(_displayName);
        if (!success) {
          _isAdvertising = false;
          _lastError = 'Failed to start advertising. Please try again.';
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[DeviceProvider] Advertising error: $e');
        _isAdvertising = false;
        _lastError = 'Advertising failed: $e';
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
      // Check permissions first BEFORE showing any UI state changes
      if (!await _ensureNearbyPermissions()) {
        notifyListeners(); // notify so UI can show _lastError
        return;
      }

      // Immediate feedback
      _isDiscovering = true;
      _isAdvertising = false;
      _foundDevices.clear();
      _lastError = null;
      notifyListeners();

      // Background work
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

  /// Requests connection and waits for the result callback.
  /// Returns true only when connection is fully established.
  Future<bool> requestConnectionAndWait(String endpointId) async {
    _connectionCompleter = Completer<bool>();
    _pendingConnectionId = endpointId;

    bool requestSent = await _nearbyService.requestConnection(_displayName, endpointId);
    if (!requestSent) {
      _connectionCompleter = null;
      _pendingConnectionId = null;
      return false;
    }

    // Wait up to 15 seconds for connection result (increased from 10)
    try {
      bool connected = await _connectionCompleter!.future.timeout(const Duration(seconds: 15));
      return connected;
    } on TimeoutException {
      debugPrint('[DeviceProvider] Connection timed out for $endpointId');
      _pendingConnectionId = null;
      _connectionCompleter = null;
      return false;
    }
  }
}
