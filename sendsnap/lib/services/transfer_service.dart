import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:async/async.dart';
import 'package:path_provider/path_provider.dart';
import '../models/device.dart';
import '../models/transfer_file.dart';

class _IncomingSocketContext {
  final Socket socket;
  final StreamQueue<Uint8List> queue;

  // Bytes already read from the stream but not yet consumed by higher-level parsing.
  Uint8List pending = Uint8List(0);

  _IncomingSocketContext(this.socket) : queue = StreamQueue<Uint8List>(socket);
}

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
      final ctx = _IncomingSocketContext(socket);

      // Wait for the header with timeout
      final headerJson = await _readHeader(ctx).timeout(
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
        socket: ctx,
      );

      onIncomingRequest?.call(request);
    } catch (e) {
      debugPrint('[SendSnap] Error handling connection: $e');
      socket.destroy();
    }
  }

  /// Accept an incoming file transfer request.
  Future<void> acceptTransfer(IncomingRequest request) async {
    final ctx = request.socket is _IncomingSocketContext
        ? request.socket as _IncomingSocketContext
        : _IncomingSocketContext(request.socket as Socket);

    try {
      // Send acceptance signal
      ctx.socket.write('ACCEPT\n');
      await ctx.socket.flush();
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
        IOSink sink;
        try {
          sink = outputFile.openWrite();
        } catch (e) {
          debugPrint('[SendSnap] Permission denied or write error: $e');
          ctx.socket.write('WRITE_ERROR:${file.name}\n');
          await ctx.socket.flush();
          throw Exception('Permission denied to write ${file.name}');
        }

        int fileReceived = 0;
        DateTime lastSpeedUpdate = DateTime.now();
        int lastSpeedBytes = 0;
        double currentSpeed = 0;

        // Read exactly `file.size` bytes. This avoids corrupting binary files and
        // works correctly regardless of TCP packet boundaries.
        int remaining = file.size;
        while (remaining > 0) {
          final Uint8List chunk = await _nextBytes(ctx);
          if (chunk.isEmpty) continue;

          if (chunk.length <= remaining) {
            sink.add(chunk);
            fileReceived += chunk.length;
            totalReceived += chunk.length;
            remaining -= chunk.length;
          } else {
            sink.add(chunk.sublist(0, remaining));
            fileReceived += remaining;
            totalReceived += remaining;
            ctx.pending = Uint8List.fromList(chunk.sublist(remaining));
            remaining = 0;
          }

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
        }

        try {
          await sink.close();
        } catch (e) {
          ctx.socket.write('WRITE_ERROR:${file.name}\n');
          await ctx.socket.flush();
          throw Exception('Failed to finalize file: $e');
        }

        files[i] = file.copyWith(
          status: FileTransferStatus.completed,
          progress: 1.0,
          path: savePath,
        );
      }

      // All done - Send final OK signal
      ctx.socket.write('TRANSFER_OK\n');
      await ctx.socket.flush();

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
      await ctx.queue.cancel();
      ctx.socket.destroy();
    } catch (e) {
      debugPrint('[SendSnap] Transfer receive error: $e');
      onError?.call('Transfer failed: $e');
      try {
        await ctx.queue.cancel();
      } catch (_) {}
      ctx.socket.destroy();
    }
  }

  /// Decline an incoming file transfer request.
  void declineTransfer(IncomingRequest request) {
    final ctx =
        request.socket is _IncomingSocketContext ? request.socket as _IncomingSocketContext : null;
    final socket = ctx?.socket ?? request.socket as Socket;
    try {
      socket.write('REJECT\n');
      socket.flush().whenComplete(() {
        ctx?.queue.cancel()?.catchError((_) {});
        socket.destroy();
      });
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
      final sourceAddr = await _getBestSourceAddress(target.ip);
      debugPrint('[SendSnap] Connecting from ${sourceAddr?.address ?? "any"} to ${target.ip}:${target.port}');
      
      _activeSocket = await Socket.connect(
        target.ip,
        target.port,
        sourceAddress: sourceAddr,
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

        mutableFiles[i] = file.copyWith(
          status: FileTransferStatus.completed,
          progress: 1.0,
        );
      }

      // Wait for receiver's final ACK (TRANSFER_OK or WRITE_ERROR)
      debugPrint('[SendSnap] Waiting for final ACK from receiver...');
      final ackCompleter = Completer<String>();
      final ackBuf = StringBuffer();

      late StreamSubscription ackSub;
      ackSub = _activeSocket!.listen(
        (data) {
          ackBuf.write(utf8.decode(data));
          if (ackBuf.toString().contains('\n')) {
            ackSub.cancel();
            ackCompleter.complete(ackBuf.toString().trim());
          }
        },
        onError: (e) {
          if (!ackCompleter.isCompleted) ackCompleter.complete('CONNECTION_LOST');
        },
        cancelOnError: true,
      );

      final finalAck = await ackCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => 'TIMEOUT',
      );

      debugPrint('[SendSnap] Final ACK received: $finalAck');

      if (finalAck.startsWith('WRITE_ERROR')) {
        throw Exception('Receiver failed to write file: ${finalAck.split(':').last}');
      } else if (finalAck != 'TRANSFER_OK') {
        debugPrint('[SendSnap] Warning: Unexpected final ACK: $finalAck');
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
      
      String displayError = e.toString();
      if (e is SocketException && e.osError?.errorCode == 113) {
        displayError = 'Connection blocked by WiFi Router (AP Isolation). Please use the Offline Connection mode, or connect both devices to a private/home WiFi network.';
      }

      _emitUpdate(TransferSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        targetDevice: target,
        files: files,
        direction: TransferDirection.sending,
        status: TransferSessionStatus.connectionLost,
        errorMessage: displayError,
      ));
      _activeSocket?.destroy();
      onError?.call('Transfer failed: $displayError');
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
      try {
        // Try getting the public downloads directory via path_provider
        final downloads = await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (downloads != null && downloads.isNotEmpty) {
          dir = Directory('${downloads.first.path}/SendSnap');
        }
      } catch (e) {
        debugPrint('[SendSnap] Could not get external storage via path_provider: $e');
      }
      
      // Fallback to absolute legacy path if path_provider fails or is restrictive
      dir ??= Directory('/storage/emulated/0/Download/SendSnap');
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

  /// Attempts to find the best local interface IP to bind to, ensuring we route
  /// through the WiFi interface instead of getting stuck on Mobile Data.
  Future<InternetAddress?> _getBestSourceAddress(String targetIp) async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      
      final targetSubnet = targetIp.split('.').take(3).join('.');
      
      for (var iface in interfaces) {
        for (var addr in iface.addresses) {
          if (addr.address.startsWith(targetSubnet)) {
            return addr;
          }
        }
      }
      
      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        return interfaces.first.addresses.first;
      }
    } catch (_) {}
    return null;
  }
}

Future<String> _readHeader(_IncomingSocketContext ctx) async {
  final terminator = utf8.encode('\n---END_HEADER---\n');
  final builder = BytesBuilder(copy: false);

  if (ctx.pending.isNotEmpty) {
    builder.add(ctx.pending);
    ctx.pending = Uint8List(0);
  }

  while (true) {
    final bytes = builder.toBytes();
    final idx = _indexOfSubsequence(bytes, terminator);
    if (idx != -1) {
      final headerBytes = bytes.sublist(0, idx);
      final remaining = bytes.sublist(idx + terminator.length);
      ctx.pending = Uint8List.fromList(remaining);
      return utf8.decode(headerBytes);
    }

    builder.add(await ctx.queue.next);
  }
}

Future<Uint8List> _nextBytes(_IncomingSocketContext ctx) async {
  if (ctx.pending.isNotEmpty) {
    final bytes = ctx.pending;
    ctx.pending = Uint8List(0);
    return bytes;
  }
  return await ctx.queue.next;
}

int _indexOfSubsequence(Uint8List data, List<int> pattern) {
  if (pattern.isEmpty) return 0;
  if (data.length < pattern.length) return -1;

  for (int i = 0; i <= data.length - pattern.length; i++) {
    bool match = true;
    for (int j = 0; j < pattern.length; j++) {
      if (data[i + j] != pattern[j]) {
        match = false;
        break;
      }
    }
    if (match) return i;
  }
  return -1;
}
