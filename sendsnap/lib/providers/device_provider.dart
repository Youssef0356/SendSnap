import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:math';
import '../models/device.dart';
import '../services/nearby_service.dart';
import '../services/permission_service.dart';

class DeviceProvider with ChangeNotifier {
  final NearbyService _nearbyService = NearbyService();
  final PermissionService _permissionService = PermissionService();
  
  String _displayName = 'User';
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  
  final Map<String, NearbyDevice> _foundDevices = {};
  NearbyDevice? _connectedDevice;
  
  String get displayName => _displayName;
  bool get isAdvertising => _isAdvertising;
  bool get getIsDiscovering => _isDiscovering;
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
      _isAdvertising = false;
      notifyListeners();
      await _nearbyService.stopAll();
    } else {
      // Immediate feedback
      _isAdvertising = true;
      _isDiscovering = false;
      notifyListeners();

      // Background work
      try {
        await _nearbyService.stopAll();
        if (!await _permissionService.hasStoragePermission()) {
          if (!await _permissionService.requestAllPermissions()) {
            _isAdvertising = false;
            notifyListeners();
            return;
          }
        }
        
        bool success = await _nearbyService.startAdvertising(_displayName);
        if (!success) {
          _isAdvertising = false;
          notifyListeners();
        }
      } catch (e) {
        _isAdvertising = false;
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
      // Immediate feedback
      _isDiscovering = true;
      _isAdvertising = false;
      _foundDevices.clear();
      notifyListeners();

      // Background work
      try {
        await _nearbyService.stopAll();
        if (!await _permissionService.hasStoragePermission()) {
          if (!await _permissionService.requestAllPermissions()) {
            _isDiscovering = false;
            notifyListeners();
            return;
          }
        }
        
        bool success = await _nearbyService.startDiscovery(_displayName);
        if (!success) {
          _isDiscovering = false;
          notifyListeners();
        }
      } catch (e) {
        _isDiscovering = false;
        notifyListeners();
      }
    }
  }

  Future<void> stopAll() async {
    await _nearbyService.stopAll();
    _isAdvertising = false;
    _isDiscovering = false;
    _foundDevices.clear();
    notifyListeners();
  }
}
