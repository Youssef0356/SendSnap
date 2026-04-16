import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device.dart';
import '../services/discovery_service.dart';
import '../services/transfer_service.dart';
import 'settings_provider.dart';
import 'dart:io';

// ─── Local Network Services (mDNS + TCP) ───
final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  final service = DiscoveryService();
  ref.onDispose(() => service.dispose());
  return service;
});

final transferServiceProvider = Provider<TransferService>((ref) {
  final service = TransferService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ─── My Device Name ───
final deviceNameProvider =
    StateNotifierProvider<DeviceNameNotifier, String>((ref) {
  return DeviceNameNotifier();
});

class DeviceNameNotifier extends StateNotifier<String> {
  final Completer<void> _loadCompleter = Completer<void>();

  DeviceNameNotifier() : super('My Device') {
    _loadName();
  }

  Future<void> _loadName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? uniqueId = prefs.getString('device_unique_id');
      if (uniqueId == null || uniqueId.length != 4) {
        const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
        uniqueId = List.generate(4, (i) => chars[Random().nextInt(chars.length)]).join();
        await prefs.setString('device_unique_id', uniqueId);
      }
      final savedName = prefs.getString('device_name');
      if (savedName != null && savedName.isNotEmpty) { state = savedName; return; }
      String baseName = 'My Device';
      try {
        if (Platform.isAndroid) { final info = await DeviceInfoPlugin().androidInfo; baseName = '${info.brand} ${info.model}'; }
      } catch (_) {}
      state = '$baseName ($uniqueId)';
    } finally { if (!_loadCompleter.isCompleted) _loadCompleter.complete(); }
  }

  Future<void> ensureLoaded() => _loadCompleter.future;
  Future<void> updateName(String newName) async {
    if (newName.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('device_unique_id') ?? '????';
    String n = newName.trim();
    if (!n.endsWith('($uid)')) n = '$n ($uid)';
    state = n; await prefs.setString('device_name', state);
  }
}

// ─── Broadcast Status ───
final broadcastStatusProvider = StateProvider<bool>((ref) => false);

// ─── Nearby Devices (from BLE scan) ───
final nearbyDevicesProvider =
    StateNotifierProvider<NearbyDevicesNotifier, List<NearbyDevice>>((ref) {
  return NearbyDevicesNotifier(ref);
});

class NearbyDevicesNotifier extends StateNotifier<List<NearbyDevice>> {
  final Ref _ref;
  StreamSubscription? _scanSub;

  NearbyDevicesNotifier(this._ref) : super([]) { _startListening(); }

  void _startListening() {
    final svc = _ref.read(discoveryServiceProvider);
    _ref.listen<bool>(simulatorModeProvider, (_, __) => _update());
    _scanSub = svc.devicesStream.listen((_) => _update());
  }

  void _update() {
    final svc = _ref.read(discoveryServiceProvider);
    final isSim = _ref.read(simulatorModeProvider);
    final devices = List<NearbyDevice>.from(svc.currentDevices);
    if (isSim) {
      devices.addAll([
        NearbyDevice(id: 'mock_1', name: 'Simulator Pro (Mock)', ip: '127.0.0.1', port: 8080),
        NearbyDevice(id: 'mock_2', name: 'Virtual Pixel 8 (Mock)', ip: '127.0.0.1', port: 8081),
      ]);
    }
    state = devices;
  }

  @override
  void dispose() { _scanSub?.cancel(); super.dispose(); }
}
