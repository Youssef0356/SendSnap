import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectionMode { wifi, offline }

final connectionModeProvider =
    StateNotifierProvider<ConnectionModeNotifier, ConnectionMode>((ref) {
  return ConnectionModeNotifier();
});

class ConnectionModeNotifier extends StateNotifier<ConnectionMode> {
  // We've shifted the architecture to default to Offline (Nearby Connections API) 
  // identically to QuickShare/ShareIt, avoiding all Router/NAT isolation errors permanently.
  ConnectionModeNotifier() : super(ConnectionMode.offline);

  void setMode(ConnectionMode mode) {
    state = mode;
  }
}
