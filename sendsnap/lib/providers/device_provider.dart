import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:math';
import '../models/device.dart';
import '../services/nearby_service.dart';
import '../services/permission_handler.dart';

class DeviceProvider with ChangeNotifier {
  final NearbyService _nearbyService = NearbyService();
  
  String _displayName = 'User';
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  
  final Map<String, NearbyDevice> _foundDevices = {};
  NearbyDevice? _connectedDevice;
  
  String get displayName => _displayName;
  bool get isAdvertising => _isAdvertising;
  bool get isDiscovering => _isDiscovering;
  List<NearbyDevice> get nearbyDevices => _foundDevices.values.toList();
  NearbyDevice? get connectedDevice => _connectedDevice;

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
    
    _nearbyService.onConnectionResult = (id, success) {
      if (success) {
        _connectedDevice = _foundDevices[id];
      } else {
        _connectedDevice = null;
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

  Future<void> toggleAdvertising() async {
    if (_isAdvertising) {
      await _nearbyService.stopAll();
      _isAdvertising = false;
    } else {
      if (!await PermissionHandler.checkPermissions()) {
        if (!await PermissionHandler.requestAllPermissions()) return;
      }
      _isAdvertising = await _nearbyService.startAdvertising(_displayName);
      if (_isAdvertising) _isDiscovering = false;
    }
    notifyListeners();
  }

  Future<void> toggleDiscovery() async {
    if (_isDiscovering) {
      await _nearbyService.stopAll();
      _isDiscovering = false;
    } else {
      if (!await PermissionHandler.checkPermissions()) {
        if (!await PermissionHandler.requestAllPermissions()) return;
      }
      _foundDevices.clear();
      _isDiscovering = await _nearbyService.startDiscovery(_displayName);
      if (_isDiscovering) _isAdvertising = false;
    }
    notifyListeners();
  }

  Future<void> stopAll() async {
    await _nearbyService.stopAll();
    _isAdvertising = false;
    _isDiscovering = false;
    _foundDevices.clear();
    notifyListeners();
  }
}
