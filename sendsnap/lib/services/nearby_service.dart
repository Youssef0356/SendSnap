import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/device.dart';
import '../models/transfer.dart';
import 'network_info_service.dart';
import 'discovery_service.dart';
import 'http_transfer_server.dart';
import 'http_transfer_client.dart';

class NearbyService {
  final DiscoveryService _discoveryService = DiscoveryService();
  final HttpTransferServer _httpServer = HttpTransferServer();
  final HttpTransferClient _httpClient = HttpTransferClient();

  final Map<String, NearbyDevice> _knownDevices = {};
  NearbyDevice? _localDevice;
  String? _deviceId;

  // Callbacks for DeviceProvider
  Function(NearbyDevice)? onDeviceFound;
  Function(String)? onDeviceLost;
  Function(String, String)? onConnectionInitiated; // endpointId, deviceName
  Function(String, bool)? onConnectionResult;     // endpointId, success
  Function(String)? onDisconnected;

  // Callbacks for TransferProvider
  Function(NearbyDevice sender, FileTransfer transfer)? onIncomingTransfer;
  Function(String transferId, int bytesTransferred, int totalBytes, double speed)? onTransferProgress;
  Function(String transferId, String savedPath)? onTransferCompleted;
  Function(String transferId, String error)? onTransferFailed;

  NearbyDevice? get localDevice => _localDevice;
  HttpTransferServer get httpServer => _httpServer;
  HttpTransferClient get httpClient => _httpClient;

  NearbyService() {
    _deviceId = const Uuid().v4().substring(0, 8);
    _setupDiscoveryCallbacks();
    _setupServerCallbacks();
  }

  void _setupDiscoveryCallbacks() {
    _discoveryService.onDeviceFound = (device) {
      _knownDevices[device.id] = device;
      onDeviceFound?.call(device);
    };

    _discoveryService.onDeviceLost = (deviceId) {
      _knownDevices.remove(deviceId);
      onDeviceLost?.call(deviceId);
    };
  }

  void _setupServerCallbacks() {
    _httpServer.onRequestReceived = ({
      required String sessionId,
      required NearbyDevice sender,
      required List<FileTransfer> files,
    }) async {
      debugPrint('[NearbyService] Incoming transfer request from ${sender.name} (${files.length} files)');
      _knownDevices[sender.id] = sender;
      onConnectionInitiated?.call(sender.id, sender.name);

      for (final file in files) {
        onIncomingTransfer?.call(sender, file);
      }

      onConnectionResult?.call(sender.id, true);
      return true; // Auto-accept incoming transfer
    };

    _httpServer.onProgress = ({
      required String sessionId,
      required String fileId,
      required int bytesReceived,
      required int totalBytes,
      required double speed,
    }) {
      onTransferProgress?.call(fileId, bytesReceived, totalBytes, speed);
    };

    _httpServer.onFileCompleted = ({
      required String sessionId,
      required String fileId,
      required String savedPath,
    }) {
      onTransferCompleted?.call(fileId, savedPath);
    };

    _httpServer.onFileFailed = ({
      required String sessionId,
      required String fileId,
      required String error,
    }) {
      onTransferFailed?.call(fileId, error);
    };
  }

  Future<NearbyDevice> _ensureLocalDevice(String deviceName) async {
    final localIp = await NetworkInfoService.getLocalIpAddress() ?? '0.0.0.0';
    _deviceId ??= const Uuid().v4().substring(0, 8);

    _localDevice = NearbyDevice(
      id: _deviceId!,
      name: deviceName,
      ip: localIp,
      port: HttpTransferServer.defaultPort,
      deviceType: NetworkInfoService.getPlatformName(),
    );
    return _localDevice!;
  }

  /// Start receiving mode (Embedded HTTP Server + Discovery Broadcast).
  Future<bool> startAdvertising(String deviceName) async {
    try {
      debugPrint('[NearbyService] Starting advertising as $deviceName...');
      final local = await _ensureLocalDevice(deviceName);

      // Start embedded HTTP server
      final boundPort = await _httpServer.startServer(localDevice: local);
      if (boundPort == null) {
        debugPrint('[NearbyService] Failed to start HTTP server');
        return false;
      }

      _localDevice = local.copyWith(port: boundPort);

      // Start discovery announcements
      final discoveryOk = await _discoveryService.startDiscovery(localDevice: _localDevice!);
      debugPrint('[NearbyService] Advertising active on ${_localDevice!.ip}:$boundPort (discovery=$discoveryOk)');
      return discoveryOk;
    } catch (e) {
      debugPrint('[NearbyService] Advertising error: $e');
      return false;
    }
  }

  /// Start sending mode (Listen for receiving devices on Wi-Fi).
  Future<bool> startDiscovery(String deviceName) async {
    try {
      debugPrint('[NearbyService] Starting discovery for $deviceName...');
      final local = await _ensureLocalDevice(deviceName);
      return await _discoveryService.startDiscovery(localDevice: local);
    } catch (e) {
      debugPrint('[NearbyService] Discovery error: $e');
      return false;
    }
  }

  Future<void> stopAll() async {
    try {
      await _discoveryService.stopDiscovery();
      await _httpServer.stopServer();
      _knownDevices.clear();
      debugPrint('[NearbyService] Stopped all services');
    } catch (e) {
      debugPrint('[NearbyService] stopAll error: $e');
    }
  }

  NearbyDevice? getDevice(String endpointId) => _knownDevices[endpointId];

  void addManualDevice(NearbyDevice device) {
    _knownDevices[device.id] = device;
    _discoveryService.registerManualDevice(device);
  }

  /// Request connection/handshake with a discovered target device.
  Future<bool> requestConnection(String deviceName, String endpointId) async {
    final target = _knownDevices[endpointId];
    if (target == null) {
      debugPrint('[NearbyService] Unknown endpointId: $endpointId');
      return false;
    }

    try {
      onConnectionInitiated?.call(endpointId, target.name);
      final pingDevice = await _httpClient.ping(target.ip, target.port);
      final success = pingDevice != null;
      onConnectionResult?.call(endpointId, success);
      return success;
    } catch (e) {
      debugPrint('[NearbyService] requestConnection error: $e');
      onConnectionResult?.call(endpointId, false);
      return false;
    }
  }

  Future<void> acceptConnection(String endpointId) async {
    // Handled automatically via HTTP protocol
  }

  Future<void> rejectConnection(String endpointId) async {
    // Handled automatically
  }

  /// Uploads a single file to the target device.
  Future<bool> sendFileStream({
    required NearbyDevice target,
    required FileTransfer transfer,
    required File file,
  }) async {
    return sendFilesStream(
      target: target,
      transfers: [transfer],
      files: [file],
    );
  }

  /// Uploads multiple files sequentially to the target device in a single session.
  Future<bool> sendFilesStream({
    required NearbyDevice target,
    required List<FileTransfer> transfers,
    required List<File> files,
  }) async {
    if (_localDevice == null) {
      await _ensureLocalDevice('Sender');
    }

    final sessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Prepare batch transfer
    final prepared = await _httpClient.prepareTransfer(
      target: target,
      sender: _localDevice!,
      sessionId: sessionId,
      files: transfers,
    );

    if (!prepared) {
      debugPrint('[NearbyService] Target declined or unreachable');
      for (final t in transfers) {
        onTransferFailed?.call(t.id, 'Target device declined or unreachable');
      }
      return false;
    }

    // 2. Stream each file
    bool allOk = true;
    for (int i = 0; i < files.length; i++) {
      final f = files[i];
      final t = transfers[i];

      final ok = await _httpClient.uploadFile(
        target: target,
        sessionId: sessionId,
        fileTransfer: t,
        file: f,
        onProgress: (sentBytes, totalBytes, speed) {
          onTransferProgress?.call(t.id, sentBytes, totalBytes, speed);
        },
      );

      if (ok) {
        onTransferCompleted?.call(t.id, f.path);
      } else {
        onTransferFailed?.call(t.id, 'Connection lost during transfer');
        allOk = false;
        break;
      }
    }

    return allOk;
  }

  void disconnect(String endpointId) {
    onDisconnected?.call(endpointId);
  }
}
