import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import '../models/transfer.dart';
import '../models/payload.dart';
import '../services/nearby_service.dart';
import '../services/file_handler.dart';

class TransferProvider with ChangeNotifier {
  final List<FileTransfer> _transfers = [];
  FileTransfer? _activeTransfer;
  
  // Maps to track payload relations
  final Map<int, String> _payloadToTransferId = {}; // payloadId -> transferId
  final Map<int, String> _payloadToTempPath = {}; // payloadId -> tempPath (for receiving)

  List<FileTransfer> get transfers => _transfers;
  FileTransfer? get activeTransfer => _activeTransfer;

  void addTransfer(FileTransfer transfer) {
    _transfers.insert(0, transfer);
    if (transfer.status == TransferStatus.inProgress) {
      _activeTransfer = transfer;
    }
    notifyListeners();
  }

  void updateTransferProgress(int payloadId, PayloadTransferUpdate update) async {
    final transferId = _payloadToTransferId[payloadId];
    if (transferId == null) return;

    final index = _transfers.indexWhere((t) => t.id == transferId);
    if (index == -1) return;

    var transfer = _transfers[index];

    if (update.status == PayloadStatus.IN_PROGRESS) {
      transfer = transfer.copyWith(
        transferredBytes: update.bytesTransferred,
        status: TransferStatus.inProgress,
      );
      if (_activeTransfer?.id == transferId) _activeTransfer = transfer;
    } 
    else if (update.status == PayloadStatus.SUCCESS) {
      // If receiving, move the file from temp to downloads
      if (_payloadToTempPath.containsKey(payloadId)) {
        final tempPath = _payloadToTempPath[payloadId]!;
        await FileHandler.moveFileToDownloads(tempPath, transfer.fileName);
        _payloadToTempPath.remove(payloadId);
      }

      transfer = transfer.copyWith(
         transferredBytes: transfer.fileSize,
         status: TransferStatus.completed,
      );
      if (_activeTransfer?.id == transferId) _activeTransfer = null;
    } 
    else if (update.status == PayloadStatus.FAILURE || update.status == PayloadStatus.CANCELED) {
      transfer = transfer.copyWith(status: TransferStatus.failed);
      if (_activeTransfer?.id == transferId) _activeTransfer = null;
    }

    _transfers[index] = transfer;
    notifyListeners();
  }

  void handleIncomingMetadata(String endpointId, PayloadWrapper wrapper, NearbyService service) {
    if (wrapper.type == 'FILE_META') {
      // Received information about a file the sender is about to send
      final transfer = FileTransfer(
        id: wrapper.data['id'],
        fileName: wrapper.data['name'],
        fileSize: wrapper.data['size'],
        status: TransferStatus.pending,
      );
      addTransfer(transfer);
      
      // Auto-accept the metadata by responding with an ACK if needed, 
      // but Nearby Connections handles the actual file stream.
      // We just need to wait for the FILE payload now.
    } 
    else if (wrapper.type == 'FILE_INCOMING') {
      // This is our internal wrapper for when a FILE payload actually starts
      final payloadId = wrapper.data['payloadId'] as int;
      final tempPath = wrapper.data['tempPath'] as String;
      
      // Attempt to link this payload to the most recent PENDING transfer from this endpoint
      try {
        final pendingTransfer = _transfers.firstWhere((t) => t.status == TransferStatus.pending);
        _payloadToTransferId[payloadId] = pendingTransfer.id;
        _payloadToTempPath[payloadId] = tempPath.replaceFirst('file://', '');
        
        // Update status to inProgress
        final index = _transfers.indexOf(pendingTransfer);
        _transfers[index] = pendingTransfer.copyWith(status: TransferStatus.inProgress);
        _activeTransfer = _transfers[index];
        notifyListeners();
      } catch (e) {
        debugPrint('[TransferProvider] Could not match payload $payloadId to a pending transfer');
      }
    }
  }

  Future<void> sendFile(String endpointId, File file, NearbyService service) async {
    final transferId = DateTime.now().millisecondsSinceEpoch.toString();
    final transfer = FileTransfer(
      id: transferId,
      fileName: path.basename(file.path),
      fileSize: await file.length(),
      status: TransferStatus.inProgress,
    );
    addTransfer(transfer);

    // 1. Send metadata first
    await service.sendMetadata(endpointId, PayloadWrapper(
      type: 'FILE_META',
      data: {
        'id': transfer.id,
        'name': transfer.fileName,
        'size': transfer.fileSize,
      },
    ));

    // 2. Send actual file
    final payloadId = await service.sendFile(endpointId, file.path);
    _payloadToTransferId[payloadId] = transferId;
  }

  void clearHistory() {
    _transfers.removeWhere((t) => t.status != TransferStatus.inProgress);
    notifyListeners();
  }
}
