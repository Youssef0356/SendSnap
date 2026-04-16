import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device.dart';
import '../models/transfer_file.dart';
import '../services/transfer_service.dart';
import 'device_provider.dart';
import 'settings_provider.dart';

// ─── Active Transfer Session ───
final activeTransferProvider =
    StateNotifierProvider<TransferNotifier, TransferSession?>((ref) {
  return TransferNotifier(ref);
});

class TransferNotifier extends StateNotifier<TransferSession?> {
  final Ref _ref;
  Timer? _mockTimer;

  TransferNotifier(this._ref) : super(null) { _setupCallbacks(); }

  TransferService get _svc => _ref.read(transferServiceProvider);

  void _setupCallbacks() {
    void onUpdate(TransferSession s) { state = s; }
    void onComplete() {}
    void onError(String e) { if (state != null) state = state!.copyWith(status: TransferSessionStatus.error, errorMessage: e); }
    void onIncomingReq(IncomingRequest req) { _ref.read(incomingRequestProvider.notifier).state = req; }

    // Wire callbacks — will work after service is initialized
    _svc.onTransferUpdate = onUpdate;
    _svc.onTransferComplete = onComplete;
    _svc.onError = onError;
    _svc.onIncomingRequest = onIncomingReq;
  }

  Future<void> sendFiles({required NearbyDevice target, required List<TransferFile> files}) async {
    final senderName = _ref.read(deviceNameProvider);
    debugPrint('[SendSnap] TransferNotifier: sendFiles to ${target.name} (${target.ip}:${target.port})');
    state = TransferSession(id: '${DateTime.now().millisecondsSinceEpoch}', targetDevice: target, files: files, direction: TransferDirection.sending, status: TransferSessionStatus.waitingForAccept);

    if (target.id.startsWith('mock_')) {
      debugPrint('[SendSnap] TransferNotifier: Starting mock transfer');
      Future.delayed(const Duration(seconds: 1), () { if (state?.targetDevice.id == target.id) _mockTransfer(); });
      return;
    }
    try {
      await _svc.sendFiles(target: target, files: files, senderName: senderName);
    } catch (e) {
      debugPrint('[SendSnap] TransferNotifier: Error in sendFiles: $e');
      if (state != null) state = state!.copyWith(status: TransferSessionStatus.error, errorMessage: e.toString());
    }
  }

  void _mockTransfer() {
    _mockTimer?.cancel();
    int fi = 0; double p = 0.0;
    final total = state?.files.length ?? 1;
    _mockTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (state == null || state!.status == TransferSessionStatus.cancelled) { t.cancel(); return; }
      p += 0.05;
      final files = List<TransferFile>.from(state!.files);
      files[fi] = files[fi].copyWith(status: FileTransferStatus.transferring, progress: p.clamp(0.0, 1.0));
      if (p >= 1.0) { files[fi] = files[fi].copyWith(status: FileTransferStatus.completed, progress: 1.0); p = 0.0; fi++; }
      if (fi >= total) { state = state!.copyWith(status: TransferSessionStatus.completed, overallProgress: 1.0, files: files); t.cancel(); return; }
      state = state!.copyWith(status: TransferSessionStatus.transferring, overallProgress: (fi + p) / total, files: files);
    });
  }

  Future<void> acceptIncoming(IncomingRequest req) async {
    debugPrint('[SendSnap] TransferNotifier: acceptIncoming from ${req.senderName}');
    state = TransferSession(id: '${DateTime.now().millisecondsSinceEpoch}', targetDevice: NearbyDevice(id: req.senderIp, name: req.senderName, ip: req.senderIp, port: 0, status: DeviceStatus.ready), files: req.files, direction: TransferDirection.receiving, status: TransferSessionStatus.transferring);
    if (req.senderIp == 'mock_ip') { 
      debugPrint('[SendSnap] TransferNotifier: Starting mock incoming');
      Future.delayed(const Duration(milliseconds: 500), () => _mockTransfer()); 
      return; 
    }
    try {
      await _svc.acceptTransfer(req);
    } catch (e) {
      debugPrint('[SendSnap] TransferNotifier: Error in acceptIncoming: $e');
      if (state != null) state = state!.copyWith(status: TransferSessionStatus.error, errorMessage: e.toString());
    }
  }

  void declineIncoming(IncomingRequest req) { _svc.declineTransfer(req); }
  void cancelTransfer() { _svc.cancelTransfer(); if (state != null) state = state!.copyWith(status: TransferSessionStatus.cancelled); }
  void clearTransfer() { _mockTimer?.cancel(); state = null; }

  void triggerMockIncomingRequest() {
    _ref.read(incomingRequestProvider.notifier).state = IncomingRequest(
      senderName: 'Simulator Pro', senderIp: 'mock_ip', senderPort: 8080,
      files: [TransferFile(name: 'mock_image.jpg', size: 2 * 1024 * 1024, path: ''), TransferFile(name: 'mock_video.mp4', size: 45 * 1024 * 1024, path: '')],
    );
  }
}

// ─── Incoming Request ───
final incomingRequestProvider = StateProvider<IncomingRequest?>((ref) => null);
