import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device.dart';
import '../services/discovery_service.dart';
import '../services/offline_connection_service.dart';
import 'connection_provider.dart';
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

    _wifiSubscription = wifiDiscovery.devicesStream.listen((devices) {
      if (_ref.read(connectionModeProvider) == ConnectionMode.wifi) {
        state = devices;
      }
    });

    _offlineSubscription = offlineDiscovery.devicesStream.listen((devices) {
      if (_ref.read(connectionModeProvider) == ConnectionMode.offline) {
        state = devices;
      }
    });
  }

  @override
  void dispose() {
    _wifiSubscription?.cancel();
    _offlineSubscription?.cancel();
    super.dispose();
  }
}
