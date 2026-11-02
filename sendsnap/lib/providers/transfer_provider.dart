import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import '../models/transfer.dart';
import '../models/device.dart';
import '../services/nearby_service.dart';

class TransferProvider with ChangeNotifier {
  final List<FileTransfer> _transfers = [];
  FileTransfer? _activeTransfer;

  // Callbacks for UI navigation & notification
  VoidCallback? onTransferStarted;
  VoidCallback? onTransferCompleted;

  List<FileTransfer> get transfers => _transfers;
  FileTransfer? get activeTransfer => _activeTransfer;

  /// Returns the most recent transfer (active or last in list)
  FileTransfer? get currentTransfer => _activeTransfer ?? (_transfers.isNotEmpty ? _transfers.first : null);

  void addTransfer(FileTransfer transfer) {
    _transfers.insert(0, transfer);
    if (transfer.status == TransferStatus.inProgress || transfer.status == TransferStatus.pending) {
      _activeTransfer = transfer;
    }
    notifyListeners();
  }

  void handleIncomingTransfer(NearbyDevice sender, FileTransfer transfer) {
    debugPrint('[TransferProvider] Handling incoming transfer: ${transfer.fileName}');
    addTransfer(transfer);
    onTransferStarted?.call();
  }

  void updateTransferProgress({
    required String transferId,
    required int bytesTransferred,
    required int totalBytes,
    required double speed,
  }) {
    final index = _transfers.indexWhere((t) => t.id == transferId);
    if (index == -1) return;

    final updated = _transfers[index].copyWith(
      transferredBytes: bytesTransferred,
      fileSize: totalBytes > 0 ? totalBytes : _transfers[index].fileSize,
      speed: speed,
      status: TransferStatus.inProgress,
    );

    _transfers[index] = updated;
    _activeTransfer = updated;
    notifyListeners();
  }

  void markTransferCompleted({
    required String transferId,
    required String savedPath,
  }) {
    final index = _transfers.indexWhere((t) => t.id == transferId);
    if (index == -1) return;

    final completed = _transfers[index].copyWith(
      transferredBytes: _transfers[index].fileSize,
      status: TransferStatus.completed,
      savedPath: savedPath,
    );

    _transfers[index] = completed;
    _activeTransfer = completed;
    notifyListeners();
    onTransferCompleted?.call();
  }

  void markTransferFailed({
    required String transferId,
    required String error,
  }) {
    final index = _transfers.indexWhere((t) => t.id == transferId);
    if (index == -1) return;

    final failed = _transfers[index].copyWith(
      status: TransferStatus.failed,
      errorMessage: error,
    );

    _transfers[index] = failed;
    _activeTransfer = failed;
    notifyListeners();
  }

  /// Initiates sending a file to target device.
  /// Supports either passing a NearbyDevice object or its endpoint ID string.
  Future<bool> sendFile(
    dynamic targetOrEndpointId,
    File file,
    NearbyService service,
  ) async {
    return sendFiles(targetOrEndpointId, [file], service);
  }

  /// Initiates sending multiple files to target device.
  Future<bool> sendFiles(
    dynamic targetOrEndpointId,
    List<File> files,
    NearbyService service,
  ) async {
    if (files.isEmpty) return false;

    NearbyDevice? target;
    if (targetOrEndpointId is NearbyDevice) {
      target = targetOrEndpointId;
    } else if (targetOrEndpointId is String) {
      target = service.getDevice(targetOrEndpointId);
    }

    if (target == null) {
      debugPrint('[TransferProvider] Cannot send file: Target device not found');
      return false;
    }

    final transfers = <FileTransfer>[];
    for (int i = 0; i < files.length; i++) {
      final f = files[i];
      final size = await f.length();
      final t = FileTransfer(
        id: '${DateTime.now().millisecondsSinceEpoch}_$i',
        fileName: path.basename(f.path),
        fileSize: size,
        filePath: f.path,
        status: i == 0 ? TransferStatus.inProgress : TransferStatus.pending,
      );
      transfers.add(t);
      addTransfer(t);
    }

    final success = await service.sendFilesStream(
      target: target,
      transfers: transfers,
      files: files,
    );

    return success;
  }

  void clearHistory() {
    _transfers.removeWhere((t) => t.status != TransferStatus.inProgress);
    _activeTransfer = null;
    notifyListeners();
  }

  void dismissActiveTransfer() {
    _activeTransfer = null;
    notifyListeners();
  }
}
