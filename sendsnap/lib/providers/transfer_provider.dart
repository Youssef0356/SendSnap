import 'dart:async';
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

  Timer? _mockTimer;

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

    if (target.id.startsWith('mock_')) {
      // Simulate target accepting after 1 second
      Future.delayed(const Duration(seconds: 1), () {
        if (state?.targetDevice.id == target.id) {
          _startMockTransfer();
        }
      });
      return;
    }

    await _activeService.sendFiles(
      target: target,
      files: files,
      senderName: senderName,
    );
  }

  /// Start a mock transfer simulation
  void _startMockTransfer() {
    _mockTimer?.cancel();
    int totalFiles = state?.files.length ?? 0;
    int currentFileIndex = 0;
      double progress = 0.0;

    _mockTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (state == null || state!.status == TransferSessionStatus.cancelled) {
        timer.cancel();
        return;
      }

      progress += 0.05; // Increment progress
      
      double overallProgress = (currentFileIndex + progress) / totalFiles;

      // Update the files list with individual progress
      final updatedFiles = List<TransferFile>.from(state!.files);
      updatedFiles[currentFileIndex] = updatedFiles[currentFileIndex].copyWith(
        status: FileTransferStatus.transferring,
        progress: progress.clamp(0.0, 1.0),
      );

      if (progress >= 1.0) {
        // Mark current file as completed
        updatedFiles[currentFileIndex] = updatedFiles[currentFileIndex].copyWith(
          status: FileTransferStatus.completed,
          progress: 1.0,
        );
        
        progress = 0.0;
        currentFileIndex++;
        
        if (currentFileIndex >= totalFiles) {
          state = state!.copyWith(
            status: TransferSessionStatus.completed,
            overallProgress: 1.0,
            files: updatedFiles,
          );
          timer.cancel();
          return;
        }
      }

      state = state!.copyWith(
        status: TransferSessionStatus.transferring,
        overallProgress: overallProgress,
        files: updatedFiles,
      );
    });
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

    if (request.senderIp == 'mock_ip') {
      Future.delayed(const Duration(milliseconds: 500), () {
        _startMockTransfer();
      });
      return;
    }

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
    _mockTimer?.cancel();
    state = null;
  }

  /// Trigger a mock incoming request for testing
  void triggerMockIncomingRequest() {
    final mockRequest = IncomingRequest(
      senderName: 'Simulator Pro',
      senderIp: 'mock_ip',
      senderPort: 8080,
      files: [
        TransferFile(
          name: 'mock_image_1.jpg',
          size: 1024 * 1024 * 2, // 2MB
          path: '',
        ),
        TransferFile(
          name: 'mock_video_presentation.mp4',
          size: 1024 * 1024 * 45, // 45MB
          path: '',
        ),
      ],
    );
    _ref.read(incomingRequestProvider.notifier).state = mockRequest;
  }
}

// ─── Incoming Request ───
final incomingRequestProvider =
    StateProvider<IncomingRequest?>((ref) => null);
