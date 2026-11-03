import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/device.dart';
import '../models/transfer.dart';
import 'file_handler.dart';

typedef TransferRequestCallback = Future<bool> Function({
  required String sessionId,
  required NearbyDevice sender,
  required List<FileTransfer> files,
});

typedef ProgressCallback = void Function({
  required String sessionId,
  required String fileId,
  required int bytesReceived,
  required int totalBytes,
  required double speed,
});

typedef FileCompletedCallback = void Function({
  required String sessionId,
  required String fileId,
  required String savedPath,
});

typedef TransferFailedCallback = void Function({
  required String sessionId,
  required String fileId,
  required String error,
});

class HttpTransferServer {
  static const int defaultPort = 53318;
  HttpServer? _server;
  NearbyDevice? _localDevice;

  // Active sessions: sessionId -> map of pending file info
  final Map<String, Map<String, FileTransfer>> _activeSessions = {};
  final Map<String, IOSink> _activeSinks = {};

  TransferRequestCallback? onRequestReceived;
  ProgressCallback? onProgress;
  FileCompletedCallback? onFileCompleted;
  TransferFailedCallback? onFileFailed;
  ValueChanged<Map<String, dynamic>>? onPortalEvent;

  int? get port => _server?.port;
  bool get isRunning => _server != null;

  Future<int?> startServer({
    required NearbyDevice localDevice,
    int port = defaultPort,
  }) async {
    _localDevice = localDevice;
    try {
      // Bind to any IPv4 address
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );

      _server!.listen(_handleRequest, onError: (e) {
        debugPrint('[HttpServer] Server error: $e');
      });

      debugPrint('[HttpServer] Running on port ${_server!.port}');
      return _server!.port;
    } catch (e) {
      debugPrint('[HttpServer] Failed to bind to port $port, trying ephemeral port...: $e');
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, 0, shared: true);
        _server!.listen(_handleRequest);
        debugPrint('[HttpServer] Running on fallback port ${_server!.port}');
        return _server!.port;
      } catch (e2) {
        debugPrint('[HttpServer] Critical server start error: $e2');
        return null;
      }
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // Enable CORS for flexibility
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    // Fast-path for Live Edge Portal WebSocket stream
    if (path == '/api/v1/portal/stream' && WebSocketTransformer.isUpgradeRequest(request)) {
      try {
        final socket = await WebSocketTransformer.upgrade(request);
        _handlePortalSocket(socket);
        return;
      } catch (e) {
        debugPrint('[HttpServer] WebSocket upgrade failed: $e');
        return;
      }
    }

    try {
      if (path == '/api/v1/info' && request.method == 'GET') {
        await _handleInfo(request);
      } else if (path == '/api/v1/prepare' && request.method == 'POST') {
        await _handlePrepare(request);
      } else if (path == '/api/v1/upload' && request.method == 'POST') {
        await _handleUpload(request);
      } else if (path == '/api/v1/cancel' && request.method == 'POST') {
        await _handleCancel(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not Found');
        await request.response.close();
      }
    } catch (e, stack) {
      debugPrint('[HttpServer] Error handling request $path: $e\n$stack');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write(jsonEncode({'error': e.toString()}));
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleInfo(HttpRequest request) async {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'id': _localDevice?.id ?? '',
      'name': _localDevice?.name ?? 'SendSnap Device',
      'port': _server?.port ?? defaultPort,
      'protocol': 'sendsnap-v1',
    }));
    await request.response.close();
  }

  Future<void> _handlePrepare(HttpRequest request) async {
    final body = await utf8.decodeStream(request);
    final data = jsonDecode(body) as Map<String, dynamic>;

    final sessionId = data['sessionId'] as String;
    final senderJson = data['sender'] as Map<String, dynamic>;
    final filesJson = data['files'] as List<dynamic>;

    final sender = NearbyDevice.fromJson(senderJson);
    final files = filesJson.map((f) {
      return FileTransfer(
        id: f['id'] as String,
        fileName: f['name'] as String,
        fileSize: f['size'] as int,
        status: TransferStatus.pending,
      );
    }).toList();

    _activeSessions[sessionId] = {
      for (var f in files) f.id: f,
    };

    bool accepted = true;
    if (onRequestReceived != null) {
      accepted = await onRequestReceived!(
        sessionId: sessionId,
        sender: sender,
        files: files,
      );
    }

    request.response.headers.contentType = ContentType.json;
    if (accepted) {
      request.response.statusCode = HttpStatus.ok;
      request.response.write(jsonEncode({
        'status': 'accepted',
        'sessionId': sessionId,
      }));
    } else {
      request.response.statusCode = HttpStatus.forbidden;
      request.response.write(jsonEncode({
        'status': 'rejected',
        'sessionId': sessionId,
      }));
      _activeSessions.remove(sessionId);
    }
    await request.response.close();
  }

  Future<void> _handleUpload(HttpRequest request) async {
    final sessionId = request.uri.queryParameters['sessionId'];
    final fileId = request.uri.queryParameters['fileId'];

    if (sessionId == null || fileId == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'error': 'Missing sessionId or fileId'}));
      await request.response.close();
      return;
    }

    final sessionFiles = _activeSessions[sessionId];
    final fileInfo = sessionFiles?[fileId];
    if (fileInfo == null) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write(jsonEncode({'error': 'Transfer not registered'}));
      await request.response.close();
      return;
    }

    final tempDir = Directory.systemTemp;
    final tempFilePath = p.join(tempDir.path, 'recv_${fileId}_${fileInfo.fileName}');
    final tempFile = File(tempFilePath);
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    final sink = tempFile.openWrite();
    final sinkKey = '$sessionId-$fileId';
    _activeSinks[sinkKey] = sink;

    int bytesReceived = 0;
    final totalBytes = fileInfo.fileSize;
    final stopwatch = Stopwatch()..start();
    DateTime lastProgressUpdate = DateTime.now();

    try {
      await for (final chunk in request) {
        sink.add(chunk);
        bytesReceived += chunk.length;

        final now = DateTime.now();
        if (now.difference(lastProgressUpdate).inMilliseconds >= 100 ||
            bytesReceived == totalBytes) {
          lastProgressUpdate = now;
          final elapsedSeconds = stopwatch.elapsedMilliseconds / 1000.0;
          final speed = elapsedSeconds > 0 ? (bytesReceived / elapsedSeconds) : 0.0;

          onProgress?.call(
            sessionId: sessionId,
            fileId: fileId,
            bytesReceived: bytesReceived,
            totalBytes: totalBytes,
            speed: speed,
          );
        }
      }

      await sink.flush();
      await sink.close();
      _activeSinks.remove(sinkKey);

      // Move completed file to safe downloads directory
      final savedFile = await FileHandler.moveFileToDownloads(tempFilePath, fileInfo.fileName);
      final finalPath = savedFile?.path ?? tempFilePath;

      onFileCompleted?.call(
        sessionId: sessionId,
        fileId: fileId,
        savedPath: finalPath,
      );

      request.response.headers.contentType = ContentType.json;
      request.response.statusCode = HttpStatus.ok;
      request.response.write(jsonEncode({
        'status': 'completed',
        'fileId': fileId,
        'savedPath': finalPath,
      }));
      await request.response.close();
    } catch (e) {
      debugPrint('[HttpServer] Upload stream error: $e');
      _activeSinks.remove(sinkKey);
      try {
        await sink.close();
      } catch (_) {}
      try {
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}

      onFileFailed?.call(
        sessionId: sessionId,
        fileId: fileId,
        error: e.toString(),
      );

      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(jsonEncode({'error': e.toString()}));
      await request.response.close();
    }
  }

  Future<void> _handleCancel(HttpRequest request) async {
    final sessionId = request.uri.queryParameters['sessionId'];
    if (sessionId != null) {
      // Close any active write sinks for this session
      final keysToCancel = _activeSinks.keys.where((k) => k.startsWith(sessionId)).toList();
      for (final key in keysToCancel) {
        try {
          await _activeSinks[key]?.close();
        } catch (_) {}
        _activeSinks.remove(key);
      }
      _activeSessions.remove(sessionId);
    }
    request.response.statusCode = HttpStatus.ok;
    request.response.write(jsonEncode({'status': 'cancelled'}));
    await request.response.close();
  }

  void _handlePortalSocket(WebSocket socket) {
    socket.listen(
      (data) {
        try {
          final json = jsonDecode(data.toString()) as Map<String, dynamic>;
          onPortalEvent?.call(json);
        } catch (e) {
          debugPrint('[HttpServer] Portal socket parse error: $e');
        }
      },
      onDone: () {
        onPortalEvent?.call({'type': 'DRAG_CANCEL'});
      },
      onError: (err) {
        onPortalEvent?.call({'type': 'DRAG_CANCEL'});
      },
      cancelOnError: true,
    );
  }

  Future<void> stopServer() async {
    for (final sink in _activeSinks.values) {
      try {
        await sink.close();
      } catch (_) {}
    }
    _activeSinks.clear();
    _activeSessions.clear();

    try {
      await _server?.close(force: true);
      _server = null;
    } catch (_) {}
    debugPrint('[HttpServer] Server stopped');
  }
}
