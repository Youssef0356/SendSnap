import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Save Path ───
final savePathProvider =
    StateNotifierProvider<SavePathNotifier, String>((ref) {
  return SavePathNotifier();
});

class SavePathNotifier extends StateNotifier<String> {
  SavePathNotifier() : super('Downloads/SendSnap') {
    _loadPath();
  }

  Future<void> _loadPath() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('save_path');
    if (savedPath != null && savedPath.isNotEmpty) {
      state = savedPath;
    }
  }

  Future<void> updatePath(String newPath) async {
    if (newPath.trim().isEmpty) return;
    state = newPath.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('save_path', state);
  }
}

// ─── Simulator Mode ───
final simulatorModeProvider =
    StateNotifierProvider<SimulatorModeNotifier, bool>((ref) {
  return SimulatorModeNotifier();
});

class SimulatorModeNotifier extends StateNotifier<bool> {
  SimulatorModeNotifier() : super(false) {
    if (!kReleaseMode) {
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('simulator_mode') ?? false;
  }

  Future<void> toggle(bool value) async {
    if (kReleaseMode) return; // Always disabled in release
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('simulator_mode', state);
  }
}

// ─── App Version ───
final appVersionProvider = Provider<String>((ref) => '1.0.0');
