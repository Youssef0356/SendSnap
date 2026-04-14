import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectionMode { wifi, offline }

final connectionModeProvider =
    StateNotifierProvider<ConnectionModeNotifier, ConnectionMode>((ref) {
  return ConnectionModeNotifier();
});

class ConnectionModeNotifier extends StateNotifier<ConnectionMode> {
  final Connectivity _connectivity = Connectivity();

  ConnectionModeNotifier() : super(ConnectionMode.wifi) {
    _initConnectionMode();
    _connectivity.onConnectivityChanged.listen(_updateConnectionMode);
  }

  Future<void> _initConnectionMode() async {
    final result = await _connectivity.checkConnectivity();
    _updateConnectionMode(result);
  }

  void _updateConnectionMode(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) {
      state = ConnectionMode.wifi;
    } else {
      state = ConnectionMode.offline;
    }
  }

  void setMode(ConnectionMode mode) {
    state = mode;
  }
}
