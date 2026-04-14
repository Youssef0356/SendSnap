import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device.dart';
import '../models/transfer_file.dart';
import '../services/transfer_service.dart';
import 'device_provider.dart';
import 'connection_provider.dart';

// ─── Transfer Service Singleton ───
final transferServiceProvider = Provider<TransferService>((ref) {
  final service = TransferService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ─── Active Transfer Session ───
final activeTransferProvider =
    StateNotifierProvider<TransferNotifier, TransferSession?>((ref) {
  return TransferNotifier(ref);
});

class TransferNotifier extends StateNotifier<TransferSession?> {
  final Ref _ref;

  TransferNotifier(this._ref) : super(null) {
    _setupCallbacks();
  }

  dynamic get _activeService {
    if (_ref.read(connectionModeProvider) == ConnectionMode.offline) {
      return _ref.read(offlineConnectionServiceProvider);
    }
    return _ref.read(transferServiceProvider);
  }

  void _setupCallbacks() {
    final wifiService = _ref.read(transferServiceProvider);
    final offlineService = _ref.read(offlineConnectionServiceProvider);

    void onUpdate(TransferSession session) {
      state = session;
    }

    void onComplete() {}

    void onError(String error) {
      if (state != null) {
        state = state!.copyWith(
          status: TransferSessionStatus.error,
          errorMessage: error,
        );
      }
    }

    void onIncomingReq(IncomingRequest req) {
      _ref.read(incomingRequestProvider.notifier).state = req;
    }

    wifiService.onTransferUpdate = onUpdate;
    wifiService.onTransferComplete = onComplete;
    wifiService.onError = onError;
    wifiService.onIncomingRequest = onIncomingReq;

    offlineService.onTransferUpdate = onUpdate;
    offlineService.onTransferComplete = onComplete;
    offlineService.onError = onError;
    offlineService.onIncomingRequest = onIncomingReq;
  }

  /// Start sending files to a device.
  Future<void> sendFiles({
    required NearbyDevice target,
    required List<TransferFile> files,
  }) async {
    final senderName = _ref.read(deviceNameProvider);

    state = TransferSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      targetDevice: target,
      files: files,
      direction: TransferDirection.sending,
      status: TransferSessionStatus.waitingForAccept,
    );

    await _activeService.sendFiles(
      target: target,
      files: files,
      senderName: senderName,
    );
  }

  /// Accept an incoming transfer.
  Future<void> acceptIncoming(IncomingRequest request) async {
    state = TransferSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      targetDevice: NearbyDevice(
        id: request.senderIp,
        name: request.senderName,
        ip: request.senderIp,
        port: request.senderPort,
      ),
      files: request.files,
      direction: TransferDirection.receiving,
      status: TransferSessionStatus.waitingForAccept,
    );

    await _activeService.acceptTransfer(request);
  }
  
  /// Decline an incoming transfer.
  void declineIncoming(IncomingRequest request) {
    _activeService.declineTransfer(request);
  }

  /// Cancel the active transfer.
  void cancelTransfer() {
    _activeService.cancelTransfer();
    if (state != null) {
      state = state!.copyWith(status: TransferSessionStatus.cancelled);
    }
  }

  /// Clear the transfer state.
  void clearTransfer() {
    state = null;
  }
}

// ─── Incoming Request ───
final incomingRequestProvider =
    StateProvider<IncomingRequest?>((ref) => null);
