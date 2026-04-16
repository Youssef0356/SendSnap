import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../models/device.dart';
import '../models/transfer_file.dart';

class WifiDirectService {
  final _host = FlutterP2pHost();
  final _client = FlutterP2pClient();
  bool _isHostMode = false, _isClientMode = false, _initialized = false, _groupCreated = false, _paused = false;
  bool _isConnected = false;
  String _deviceName = 'SendSnap Device';

  final Map<String, NearbyDevice> _discovered = {};
  final Map<String, BleDiscoveredDevice> _bleDevices = {};
  final _devicesCtrl = StreamController<List<NearbyDevice>>.broadcast();
  final _connectionCtrl = StreamController<bool>.broadcast();

  Function(IncomingRequest)? onIncomingRequest;
  Function(TransferSession)? onTransferUpdate;
  Function(String)? onError;
  Function()? onTransferComplete;
  TransferSession? _session;

  Stream<bool> get connectionStream => _connectionCtrl.stream;
  bool get isConnected => _isConnected;

  Stream<List<NearbyDevice>> get devicesStream => _devicesCtrl.stream;
  List<NearbyDevice> get discoveredDevices => _discovered.values.toList();
  bool get isHostMode => _isHostMode;
  bool get isGroupCreated => _groupCreated;
  bool get isPaused => _paused;

  Future<bool> _init() async {
    if (_initialized) {
      debugPrint('[SS] _init: Already initialized');
      return true;
    }
    try {
      debugPrint('[SS] _init: Starting initialization (${_isHostMode ? "host" : "client"})...');
      if (_isHostMode) {
        debugPrint('[SS] _init: Calling _host.initialize()...');
        await _host.initialize();
        debugPrint('[SS] _init: _host.initialize() completed');
      } else {
        debugPrint('[SS] _init: Calling _client.initialize()...');
        await _client.initialize();
        debugPrint('[SS] _init: _client.initialize() completed');
      }
      _initialized = true;
      debugPrint('[SS] _init: SUCCESS');
      return true;
    } catch (e, st) {
      debugPrint('[SS] _init: ERROR - $e');
      debugPrint('[SS] _init: Stack - $st');
      return false;
    }
  }

  Future<bool> requestPermissions() async {
    try {
      debugPrint('[SS] Requesting permissions...');

      // Location (required for WiFi Direct)
      var status = await Permission.location.request();
      debugPrint('[SS] Location: $status');
      if (!status.isGranted) return false;

      // Nearby WiFi Devices (Android 12+)
      status = await Permission.nearbyWifiDevices.request();
      debugPrint('[SS] Nearby WiFi: $status');

      // Bluetooth (for BLE discovery)
      status = await Permission.bluetooth.request();
      debugPrint('[SS] Bluetooth: $status');

      status = await Permission.bluetoothScan.request();
      debugPrint('[SS] BT Scan: $status');

      status = await Permission.bluetoothAdvertise.request();
      debugPrint('[SS] BT Advertise: $status');

      status = await Permission.bluetoothConnect.request();
      debugPrint('[SS] BT Connect: $status');

      // Storage
      status = await Permission.storage.request();
      debugPrint('[SS] Storage: $status');

      // Manage external storage for Android 11+
      if (Platform.isAndroid) {
        status = await Permission.manageExternalStorage.request();
        debugPrint('[SS] Manage Ext Storage: $status');
      }

      return true;
    } catch (e) {
      debugPrint('[SS] perm err: $e');
      return false;
    }
  }

  Future<bool> enableServices() async {
    try {
      debugPrint('[SS] Enabling services...');
      final p = _isHostMode ? _host : _client;

      if (!await p.checkWifiEnabled()) {
        debugPrint('[SS] Enabling WiFi...');
        await p.enableWifiServices();
      }

      if (!await p.checkLocationEnabled()) {
        debugPrint('[SS] Enabling Location...');
        await p.enableLocationServices();
      }

      if (!await p.checkBluetoothEnabled()) {
        debugPrint('[SS] Enabling Bluetooth...');
        await p.enableBluetoothServices();
      }

      debugPrint('[SS] Services enabled');
      return true;
    } catch (e) {
      debugPrint('[SS] enable services err: $e');
      return false;
    }
  }

  // ─── HOST (RECEIVER) ───

  Future<void> startHostMode(String deviceName) async {
    debugPrint('[SS] === Starting Host Mode ===');
    debugPrint('[SS] Device name: $deviceName');
    _isHostMode = true;
    _isClientMode = false;
    _deviceName = deviceName;

    final perms = await requestPermissions();
    if (!perms) {
      debugPrint('[SS] ERROR: Permissions denied!');
      onError?.call('Permissions required');
      return;
    }
    debugPrint('[SS] Permissions granted');

    final inited = await _init();
    if (!inited) {
      debugPrint('[SS] ERROR: _init() failed');
      return;
    }
    
    final enabled = await enableServices();
    if (!enabled) {
      debugPrint('[SS] ERROR: enableServices() failed');
      return;
    }
    
    _listenHost();
    debugPrint('[SS] Host mode ready - waiting for createGroup()');
  }

  Future<bool> createGroup() async {
    try {
      debugPrint('[SS] Creating WiFi Direct group...');
      final s = await _host.createGroup(advertise: true);
      _groupCreated = s != null;
      debugPrint('[SS] Group created: $_groupCreated');
      return _groupCreated;
    } catch (e) {
      debugPrint('[SS] group err: $e');
      return false;
    }
  }

  Future<void> removeGroup() async {
    try {
      debugPrint('[SS] Removing group...');
      await _host.removeGroup();
      _groupCreated = false;
    } catch (_) {}
  }

  void _listenHost() {
    debugPrint('[SS] Starting host listeners...');
    _host.streamHotspotState().listen((state) {
      debugPrint('[SS] Host hotspot state: active=${state.isActive}, ssid=${state.ssid}');
      if (state.isActive) {
        _isConnected = true;
        _connectionCtrl.add(true);
      }
    });
    _host.streamClientList().listen((clients) {
      debugPrint('[SS] Host clients: ${clients.length}');
      if (clients.isNotEmpty) {
        _isConnected = true;
        _connectionCtrl.add(true);
      }
    });
    _host.streamReceivedTexts().listen((t) {
      debugPrint('[SS] Host received text: $t');
      _onText(t, true);
    });
    _host.streamReceivedFilesInfo().listen((f) {
      debugPrint('[SS] Host received files info: ${f.length}');
      _onReceivable(f, true);
    });
  }

  // ─── CLIENT (SENDER) ───

  Future<void> startClientMode() async {
    debugPrint('[SS] === Starting Client Mode ===');
    _isClientMode = true;
    _isHostMode = false;

    final perms = await requestPermissions();
    if (!perms) {
      debugPrint('[SS] ERROR: Permissions denied!');
      onError?.call('Permissions required');
      return;
    }
    debugPrint('[SS] Permissions granted');

    final inited = await _init();
    if (!inited) {
      debugPrint('[SS] ERROR: _init() failed');
      return;
    }
    
    final enabled = await enableServices();
    if (!enabled) {
      debugPrint('[SS] ERROR: enableServices() failed');
      return;
    }
    
    _listenClient();
    debugPrint('[SS] Client mode ready - call startScan() to discover devices');
  }

  Future<void> startScan() async {
    try {
      debugPrint('[SS] === Starting BLE Scan ===');
      _discovered.clear();
      _bleDevices.clear();
      _devicesCtrl.add([]);
      
      debugPrint('[SS] Calling _client.startScan...');
      await _client.startScan((List<BleDiscoveredDevice> devices) {
        debugPrint('[SS] Scan callback: ${devices.length} devices');

        for (final d in devices) {
          debugPrint('[SS] Device: name=${d.deviceName}, address=${d.deviceAddress}');

          // Use MAC address as ID
          final id = d.deviceAddress;
          final name = d.deviceName.isNotEmpty ? d.deviceName : 'SendSnap Device';

          _bleDevices[id] = d;
          _discovered[id] = NearbyDevice(
            id: id,
            name: name,
            ip: '',
            port: 0,
            status: DeviceStatus.ready,
          );
        }

        _devicesCtrl.add(_discovered.values.toList());
        debugPrint('[SS] Discovered: ${_discovered.length} devices');
      });

      debugPrint('[SS] Scan started');
    } catch (e, st) {
      debugPrint('[SS] scan err: $e');
      debugPrint('[SS] stack: $st');
      onError?.call('Scan failed: $e');
    }
  }

  Future<void> stopScan() async {
    try {
      debugPrint('[SS] Stopping scan...');
      await _client.stopScan();
    } catch (_) {}
  }

  Future<bool> connectToDevice(NearbyDevice d) async {
    try {
      debugPrint('[SS] === Starting connection to ${d.name} ===');
      debugPrint('[SS] Device ID: ${d.id}');
      
      // Get the BleDiscoveredDevice from our map
      final bleDevice = _bleDevices[d.id];
      if (bleDevice == null) {
        debugPrint('[SS] ERROR: BLE device not found in map!');
        debugPrint('[SS] Available devices: ${_bleDevices.keys.join(', ')}');
        return false;
      }
      
      debugPrint('[SS] Found BLE device: ${bleDevice.deviceName} @ ${bleDevice.deviceAddress}');
      
      // Connect using the BleDiscoveredDevice
      debugPrint('[SS] Calling _client.connectWithDevice...');
      await _client.connectWithDevice(bleDevice);
      debugPrint('[SS] connectWithDevice completed successfully');
      
      // Wait a moment for connection to stabilize
      debugPrint('[SS] Waiting for connection to stabilize...');
      await Future.delayed(const Duration(seconds: 2));
      
      // Check if we're connected by listening to hotspot state
      debugPrint('[SS] Checking connection state...');
      try {
        await for (final state in _client.streamHotspotState().timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) {
            debugPrint('[SS] WARNING: Timeout waiting for hotspot state');
            sink.close();
          },
        )) {
          debugPrint('[SS] Hotspot state: active=${state.isActive}, ssid=${state.hostSsid}');
          if (state.isActive) {
            _isConnected = true;
            _connectionCtrl.add(true);
            debugPrint('[SS] Connection confirmed active!');
            break;
          }
        }
      } catch (e) {
        debugPrint('[SS] Error checking hotspot state: $e');
      }
      
      return true;
    } catch (e, st) {
      debugPrint('[SS] === CONNECT ERROR ===');
      debugPrint('[SS] Error: $e');
      debugPrint('[SS] Stack: $st');
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      debugPrint('[SS] Disconnecting...');
      await _client.disconnect();
    } catch (_) {}
  }

  void _listenClient() {
    debugPrint('[SS] Starting client listeners...');
    _client.streamHotspotState().listen((state) {
      debugPrint('[SS] Client hotspot state: active=${state.isActive}, ssid=${state.hostSsid}');
      if (state.isActive) {
        _isConnected = true;
        _connectionCtrl.add(true);
      }
    });
    _client.streamReceivedTexts().listen((t) {
      debugPrint('[SS] Client received text: $t');
      _onText(t, false);
    });
    _client.streamSentFilesInfo().listen((f) {
      debugPrint('[SS] Client sent files: ${f.length}');
      _onSentFiles(f);
    });
    _client.streamReceivedFilesInfo().listen((f) {
      debugPrint('[SS] Client received files: ${f.length}');
      _onReceivable(f, false);
    });
  }

  // ─── TEXT PROTOCOL ───

  void _onText(String text, bool isHost) {
    debugPrint('[SS] onText: $text (host=$isHost)');
    if (text.startsWith('HEADER:')) {
      try {
        final data = jsonDecode(text.substring(7)) as Map<String, dynamic>;
        final files = (data['files'] as List)
            .map((f) => TransferFile.fromJson(f as Map<String, dynamic>))
            .toList();
        final senderName = data['sender'] as String? ?? 'Unknown';
        final senderId = data['sender_id'] as String? ?? '';

        debugPrint('[SS] Incoming request from $senderName ($senderId) with ${files.length} files');
        
        onIncomingRequest?.call(IncomingRequest(
          senderName: senderName,
          senderIp: senderId,
          senderPort: 0,
          files: files,
        ));
      } catch (e) {
        debugPrint('[SS] Header parse err: $e');
      }
    } else if (text == 'ACCEPT') {
      debugPrint('[SS] Transfer accepted by receiver');
      _sendFiles();
    } else if (text == 'REJECT') {
      debugPrint('[SS] Transfer rejected by receiver');
      _emit(_session?.copyWith(
          status: TransferSessionStatus.cancelled,
          errorMessage: 'The receiver declined your request.'));
      onError?.call('Transfer declined');
    }
  }

  // ─── SEND ───

  Future<void> sendFiles({
    required NearbyDevice target,
    required List<TransferFile> files,
    required String senderName,
  }) async {
    debugPrint('[SS] Sending files to ${target.name}...');
    _session = TransferSession(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      targetDevice: target,
      files: files,
      direction: TransferDirection.sending,
      status: TransferSessionStatus.waitingForAccept,
    );
    _emit(_session);
    _paused = false;

    // Wait for connection to be established
    if (!_isConnected) {
      debugPrint('[SS] Waiting for connection...');
      try {
        await _connectionCtrl.stream.firstWhere((connected) => connected).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            debugPrint('[SS] Connection timeout');
            onError?.call('Connection timeout - could not establish P2P connection');
            return false;
          },
        );
      } catch (e) {
        debugPrint('[SS] Failed to wait for connection: $e');
        onError?.call('Failed to establish connection: $e');
        return;
      }
    }

    debugPrint('[SS] Connection ready, sending HEADER...');
    
    // 1. Send metadata header
    final header = {
      'sender': senderName,
      'sender_id': _deviceName, // Use own device name as ID for now
      'files': files.map((f) => f.toJson()).toList(),
    };
    
    try {
      final headerJson = 'HEADER:${jsonEncode(header)}';
      await (_isClientMode ? _client.broadcastText(headerJson) : _host.broadcastText(headerJson));
      debugPrint('[SS] HEADER sent, waiting for ACCEPT...');
    } catch (e) {
      debugPrint('[SS] Failed to send header: $e');
      onError?.call('Failed to initiate transfer: $e');
    }
  }

  void _sendFiles() async {
    if (_session == null) return;
    debugPrint('[SS] Starting file transfer...');
    _session = _session!.copyWith(status: TransferSessionStatus.transferring);
    _emit(_session);

    for (int i = 0; i < _session!.files.length; i++) {
      if (_paused) {
        while (_paused) await Future.delayed(const Duration(milliseconds: 200));
      }

      final f = _session!.files[i];
      final file = File(f.path);
      if (!await file.exists()) {
        _updateFile(i, FileTransferStatus.failed);
        continue;
      }

      try {
        debugPrint('[SS] Sending file ${f.name}...');
        await (_isClientMode ? _client.broadcastFile(file) : _host.broadcastFile(file));
        _updateFile(i, FileTransferStatus.completed, 1.0);
        debugPrint('[SS] File sent');
      } catch (e) {
        debugPrint('[SS] Send file err: $e');
        _updateFile(i, FileTransferStatus.failed);
      }
    }

    _session = _session!.copyWith(
        overallProgress: 1.0, status: TransferSessionStatus.completed);
    _emit(_session);
    onTransferComplete?.call();
    debugPrint('[SS] Transfer complete');
  }

  void _updateFile(int i, FileTransferStatus s, [double p = 0.0]) {
    if (_session == null) return;
    final files = List<TransferFile>.from(_session!.files);
    files[i] = files[i].copyWith(status: s, progress: p);
    _session = _session!.copyWith(files: files);
    _emit(_session);
  }

  // ─── RECEIVE ───

  void _onReceivable(List<dynamic> files, bool isHost) {
    debugPrint('[SS] Receivable files: ${files.length}');
    if (files.isEmpty) return;
    
    // Check if we have an active session for receiving
    if (_session == null || _session!.direction != TransferDirection.receiving) {
      debugPrint('[SS] No active receiving session, ignoring files');
      // In some cases we might want to auto-create a session if we missed the HEADER,
      // but for now we follow the protocol.
      return;
    }

    for (final f in files) {
      try {
        debugPrint('[SS] Processing file object: ${f.runtimeType}');
        
        // Extract file info using dynamic access (flutter_p2p_connection's TransferFileInfo)
        final String? fileId = (f as dynamic).id?.toString();
        final String fileName = (f as dynamic).name?.toString() ?? 'unknown';
        
        if (fileId == null) {
          debugPrint('[SS] File ID is null, skipping');
          continue;
        }
        
        // Check if this file is already being transferred or completed
        final fileIndex = _session!.files.indexWhere((tf) => tf.name == fileName);
        if (fileIndex != -1) {
          final tf = _session!.files[fileIndex];
          if (tf.status == FileTransferStatus.completed || tf.status == FileTransferStatus.transferring) {
            debugPrint('[SS] File $fileName already in progress or done');
            continue;
          }
          
          debugPrint('[SS] Starting download for: $fileName (ID: $fileId)');
          _downloadFileById(fileId, fileName, fileIndex);
        } else {
          // File not in session metadata, but we should probably download it anyway
          debugPrint('[SS] File $fileName not in session metadata, auto-downloading...');
          _downloadFileById(fileId, fileName, -1);
        }
      } catch (e, st) {
        debugPrint('[SS] Error processing receivable file: $e');
        debugPrint('[SS] Stack: $st');
      }
    }
  }

  Future<void> _downloadFileById(String fileId, String fileName, int sessionIndex) async {
    try {
      debugPrint('[SS] Downloading file $fileName (ID: $fileId)...');
      
      if (sessionIndex != -1) {
        _updateFile(sessionIndex, FileTransferStatus.transferring, 0.1);
      }
      
      final dir = await _saveDir();
      final savePath = '${dir.path}/$fileName';
      
      final success = await (_isHostMode
          ? _host.downloadFile(fileId, savePath)
          : _client.downloadFile(fileId, savePath));
      
      if (success) {
        debugPrint('[SS] Download complete: $savePath');
        if (sessionIndex != -1) {
          _updateFile(sessionIndex, FileTransferStatus.completed, 1.0);
          
          // Check if all files are done
          final allDone = _session!.files.every((f) => f.status == FileTransferStatus.completed);
          if (allDone) {
             _session = _session!.copyWith(status: TransferSessionStatus.completed, overallProgress: 1.0);
             _emit(_session);
             onTransferComplete?.call();
          }
        }
      } else {
        debugPrint('[SS] Download failed for $fileName');
        if (sessionIndex != -1) {
          _updateFile(sessionIndex, FileTransferStatus.failed);
        }
      }
    } catch (e) {
      debugPrint('[SS] Download error: $e');
      if (sessionIndex != -1) {
        _updateFile(sessionIndex, FileTransferStatus.failed);
      }
    }
  }

  Future<void> _download(String fileId) async {
    try {
      debugPrint('[SS] Downloading file...');
      final dir = await _saveDir();
      await (_isHostMode
          ? _host.downloadFile(fileId, dir.path)
          : _client.downloadFile(fileId, dir.path));
      debugPrint('[SS] Download complete');
    } catch (e) {
      debugPrint('[SS] download err: $e');
    }
  }

  void _onSentFiles(List files) {
    if (_session == null) return;
    debugPrint('[SS] Sent files update: ${files.length}');
    
    final updated = List<TransferFile>.from(_session!.files);
    for (int i = 0; i < updated.length; i++) {
      final f = updated[i];
      if (f.status == FileTransferStatus.completed) continue;
      
      // Since flutter_p2p_connection doesn't provide precise mapping,
      // we mark all in-progress files as transferring
      updated[i] = f.copyWith(
        status: FileTransferStatus.transferring,
        progress: 0.5, // Mock halfway progress as we don't have real updates
      );
    }
    
    _session = _session!.copyWith(
        files: updated, status: TransferSessionStatus.transferring);
    _emit(_session);
  }

  // ─── ACCEPT / REJECT ───

  Future<void> acceptTransfer(IncomingRequest req) async {
    try {
      debugPrint('[SS] Accepting transfer...');
      await (_isHostMode
          ? _host.broadcastText('ACCEPT')
          : _client.broadcastText('ACCEPT'));
      _session = TransferSession(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        targetDevice: NearbyDevice(
            id: req.senderIp,
            name: req.senderName,
            ip: req.senderIp,
            port: 0,
            status: DeviceStatus.ready),
        files: req.files,
        direction: TransferDirection.receiving,
        status: TransferSessionStatus.transferring,
      );
      _emit(_session);
      debugPrint('[SS] Transfer accepted');
    } catch (e) {
      debugPrint('[SS] Accept err: $e');
      onError?.call('Accept failed: $e');
    }
  }

  void declineTransfer(IncomingRequest req) {
    debugPrint('[SS] Declining transfer...');
    try {
      _isHostMode
          ? _host.broadcastText('REJECT')
          : _client.broadcastText('REJECT');
    } catch (_) {}
  }

  // ─── PAUSE / RESUME / CANCEL ───

  void pauseTransfer() {
    debugPrint('[SS] Pausing transfer');
    _paused = true;
  }

  void resumeTransfer() {
    debugPrint('[SS] Resuming transfer');
    _paused = false;
  }

  void cancelTransfer() {
    debugPrint('[SS] Cancelling transfer');
    _paused = false;
    _emit(_session?.copyWith(status: TransferSessionStatus.cancelled));
  }

  // ─── HELPERS ───

  void _emit(TransferSession? s) {
    if (s != null) onTransferUpdate?.call(s);
  }

  Future<Directory> _saveDir() async {
    Directory? d;
    if (Platform.isAndroid) {
      try {
        final dl = await getExternalStorageDirectories(
            type: StorageDirectory.downloads);
        if (dl?.isNotEmpty ?? false) d = Directory('${dl!.first.path}/SendSnap');
      } catch (_) {}
      d ??= Directory('/storage/emulated/0/Download/SendSnap');
    } else {
      d = Directory(
          '${(await getApplicationDocumentsDirectory()).path}/SendSnap');
    }
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<void> dispose() async {
    debugPrint('[SS] Disposing...');
    if (_isHostMode) {
      await removeGroup();
      _host.dispose();
    }
    if (_isClientMode) {
      await stopScan();
      await disconnect();
      _client.dispose();
    }
    _initialized = false;
    _isHostMode = false;
    _isClientMode = false;
    _isConnected = false;
    _discovered.clear();
    _bleDevices.clear();
    if (!_devicesCtrl.isClosed) await _devicesCtrl.close();
    if (!_connectionCtrl.isClosed) await _connectionCtrl.close();
    debugPrint('[SS] Disposed');
  }
}
