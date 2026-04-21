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

  // Callback for UI navigation when a transfer starts on receiver side
  VoidCallback? onTransferStarted;
  // Callback for UI notification when a transfer completes
  VoidCallback? onTransferCompleted;

  List<FileTransfer> get transfers => _transfers;
  FileTransfer? get activeTransfer => _activeTransfer;

  /// Returns the most recent transfer (active or last in list)
  FileTransfer? get currentTransfer => _activeTransfer ?? (_transfers.isNotEmpty ? _transfers.first : null);

  void addTransfer(FileTransfer transfer) {
    _transfers.insert(0, transfer);
    if (transfer.status == TransferStatus.inProgress) {
      _activeTransfer = transfer;
    }
    notifyListeners();
  }

  void updateTransferProgress(int payloadId, PayloadTransferUpdate update) async {
    final transferId = _payloadToTransferId[payloadId];
    if (transferId == null) {
      debugPrint('[TransferProvider] No transfer found for payloadId: $payloadId');
      return;
    }

    final index = _transfers.indexWhere((t) => t.id == transferId);
    if (index == -1) {
      debugPrint('[TransferProvider] Transfer $transferId not found in list');
      return;
    }

    var transfer = _transfers[index];

    if (update.status == PayloadStatus.IN_PROGRESS) {
      transfer = transfer.copyWith(
        transferredBytes: update.bytesTransferred,
        status: TransferStatus.inProgress,
      );
      _activeTransfer = transfer;
      _transfers[index] = transfer;
      notifyListeners();
    } 
    else if (update.status == PayloadStatus.SUCCESS) {
      debugPrint('[TransferProvider] Transfer SUCCESS for payloadId: $payloadId');
      
      // If receiving, move the file from temp to downloads
      String? savedPath;
      if (_payloadToTempPath.containsKey(payloadId)) {
        final tempPath = _payloadToTempPath[payloadId]!;
        try {
          debugPrint('[TransferProvider] Moving file from: $tempPath to downloads as: ${transfer.fileName}');
          final savedFile = await FileHandler.moveFileToDownloads(tempPath, transfer.fileName);
          if (savedFile != null) {
            savedPath = savedFile.path;
            debugPrint('[TransferProvider] File moved successfully to: $savedPath');
          } else {
            debugPrint('[TransferProvider] WARNING: File move failed for: $tempPath');
          }
        } catch (e) {
          debugPrint('[TransferProvider] Error moving file to downloads: $e');
        }
        _payloadToTempPath.remove(payloadId);
      }

      transfer = transfer.copyWith(
         transferredBytes: transfer.fileSize,
         status: TransferStatus.completed,
         savedPath: savedPath,
      );
      _transfers[index] = transfer;
      
      // Keep activeTransfer pointing to the completed transfer so UI can show success
      _activeTransfer = transfer;
      notifyListeners();
      
      // Notify UI that transfer completed
      onTransferCompleted?.call();
      
      // Clear active transfer after a delay so the UI has time to show success
      Future.delayed(const Duration(seconds: 1), () {
        if (_activeTransfer?.id == transferId && _activeTransfer?.status == TransferStatus.completed) {
          // Don't null it out — let currentTransfer getter handle fallback
          // This way the transfer screen still shows the completed state
        }
      });
    } 
    else if (update.status == PayloadStatus.FAILURE || update.status == PayloadStatus.CANCELED) {
      debugPrint('[TransferProvider] Transfer FAILED for payloadId: $payloadId, status: ${update.status}');
      transfer = transfer.copyWith(status: TransferStatus.failed);
      _transfers[index] = transfer;
      _activeTransfer = transfer;
      notifyListeners();
    }
  }

  void handleIncomingMetadata(String endpointId, PayloadWrapper wrapper, NearbyService service) {
    if (wrapper.type == 'FILE_META') {
      debugPrint('[TransferProvider] Received FILE_META: ${wrapper.data}');
      // Received information about a file the sender is about to send
      final transfer = FileTransfer(
        id: wrapper.data['id'],
        fileName: wrapper.data['name'],
        fileSize: wrapper.data['size'],
        status: TransferStatus.pending,
      );
      addTransfer(transfer);
      
      // Notify UI that an incoming transfer is starting (for receiver auto-navigation)
      onTransferStarted?.call();
    } 
    else if (wrapper.type == 'FILE_INCOMING') {
      debugPrint('[TransferProvider] Received FILE_INCOMING: payloadId=${wrapper.data['payloadId']}, tempPath=${wrapper.data['tempPath']}');
      // This is our internal wrapper for when a FILE payload actually starts
      final payloadId = wrapper.data['payloadId'] as int;
      final tempPath = wrapper.data['tempPath'] as String;
      
      // Attempt to link this payload to the most recent PENDING transfer from this endpoint
      try {
        final pendingTransfer = _transfers.firstWhere((t) => t.status == TransferStatus.pending);
        _payloadToTransferId[payloadId] = pendingTransfer.id;
        _payloadToTempPath[payloadId] = tempPath;
        
        debugPrint('[TransferProvider] Linked payloadId $payloadId to transfer ${pendingTransfer.id}, tempPath: $tempPath');
        
        // Update status to inProgress
        final index = _transfers.indexOf(pendingTransfer);
        _transfers[index] = pendingTransfer.copyWith(status: TransferStatus.inProgress);
        _activeTransfer = _transfers[index];
        notifyListeners();
      } catch (e) {
        debugPrint('[TransferProvider] Could not match payload $payloadId to a pending transfer: $e');
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
    debugPrint('[TransferProvider] Sending FILE_META for ${transfer.fileName} (${transfer.fileSize} bytes)');
    await service.sendMetadata(endpointId, PayloadWrapper(
      type: 'FILE_META',
      data: {
        'id': transfer.id,
        'name': transfer.fileName,
        'size': transfer.fileSize,
      },
    ));

    // Small delay to ensure metadata arrives before file payload
    await Future.delayed(const Duration(milliseconds: 300));

    // 2. Send actual file
    debugPrint('[TransferProvider] Sending file payload: ${file.path}');
    final payloadId = await service.sendFile(endpointId, file.path);
    _payloadToTransferId[payloadId] = transferId;
    debugPrint('[TransferProvider] File payload sent with payloadId: $payloadId');
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
