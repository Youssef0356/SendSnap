import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/device.dart';
import '../models/transfer_file.dart';

/// Handles peer-to-peer file transfer over TCP sockets.
/// Sender connects to receiver's server, sends metadata, waits for accept,
/// then streams file bytes. Receiver listens for incoming connections.
class TransferService {
  ServerSocket? _serverSocket;
  Socket? _activeSocket;
  bool _isListening = false;
  int _serverPort = 0;

  // Callbacks
  Function(IncomingRequest)? onIncomingRequest;
  Function(TransferSession)? onTransferUpdate;
  Function(String)? onError;
  Function()? onTransferComplete;

  bool get isListening => _isListening;
  int get serverPort => _serverPort;

  // ─── RECEIVER SIDE ───

  /// Start TCP server to listen for incoming file transfers.
  Future<int> startServer() async {
    if (_isListening) return _serverPort;

    try {
      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        0, // OS assigns a free port
      );
      _serverPort = _serverSocket!.port;
      _isListening = true;
      debugPrint('[SendSnap] TCP server listening on port $_serverPort');

      _serverSocket!.listen(
        _handleIncomingConnection,
        onError: (e) {
          debugPrint('[SendSnap] Server error: $e');
          onError?.call('Server error: $e');
        },
      );

      return _serverPort;
    } catch (e) {
      debugPrint('[SendSnap] Failed to start server: $e');
      rethrow;
    }
  }

  void _handleIncomingConnection(Socket socket) async {
    debugPrint('[SendSnap] Incoming connection from ${socket.remoteAddress.address}:${socket.remotePort}');

    try {
      // Read the metadata header (first message)
      final completer = Completer<String>();
      final buffer = StringBuffer();

      late StreamSubscription subscription;
      subscription = socket.listen(
        (data) {
          buffer.write(utf8.decode(data));
          final content = buffer.toString();
          // Look for header terminator
          if (content.contains('\n---END_HEADER---\n')) {
            subscription.cancel();
            final headerStr = content.split('\n---END_HEADER---\n').first;
            completer.complete(headerStr);
          }
        },
        onError: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        cancelOnError: true,
      );

      // Wait for the header with timeout
      final headerJson = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          socket.destroy();
          throw TimeoutException('Header timeout');
        },
      );

      final metadata = jsonDecode(headerJson) as Map<String, dynamic>;
      final senderName = metadata['sender'] as String;
      final filesJson = metadata['files'] as List;
      final files = filesJson
          .map((f) => TransferFile.fromJson(f as Map<String, dynamic>))
          .toList();

      final request = IncomingRequest(
        senderName: senderName,
        senderIp: socket.remoteAddress.address,
        senderPort: socket.remotePort,
        files: files,
        socket: socket,
      );

      onIncomingRequest?.call(request);
    } catch (e) {
      debugPrint('[SendSnap] Error handling connection: $e');
      socket.destroy();
    }
  }

  /// Accept an incoming file transfer request.
  Future<void> acceptTransfer(IncomingRequest request) async {
    final socket = request.socket as Socket;

    try {
      // Send acceptance signal
      socket.write('ACCEPT\n');
      await socket.flush();
      debugPrint('[SendSnap] Accepted transfer from ${request.senderName}');

      // Prepare save directory
      final saveDir = await _getSaveDirectory();

      // Receive files one by one
      final files = List<TransferFile>.from(request.files);
      int totalReceived = 0;
      final totalSize = request.totalSize;

      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        files[i] = file.copyWith(status: FileTransferStatus.transferring);

        _emitUpdate(TransferSession(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          targetDevice: NearbyDevice(
            id: request.senderIp,
            name: request.senderName,
            ip: request.senderIp,
            port: request.senderPort,
          ),
          files: List.from(files),
          direction: TransferDirection.receiving,
          overallProgress: totalReceived / totalSize,
          status: TransferSessionStatus.transferring,
        ));

        final savePath = '${saveDir.path}/${file.name}';
        final outputFile = File(savePath);
        final sink = outputFile.openWrite();

        int fileReceived = 0;
        final fileCompleter = Completer<void>();
        DateTime lastSpeedUpdate = DateTime.now();
        int lastSpeedBytes = 0;
        double currentSpeed = 0;

        late StreamSubscription fileSub;
        fileSub = socket.listen(
          (data) {
            // Check for file separator
            final str = utf8.decode(data, allowMalformed: true);
            if (str.contains('\n---FILE_END---\n')) {
              final parts = str.split('\n---FILE_END---\n');
              if (parts.first.isNotEmpty) {
                final remaining = utf8.encode(parts.first);
                sink.add(remaining);
                fileReceived += remaining.length;
              }
              fileSub.cancel();
              if (!fileCompleter.isCompleted) fileCompleter.complete();
              return;
            }

            sink.add(data);
            fileReceived += data.length;
            totalReceived += data.length;

            // Calculate speed every 500ms
            final now = DateTime.now();
            if (now.difference(lastSpeedUpdate).inMilliseconds >= 500) {
              currentSpeed = (fileReceived - lastSpeedBytes) /
                  now.difference(lastSpeedUpdate).inMilliseconds *
                  1000;
              lastSpeedBytes = fileReceived;
              lastSpeedUpdate = now;
            }

            files[i] = file.copyWith(
              status: FileTransferStatus.transferring,
              progress: fileReceived / file.size,
            );

            final remainingBytes = totalSize - totalReceived;
            final eta = currentSpeed > 0
                ? Duration(seconds: (remainingBytes / currentSpeed).round())
                : null;

            _emitUpdate(TransferSession(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              targetDevice: NearbyDevice(
                id: request.senderIp,
                name: request.senderName,
                ip: request.senderIp,
                port: request.senderPort,
              ),
              files: List.from(files),
              direction: TransferDirection.receiving,
              overallProgress: totalReceived / totalSize,
              speed: currentSpeed,
              timeRemaining: eta,
              status: TransferSessionStatus.transferring,
            ));
          },
          onError: (e) {
            if (!fileCompleter.isCompleted) {
              fileCompleter.completeError(e);
            }
          },
          cancelOnError: true,
        );

        await fileCompleter.future;
        await sink.close();

        files[i] = file.copyWith(
          status: FileTransferStatus.completed,
          progress: 1.0,
          path: savePath,
        );
      }

      // All done
      _emitUpdate(TransferSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        targetDevice: NearbyDevice(
          id: request.senderIp,
          name: request.senderName,
          ip: request.senderIp,
          port: request.senderPort,
        ),
        files: List.from(files),
        direction: TransferDirection.receiving,
        overallProgress: 1.0,
        status: TransferSessionStatus.completed,
      ));

      onTransferComplete?.call();
      socket.destroy();
    } catch (e) {
      debugPrint('[SendSnap] Transfer receive error: $e');
      onError?.call('Transfer failed: $e');
      socket.destroy();
    }
  }

  /// Decline an incoming file transfer request.
  void declineTransfer(IncomingRequest request) {
    final socket = request.socket as Socket;
    try {
      socket.write('REJECT\n');
      socket.flush().then((_) => socket.destroy());
      debugPrint('[SendSnap] Declined transfer from ${request.senderName}');
    } catch (e) {
      socket.destroy();
    }
  }

  // ─── SENDER SIDE ───

  /// Send files to a target device.
  Future<void> sendFiles({
    required NearbyDevice target,
    required List<TransferFile> files,
    required String senderName,
  }) async {
    try {
      debugPrint('[SendSnap] Connecting to ${target.ip}:${target.port}');
      _activeSocket = await Socket.connect(
        target.ip,
        target.port,
        timeout: const Duration(seconds: 10),
      );

      // Send metadata header
      final metadata = {
        'sender': senderName,
        'files': files.map((f) => f.toJson()).toList(),
      };
      _activeSocket!.write('${jsonEncode(metadata)}\n---END_HEADER---\n');
      await _activeSocket!.flush();

      // Emit waiting state
      _emitUpdate(TransferSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        targetDevice: target,
        files: files,
        direction: TransferDirection.sending,
        status: TransferSessionStatus.waitingForAccept,
      ));

      // Wait for accept/reject
      final responseCompleter = Completer<String>();
      final responseBuf = StringBuffer();

      late StreamSubscription responseSub;
      responseSub = _activeSocket!.listen(
        (data) {
          responseBuf.write(utf8.decode(data));
          final content = responseBuf.toString();
          if (content.contains('\n')) {
            responseSub.cancel();
            responseCompleter.complete(content.trim());
          }
        },
        onError: (e) {
          if (!responseCompleter.isCompleted) {
            responseCompleter.completeError(e);
          }
        },
        cancelOnError: true,
      );

      final response = await responseCompleter.future.timeout(
        const Duration(seconds: 35),
        onTimeout: () {
          _activeSocket?.destroy();
          throw TimeoutException('No response from receiver');
        },
      );

      if (response != 'ACCEPT') {
        debugPrint('[SendSnap] Transfer rejected by ${target.name}');
        _emitUpdate(TransferSession(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          targetDevice: target,
          files: files,
          direction: TransferDirection.sending,
          status: TransferSessionStatus.cancelled,
          errorMessage: 'Request declined by ${target.name}',
        ));
        _activeSocket?.destroy();
        return;
      }

      debugPrint('[SendSnap] Transfer accepted, starting send');

      // Send files one by one
      final mutableFiles = List<TransferFile>.from(files);
      int totalSent = 0;
      final totalSize = files.fold<int>(0, (sum, f) => sum + f.size);
      DateTime lastSpeedUpdate = DateTime.now();
      int lastSpeedBytes = 0;
      double currentSpeed = 0;

      for (int i = 0; i < mutableFiles.length; i++) {
        final file = mutableFiles[i];
        mutableFiles[i] = file.copyWith(status: FileTransferStatus.transferring);

        final inputFile = File(file.path);
        if (!await inputFile.exists()) {
          mutableFiles[i] = file.copyWith(status: FileTransferStatus.failed);
          onError?.call('File not found: ${file.name}');
          continue;
        }

        int fileSent = 0;
        await for (final chunk in inputFile.openRead()) {
          _activeSocket!.add(chunk);
          fileSent += chunk.length;
          totalSent += chunk.length;

          // Calculate speed
          final now = DateTime.now();
          if (now.difference(lastSpeedUpdate).inMilliseconds >= 500) {
            currentSpeed = (totalSent - lastSpeedBytes) /
                now.difference(lastSpeedUpdate).inMilliseconds *
                1000;
            lastSpeedBytes = totalSent;
            lastSpeedUpdate = now;
          }

          mutableFiles[i] = file.copyWith(
            status: FileTransferStatus.transferring,
            progress: fileSent / file.size,
          );

          final remainingBytes = totalSize - totalSent;
          final eta = currentSpeed > 0
              ? Duration(seconds: (remainingBytes / currentSpeed).round())
              : null;

          _emitUpdate(TransferSession(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            targetDevice: target,
            files: List.from(mutableFiles),
            direction: TransferDirection.sending,
            overallProgress: totalSent / totalSize,
            speed: currentSpeed,
            timeRemaining: eta,
            status: TransferSessionStatus.transferring,
          ));
        }

        // Send file separator
        _activeSocket!.write('\n---FILE_END---\n');
        await _activeSocket!.flush();

        mutableFiles[i] = file.copyWith(
          status: FileTransferStatus.completed,
          progress: 1.0,
        );
      }

      // All done
      _emitUpdate(TransferSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        targetDevice: target,
        files: List.from(mutableFiles),
        direction: TransferDirection.sending,
        overallProgress: 1.0,
        status: TransferSessionStatus.completed,
      ));

      onTransferComplete?.call();
      await _activeSocket!.flush();
      _activeSocket!.destroy();
      debugPrint('[SendSnap] All files sent successfully');
    } catch (e) {
      debugPrint('[SendSnap] Send error: $e');
      _emitUpdate(TransferSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        targetDevice: target,
        files: files,
        direction: TransferDirection.sending,
        status: TransferSessionStatus.connectionLost,
        errorMessage: e.toString(),
      ));
      _activeSocket?.destroy();
      onError?.call('Transfer failed: $e');
    }
  }

  /// Cancel the active transfer.
  void cancelTransfer() {
    _activeSocket?.destroy();
    _activeSocket = null;
    debugPrint('[SendSnap] Transfer cancelled');
  }

  void _emitUpdate(TransferSession session) {
    onTransferUpdate?.call(session);
  }

  /// Get the save directory for received files.
  Future<Directory> _getSaveDirectory() async {
    Directory? dir;
    if (Platform.isAndroid) {
      // Try Downloads first
      dir = Directory('/storage/emulated/0/Download/SendSnap');
    } else {
      dir = await getApplicationDocumentsDirectory();
      dir = Directory('${dir.path}/SendSnap');
    }
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Stop the TCP server and clean up.
  Future<void> dispose() async {
    cancelTransfer();
    await _serverSocket?.close();
    _serverSocket = null;
    _isListening = false;
    debugPrint('[SendSnap] Transfer service disposed');
  }
}
