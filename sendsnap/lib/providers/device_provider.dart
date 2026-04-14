import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device.dart';
import '../services/discovery_service.dart';
import '../services/offline_connection_service.dart';
import 'connection_provider.dart';
import 'settings_provider.dart';
import 'dart:io';

// ─── Discovery Service Singleton ───
final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  final service = DiscoveryService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ─── Offline Service Singleton ───
final offlineConnectionServiceProvider = Provider<OfflineConnectionService>((ref) {
  final service = OfflineConnectionService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ─── My Device Name ───
final deviceNameProvider =
    StateNotifierProvider<DeviceNameNotifier, String>((ref) {
  return DeviceNameNotifier();
});

class DeviceNameNotifier extends StateNotifier<String> {
  DeviceNameNotifier() : super('My Device') {
    _loadName();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('device_name');
    if (savedName != null && savedName.isNotEmpty) {
      state = savedName;
      return;
    }

    // Default to system device name
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        state = '${info.brand} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        state = info.name;
      }
    } catch (_) {
      state = 'My Device';
    }
  }

  Future<void> updateName(String newName) async {
    if (newName.trim().isEmpty) return;
    state = newName.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_name', state);
  }
}

// ─── Broadcast Status ───
final broadcastStatusProvider = StateProvider<bool>((ref) => false);

// ─── Nearby Devices ───
final nearbyDevicesProvider =
    StateNotifierProvider<NearbyDevicesNotifier, List<NearbyDevice>>((ref) {
  return NearbyDevicesNotifier(ref);
});

class NearbyDevicesNotifier extends StateNotifier<List<NearbyDevice>> {
  final Ref _ref;
  StreamSubscription? _wifiSubscription;
  StreamSubscription? _offlineSubscription;

  NearbyDevicesNotifier(this._ref) : super([]) {
    _startListening();
  }

  void _startListening() {
    final wifiDiscovery = _ref.read(discoveryServiceProvider);
    final offlineDiscovery = _ref.read(offlineConnectionServiceProvider);

    // Watch simulator mode to force an update when toggled
    _ref.listen<bool>(simulatorModeProvider, (prev, next) {
      _updateState();
    });

    _wifiSubscription = wifiDiscovery.devicesStream.listen((devices) {
      _updateState(wifiDevices: devices);
    });

    _offlineSubscription = offlineDiscovery.devicesStream.listen((devices) {
      _updateState(offlineDevices: devices);
    });
  }

  void _updateState({List<NearbyDevice>? wifiDevices, List<NearbyDevice>? offlineDevices}) {
    final mode = _ref.read(connectionModeProvider);
    final isSimulator = _ref.read(simulatorModeProvider);
    final myName = _ref.read(deviceNameProvider).toLowerCase().trim();

    List<NearbyDevice> currentDevices = [];

    if (mode == ConnectionMode.wifi) {
      currentDevices = wifiDevices ?? _ref.read(discoveryServiceProvider).currentDevices;
    } else {
      currentDevices = offlineDevices ?? _ref.read(offlineConnectionServiceProvider).currentDevices;
    }

    // Filter out self
    List<NearbyDevice> filtered = currentDevices
        .where((d) => d.name.toLowerCase().trim() != myName)
        .toList();

    // Inject mock devices if simulator mode is ON
    if (isSimulator) {
      filtered.addAll([
        NearbyDevice(
          id: 'mock_1',
          name: 'Simulator Pro (Mock)',
          ip: '127.0.0.1',
          port: 8080,
          status: DeviceStatus.ready,
        ),
        NearbyDevice(
          id: 'mock_2',
          name: 'Virtual Pixel 8 (Mock)',
          ip: '127.0.0.1',
          port: 8081,
          status: DeviceStatus.ready,
        ),
      ]);
    }

    state = filtered;
  }

  @override
  void dispose() {
    _wifiSubscription?.cancel();
    _offlineSubscription?.cancel();
    super.dispose();
  }
}
