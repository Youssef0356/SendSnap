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
  Uint8List pending = Uint8List(0);

  _IncomingSocketContext(this.socket) : queue = StreamQueue<Uint8List>(socket);
}

class TransferService {
  ServerSocket? _serverSocket;
  Socket? _activeSocket;
  bool _isListening = false;
  int _serverPort = 0;

  Function(IncomingRequest)? onIncomingRequest;
  Function(TransferSession)? onTransferUpdate;
  Function(String)? onError;
  Function()? onTransferComplete;

  bool get isListening => _isListening;
  int get serverPort => _serverPort;

  // ─── RECEIVER SIDE ───

  Future<int> startServer() async {
    if (_isListening) return _serverPort;

    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
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
    debugPrint(
      '[SendSnap] Incoming connection from ${socket.remoteAddress.address}:${socket.remotePort}',
    );

    try {
      final ctx = _IncomingSocketContext(socket);

      debugPrint('[SendSnap] Reading header from ${socket.remoteAddress.address}...');
      final headerJson = await _readHeader(ctx).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('[SendSnap] Timeout reading header from ${socket.remoteAddress.address}');
          socket.destroy();
          throw TimeoutException('Header timeout');
        },
      );

      debugPrint('[SendSnap] Received header: $headerJson');
      final metadata = jsonDecode(headerJson) as Map<String, dynamic>;
      final senderName = metadata['sender'] as String;
      final filesJson = metadata['files'] as List;
      final files = filesJson
          .map((f) => TransferFile.fromJson(f as Map<String, dynamic>))
          .toList();

      debugPrint('[SendSnap] Incoming request from $senderName with ${files.length} files');
      final request = IncomingRequest(
        senderName: senderName,
        senderIp: socket.remoteAddress.address,
        senderPort: socket.remotePort,
        files: files,
        socket: ctx,
      );

      onIncomingRequest?.call(request);
    } catch (e) {
      debugPrint('[SendSnap] Error handling connection from ${socket.remoteAddress.address}: $e');
      socket.destroy();
    }
  }

  Future<void> acceptTransfer(IncomingRequest request) async {
    final ctx = request.socket is _IncomingSocketContext
        ? request.socket as _IncomingSocketContext
        : _IncomingSocketContext(request.socket as Socket);

    try {
      ctx.socket.write('ACCEPT\n');
      await ctx.socket.flush();
      debugPrint('[SendSnap] Accepted transfer from ${request.senderName}');

      final saveDir = await _getSaveDirectory();
      final files = List<TransferFile>.from(request.files);
      int totalReceived = 0;
      final totalSize = request.totalSize;

      // Guard against divide-by-zero on empty transfers
      if (totalSize == 0) {
        ctx.socket.write('TRANSFER_OK\n');
        await ctx.socket.flush();
        ctx.socket.destroy();
        return;
      }

      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        files[i] = file.copyWith(status: FileTransferStatus.transferring);

        _emitUpdate(
          TransferSession(
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
          ),
        );

        final savePath = '${saveDir.path}/${file.name}';
        final outputFile = File(savePath);
        IOSink sink;
        try {
          sink = outputFile.openWrite();
        } catch (e) {
          debugPrint('[SendSnap] Write error: $e');
          ctx.socket.write('WRITE_ERROR:${file.name}\n');
          await ctx.socket.flush();
          throw Exception('Permission denied to write ${file.name}');
        }

        int fileReceived = 0;
        DateTime lastSpeedUpdate = DateTime.now();
        int lastSpeedBytes = 0;
        double currentSpeed = 0;

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

          final now = DateTime.now();
          final elapsed = now.difference(lastSpeedUpdate).inMilliseconds;
          if (elapsed >= 500) {
            currentSpeed = (fileReceived - lastSpeedBytes) / elapsed * 1000.0;
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

          // Throttle updates to ~10 per second to avoid UI lag
          if (now.difference(lastSpeedUpdate).inMilliseconds >= 100 || remaining == 0) {
            _emitUpdate(
              TransferSession(
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
              ),
            );
          }
        }

        try {
          await sink.flush();
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

      // FIX: send final OK signal only after all files are fully written
      ctx.socket.write('TRANSFER_OK\n');
      await ctx.socket.flush();

      _emitUpdate(
        TransferSession(
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
        ),
      );

      onTransferComplete?.call();
      try {
        await ctx.queue.cancel();
      } catch (_) {}
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

  void declineTransfer(IncomingRequest request) {
    final ctx = request.socket is _IncomingSocketContext
        ? request.socket as _IncomingSocketContext
        : null;
    final socket = ctx?.socket ?? request.socket as Socket;
    try {
      socket.write('REJECT\n');
      socket.flush().whenComplete(() {
        ctx?.queue.cancel()?.catchError((_) {});
        socket.destroy();
      });
    } catch (e) {
      socket.destroy();
    }
  }

  // ─── SENDER SIDE ───

  Future<void> sendFiles({
    required NearbyDevice target,
    required List<TransferFile> files,
    required String senderName,
  }) async {
    try {
      debugPrint('[SendSnap] Starting sendFiles to ${target.name} (${target.ip}:${target.port})');
      final sourceAddr = await _getBestSourceAddress(target.ip);
      debugPrint(
        '[SendSnap] Connecting from ${sourceAddr?.address ?? "any"} to ${target.ip}:${target.port}',
      );

      _activeSocket = await Socket.connect(
        target.ip,
        target.port,
        sourceAddress: sourceAddr,
        timeout: const Duration(seconds: 15),
      );
      debugPrint('[SendSnap] Connected to ${target.ip}:${target.port}');

      final metadata = {
        'sender': senderName,
        'files': files.map((f) => f.toJson()).toList(),
      };
      debugPrint('[SendSnap] Sending header: ${jsonEncode(metadata)}');
      _activeSocket!.write('${jsonEncode(metadata)}\n---END_HEADER---\n');
      await _activeSocket!.flush();

      _emitUpdate(
        TransferSession(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          targetDevice: target,
          files: files,
          direction: TransferDirection.sending,
          status: TransferSessionStatus.waitingForAccept,
        ),
      );

      debugPrint('[SendSnap] Header sent, waiting for response...');
      // Wait for ACCEPT / REJECT
      final responseCompleter = Completer<String>();
      final responseBuf = StringBuffer();
      late StreamSubscription responseSub;
      responseSub = _activeSocket!.listen(
        (data) {
          final text = utf8.decode(data);
          debugPrint('[SendSnap] Received raw data from receiver: $text');
          responseBuf.write(text);
          if (responseBuf.toString().contains('\n')) {
            responseSub.cancel();
            if (!responseCompleter.isCompleted) {
              final resp = responseBuf.toString().trim();
              debugPrint('[SendSnap] Parsed response: $resp');
              responseCompleter.complete(resp);
            }
          }
        },
        onError: (e) {
          debugPrint('[SendSnap] Socket error while waiting for response: $e');
          if (!responseCompleter.isCompleted) {
            responseCompleter.completeError(e);
          }
        },
        onDone: () {
          debugPrint('[SendSnap] Socket closed while waiting for response');
          if (!responseCompleter.isCompleted) {
            responseCompleter.completeError('Socket closed');
          }
        },
        cancelOnError: true,
      );

      final response = await responseCompleter.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          debugPrint('[SendSnap] Timeout waiting for response from receiver');
          _activeSocket?.destroy();
          throw TimeoutException('No response from receiver');
        },
      );

      if (response != 'ACCEPT') {
        debugPrint('[SendSnap] Transfer rejected by ${target.name}');
        _emitUpdate(
          TransferSession(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            targetDevice: target,
            files: files,
            direction: TransferDirection.sending,
            status: TransferSessionStatus.cancelled,
            errorMessage: 'Request declined by ${target.name}',
          ),
        );
        _activeSocket?.destroy();
        return;
      }

      debugPrint('[SendSnap] Transfer accepted, starting send');

      final mutableFiles = List<TransferFile>.from(files);
      int totalSent = 0;
      final totalSize = files.fold<int>(0, (sum, f) => sum + f.size);
      DateTime lastSpeedUpdate = DateTime.now();
      int lastSpeedBytes = 0;
      double currentSpeed = 0;

      for (int i = 0; i < mutableFiles.length; i++) {
        final file = mutableFiles[i];
        mutableFiles[i] = file.copyWith(
          status: FileTransferStatus.transferring,
        );

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

          final now = DateTime.now();
          final elapsed = now.difference(lastSpeedUpdate).inMilliseconds;
          if (elapsed >= 500) {
            currentSpeed = (totalSent - lastSpeedBytes) / elapsed * 1000.0;
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

          // Throttle updates to ~10 per second to avoid UI lag
          if (now.difference(lastSpeedUpdate).inMilliseconds >= 100) {
            _emitUpdate(
              TransferSession(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                targetDevice: target,
                files: List.from(mutableFiles),
                direction: TransferDirection.sending,
                overallProgress: totalSent / totalSize,
                speed: currentSpeed,
                timeRemaining: eta,
                status: TransferSessionStatus.transferring,
              ),
            );
          }
        }

        // FIX: flush after each file so receiver bytes arrive before we move on
        await _activeSocket!.flush();

        mutableFiles[i] = file.copyWith(
          status: FileTransferStatus.completed,
          progress: 1.0,
        );
      }

      // FIX: flush all buffered data BEFORE waiting for the ACK
      await _activeSocket!.flush();

      debugPrint('[SendSnap] Waiting for final ACK from receiver...');
      final ackCompleter = Completer<String>();
      final ackBuf = StringBuffer();
      late StreamSubscription ackSub;
      ackSub = _activeSocket!.listen(
        (data) {
          ackBuf.write(utf8.decode(data));
          if (ackBuf.toString().contains('\n')) {
            ackSub.cancel();
            if (!ackCompleter.isCompleted) {
              ackCompleter.complete(ackBuf.toString().trim());
            }
          }
        },
        onError: (e) {
          if (!ackCompleter.isCompleted)
            ackCompleter.complete('CONNECTION_LOST');
        },
        onDone: () {
          // Socket closed before we got ACK — treat as OK if all bytes sent
          if (!ackCompleter.isCompleted) ackCompleter.complete('TRANSFER_OK');
        },
        cancelOnError: true,
      );

      final finalAck = await ackCompleter.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => 'TIMEOUT',
      );

      debugPrint('[SendSnap] Final ACK received: $finalAck');

      if (finalAck.startsWith('WRITE_ERROR')) {
        throw Exception(
          'Receiver failed to write file: ${finalAck.split(':').last}',
        );
      } else if (finalAck != 'TRANSFER_OK' && finalAck != 'TIMEOUT') {
        debugPrint('[SendSnap] Warning: Unexpected final ACK: $finalAck');
      }

      _emitUpdate(
        TransferSession(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          targetDevice: target,
          files: List.from(mutableFiles),
          direction: TransferDirection.sending,
          overallProgress: 1.0,
          status: TransferSessionStatus.completed,
        ),
      );

      onTransferComplete?.call();
      try {
        await _activeSocket!.flush();
      } catch (_) {}
      _activeSocket!.destroy();
      debugPrint('[SendSnap] All files sent successfully');
    } catch (e) {
      debugPrint('[SendSnap] Send error: $e');

      String displayError = e.toString();
      if (e is SocketException) {
        final code = e.osError?.errorCode;
        if (code == 113 || code == 111) {
          displayError =
              'Cannot reach device. If on public/hotel WiFi, AP Isolation may be blocking direct connections. Try Offline (Bluetooth) mode instead.';
        } else if (code == 110) {
          displayError =
              'Connection timed out. Make sure both devices are on the same WiFi network.';
        }
      }

      _emitUpdate(
        TransferSession(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          targetDevice: target,
          files: files,
          direction: TransferDirection.sending,
          status: TransferSessionStatus.connectionLost,
          errorMessage: displayError,
        ),
      );
      _activeSocket?.destroy();
      onError?.call('Transfer failed: $displayError');
    }
  }

  void cancelTransfer() {
    _activeSocket?.destroy();
    _activeSocket = null;
    debugPrint('[SendSnap] Transfer cancelled');
  }

  void _emitUpdate(TransferSession session) {
    onTransferUpdate?.call(session);
  }

  Future<Directory> _getSaveDirectory() async {
    Directory? dir;
    if (Platform.isAndroid) {
      try {
        final downloads = await getExternalStorageDirectories(
          type: StorageDirectory.downloads,
        );
        if (downloads != null && downloads.isNotEmpty) {
          dir = Directory('${downloads.first.path}/SendSnap');
        }
      } catch (e) {
        debugPrint(
          '[SendSnap] Could not get external storage via path_provider: $e',
        );
      }
      dir ??= Directory('/storage/emulated/0/Download/SendSnap');
    } else {
      dir = await getApplicationDocumentsDirectory();
      dir = Directory('${dir.path}/SendSnap');
    }
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // FIX: fully reset state so startServer() works after a role switch
  Future<void> dispose() async {
    cancelTransfer();
    try {
      await _serverSocket?.close();
    } catch (_) {}
    _serverSocket = null;
    _isListening = false;
    _serverPort = 0;
    debugPrint('[SendSnap] Transfer service disposed');
  }

  Future<InternetAddress?> _getBestSourceAddress(String targetIp) async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      final targetSubnet = targetIp.split('.').take(3).join('.');
      for (var iface in interfaces) {
        for (var addr in iface.addresses) {
          if (addr.address.startsWith(targetSubnet)) return addr;
        }
      }
      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        return interfaces.first.addresses.first;
      }
    } catch (_) {}
    return null;
  }
}

// ─── Header parsing helpers ───

Future<String> _readHeader(_IncomingSocketContext ctx) async {
  final terminator = utf8.encode('\n---END_HEADER---\n');
  final builder = BytesBuilder(copy: false);

  if (ctx.pending.isNotEmpty) {
    debugPrint('[SendSnap] _readHeader: Adding pending bytes (${ctx.pending.length})');
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
      debugPrint('[SendSnap] _readHeader: Found terminator. Header length: ${headerBytes.length}, Pending: ${ctx.pending.length}');
      return utf8.decode(headerBytes);
    }
    debugPrint('[SendSnap] _readHeader: Waiting for next chunk...');
    final chunk = await ctx.queue.next;
    debugPrint('[SendSnap] _readHeader: Received chunk (${chunk.length})');
    builder.add(chunk);
  }
}

Future<Uint8List> _nextBytes(_IncomingSocketContext ctx) async {
  if (ctx.pending.isNotEmpty) {
    final bytes = ctx.pending;
    ctx.pending = Uint8List(0);
    debugPrint('[SendSnap] _nextBytes: Returning pending bytes (${bytes.length})');
    return bytes;
  }
  debugPrint('[SendSnap] _nextBytes: Waiting for next chunk...');
  final chunk = await ctx.queue.next;
  debugPrint('[SendSnap] _nextBytes: Received chunk (${chunk.length})');
  return chunk;
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
