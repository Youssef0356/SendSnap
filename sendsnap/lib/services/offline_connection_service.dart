import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:path_provider/path_provider.dart';
import '../models/device.dart';
import '../models/transfer_file.dart';

class OfflineConnectionService {
  static const Strategy strategy = Strategy.P2P_POINT_TO_POINT;

  bool _isBroadcasting = false;
  bool _isDiscovering = false;

  final Map<String, NearbyDevice> _discoveredDevices = {};
  final _devicesController = StreamController<List<NearbyDevice>>.broadcast();

  // Active Connections Map
  final Map<String, ConnectionInfo> _connectedEndpoints = {};

  // Transfer Callbacks
  Function(IncomingRequest)? onIncomingRequest;
  Function(TransferSession)? onTransferUpdate;
  Function(String)? onError;
  Function()? onTransferComplete;

  TransferSession? _currentSession;
  final Map<int, TransferFile> _payloadMap = {}; // Payload ID to TransferFile

  Stream<List<NearbyDevice>> get devicesStream => _devicesController.stream;
  List<NearbyDevice> get currentDevices => _discoveredDevices.values.toList();

  Future<void> startBroadcast(String deviceName) async {
    if (_isBroadcasting) return;
    try {
      bool success = await Nearby().startAdvertising(
        deviceName,
        strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      _isBroadcasting = success;
      debugPrint('[Offline] Advertising $deviceName: $success');
    } catch (e) {
      debugPrint('[Offline] Advertising error: $e');
    }
  }

  Future<void> stopBroadcast() async {
    if (!_isBroadcasting) return;
    try {
      await Nearby().stopAdvertising();
      _isBroadcasting = false;
      debugPrint('[Offline] Stopped Advertising');
    } catch (e) {
      debugPrint('[Offline] Stop Adv error: $e');
    }
  }

  Future<void> startDiscovery() async {
    if (_isDiscovering) return;
    try {
      bool success = await Nearby().startDiscovery(
        "sendsnap", // Username doesn't matter much for discovery
        strategy,
        onEndpointFound: (endpointId, endpointName, serviceId) {
          debugPrint('[Offline] Endpoint found: $endpointName ($endpointId)');
          
          // Filter out self if discovered (Nearby Connections usually doesn't, but for safety)
          if (endpointName.contains('($endpointId)')) {
             // This is a heuristic, better to check against a stored local ID if available
          }

          final device = NearbyDevice(
            id: endpointId,
            name: endpointName,
            ip: endpointId, // using endpointId as IP internally
            port: 0, // Not applicable offline
          );
          _discoveredDevices[endpointId] = device;
          _devicesController.add(_discoveredDevices.values.toList());
        },
        onEndpointLost: (endpointId) {
          _discoveredDevices.remove(endpointId);
          _devicesController.add(_discoveredDevices.values.toList());
        },
      );
      _isDiscovering = success;
    } catch (e) {
      debugPrint('[Offline] Discovery error: $e');
    }
  }

  Future<void> stopDiscovery() async {
    if (!_isDiscovering) return;
    try {
      await Nearby().stopDiscovery();
      _isDiscovering = false;
      _discoveredDevices.clear();
      _devicesController.add([]);
    } catch (e) {
      debugPrint('[Offline] Stop Discovery error: $e');
    }
  }

  Future<void> sendFiles({
    required NearbyDevice target,
    required List<TransferFile> files,
    required String senderName,
  }) async {
    try {
      _payloadMap.clear();
      _receivedPayloadPaths.clear();
      
      _currentSession = TransferSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        targetDevice: target,
        files: files,
        direction: TransferDirection.sending,
        status: TransferSessionStatus.waitingForAccept,
      );
      onTransferUpdate?.call(_currentSession!);

      // Connect to endpoint
      await Nearby().requestConnection(
        senderName,
        target.id,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: (id, status) {
          _onConnectionResult(id, status);
          if (status == Status.CONNECTED) {
            // Once connected, wait a slight moment, then send metadata payload
            Future.delayed(const Duration(milliseconds: 500), () {
              _sendHeader(target.id, senderName, files);
            });
          }
        },
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      onError?.call('Send error: $e');
    }
  }

  void _sendHeader(String endpointId, String senderName, List<TransferFile> files) {
    final metadata = {
      'type': 'header',
      'sender': senderName,
      'files': files.map((f) => f.toJson()).toList(),
    };
    final jsonBytes = utf8.encode(jsonEncode(metadata));
    Nearby().sendBytesPayload(endpointId, Uint8List.fromList(jsonBytes));
  }

  Future<void> acceptTransfer(IncomingRequest request) async {
    _payloadMap.clear();
    _receivedPayloadPaths.clear();
    
    // Notify sender we accepted
    final msg = {'type': 'accept'};
    final jsonBytes = utf8.encode(jsonEncode(msg));
    await Nearby().sendBytesPayload(request.senderIp, Uint8List.fromList(jsonBytes));

    _currentSession = TransferSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      targetDevice: NearbyDevice(
        id: request.senderIp,
        name: request.senderName,
        ip: request.senderIp,
        port: request.senderPort,
      ),
      files: request.files,
      direction: TransferDirection.receiving,
      status: TransferSessionStatus.transferring,
    );
    onTransferUpdate?.call(_currentSession!);
  }

  void declineTransfer(IncomingRequest request) {
    Nearby().disconnectFromEndpoint(request.senderIp);
  }

  void cancelTransfer() {
    if (_currentSession != null) {
      Nearby().disconnectFromEndpoint(_currentSession!.targetDevice.id);
      _currentSession = null;
    }
  }

  // --- NEARBY CALLBACKS ---

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    debugPrint('[Offline] Connection initiated with ${info.endpointName}');
    _connectedEndpoints[endpointId] = info;
    // Auto-accept the initial connection (both sides must accept just to talk)
    Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: (endpoint, payload) => _onPayloadReceived(endpoint, payload),
      onPayloadTransferUpdate: (endpoint, update) => _onPayloadTransferUpdate(endpoint, update),
    );
  }

  void _onConnectionResult(String endpointId, Status status) {
    debugPrint('[Offline] Connection to $endpointId result: $status');
    if (status != Status.CONNECTED) {
      _connectedEndpoints.remove(endpointId);
      if (_currentSession != null && _currentSession!.status == TransferSessionStatus.waitingForAccept) {
        _currentSession = _currentSession!.copyWith(status: TransferSessionStatus.error);
        onTransferUpdate?.call(_currentSession!);
      }
    }
  }

  void _onDisconnected(String endpointId) {
    _connectedEndpoints.remove(endpointId);
    if (_currentSession != null && _currentSession!.targetDevice.id == endpointId) {
       if (_currentSession!.status != TransferSessionStatus.completed) {
         _currentSession = _currentSession!.copyWith(status: TransferSessionStatus.connectionLost);
         onTransferUpdate?.call(_currentSession!);
       }
    }
  }

  void _onPayloadReceived(String endpointId, Payload payload) async {
    if (payload.type == PayloadType.BYTES) {
      if (payload.bytes == null) return;
      final jsonStr = utf8.decode(payload.bytes!);
      try {
        final data = jsonDecode(jsonStr);
        if (data['type'] == 'header') {
          // Received file metadata
          final senderName = data['sender'] as String;
          final filesJson = data['files'] as List;
          final files = filesJson.map((f) => TransferFile.fromJson(f as Map<String, dynamic>)).toList();
          final request = IncomingRequest(
            senderName: senderName,
            senderIp: endpointId,
            senderPort: 0,
            files: files,
            socket: null,
          );
          onIncomingRequest?.call(request);
        } else if (data['type'] == 'accept') {
          // Sender received confirmation to send real files
          _startSendingFiles();
        }
      } catch (e) {
        debugPrint('[Offline] Invalid JSON payload: $e');
      }
    } else if (payload.type == PayloadType.FILE) {
      // Incoming file payload
      debugPrint('[Offline] Started receiving file payload ${payload.id} at ${payload.uri ?? payload.filePath}');
      
      if (_currentSession != null) {
        // Map this payload ID to the next unassigned incoming file
        final unassignedFile = _currentSession!.files.firstWhere(
            (f) => !_payloadMap.values.any((mapped) => mapped.name == f.name),
            orElse: () => _currentSession!.files.first);
            
        _payloadMap[payload.id] = unassignedFile;
        if (payload.uri != null || payload.filePath != null) {
          _receivedPayloadPaths[payload.id] = payload.uri ?? payload.filePath!;
        }
      }
    }
  }

  void _startSendingFiles() async {
    if (_currentSession == null) return;
    _currentSession = _currentSession!.copyWith(status: TransferSessionStatus.transferring);
    onTransferUpdate?.call(_currentSession!);

    final targetId = _currentSession!.targetDevice.id;
    for (int i = 0; i < _currentSession!.files.length; i++) {
        var file = _currentSession!.files[i];
        final payloadId = await Nearby().sendFilePayload(targetId, file.path);
        _payloadMap[payloadId] = file;
    }
  }

  final Map<int, String> _receivedPayloadPaths = {};

  void _onPayloadTransferUpdate(String endpointId, PayloadTransferUpdate update) async {
    if (_currentSession == null) return;

    // Ignore payload updates for things we aren't explicitly tracking as FILES
    if (!_payloadMap.containsKey(update.id)) return;

    final file = _payloadMap[update.id]!;
    final mutableFiles = List<TransferFile>.from(_currentSession!.files);
    final fileIndex = mutableFiles.indexWhere((f) => f.name == file.name);
    if (fileIndex == -1) return;

    if (update.status == PayloadStatus.IN_PROGRESS) {
      if (update.totalBytes > 0) {
        mutableFiles[fileIndex] = mutableFiles[fileIndex].copyWith(
          status: FileTransferStatus.transferring,
          progress: update.bytesTransferred / update.totalBytes,
        );
        _currentSession = _currentSession!.copyWith(files: mutableFiles);
        onTransferUpdate?.call(_currentSession!);
      }
    } else if (update.status == PayloadStatus.SUCCESS) {
      mutableFiles[fileIndex] = mutableFiles[fileIndex].copyWith(
        status: FileTransferStatus.completed,
        progress: 1.0,
      );

      // On receiving end, the file needs to be moved to the SendSnap downloads folder
      if (_currentSession!.direction == TransferDirection.receiving) {
        try {
          final saveDir = await _getSaveDirectory();
          final savePath = '${saveDir.path}/${file.name}';
          final sourcePath = _receivedPayloadPaths[update.id];
          
          if (sourcePath != null) {
            // Attempt to copy from the generic path Nearby Connections downloaded it to
            final sourceFile = File(sourcePath.replaceFirst('file://', ''));
            if (await sourceFile.exists()) {
              await sourceFile.copy(savePath);
              mutableFiles[fileIndex] = mutableFiles[fileIndex].copyWith(path: savePath);
            }
          }
        } catch (e) {
          debugPrint('[Offline] Failed to move received file: $e');
        }
      }

      _currentSession = _currentSession!.copyWith(files: mutableFiles);
      
      final allCompleted = _currentSession!.files.every((f) => f.status == FileTransferStatus.completed);

      if (allCompleted) {
        _currentSession = _currentSession!.copyWith(
          overallProgress: 1.0, 
          status: TransferSessionStatus.completed,
        );
        onTransferUpdate?.call(_currentSession!);
        onTransferComplete?.call();
        Nearby().disconnectFromEndpoint(endpointId);
      } else {
        onTransferUpdate?.call(_currentSession!);
      }
    } else if (update.status == PayloadStatus.FAILURE || update.status == PayloadStatus.CANCELED) {
      mutableFiles[fileIndex] = mutableFiles[fileIndex].copyWith(
        status: FileTransferStatus.failed,
      );
      _currentSession = _currentSession!.copyWith(files: mutableFiles);
      onTransferUpdate?.call(_currentSession!);
    }
  }

  Future<Directory> _getSaveDirectory() async {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download/SendSnap');
    } else {
      dir = await getApplicationDocumentsDirectory();
      dir = Directory('${dir.path}/SendSnap');
    }
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> dispose() async {
    await stopBroadcast();
    await stopDiscovery();
  }
}
