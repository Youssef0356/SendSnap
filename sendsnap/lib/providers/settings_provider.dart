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

// ─── App Version ───
final appVersionProvider = Provider<String>((ref) => '1.0.0');
