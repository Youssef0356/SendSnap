import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Low-latency WebSocket client for streaming touch coordinates and file drag events
/// to a peer device in real-time.
class PortalStreamClient {
  WebSocket? _socket;
  String? _connectedIp;
  bool _isConnecting = false;

  bool get isConnected => _socket != null && _socket!.readyState == WebSocket.open;

  /// Connect to the peer device's portal stream endpoint
  Future<bool> connect(String ip, {int port = 53318}) async {
    if (isConnected && _connectedIp == ip) return true;
    if (_isConnecting) return false;

    _isConnecting = true;
    await disconnect();

    try {
      final uri = Uri.parse('ws://$ip:$port/api/v1/portal/stream');
      _socket = await WebSocket.connect(uri.toString())
          .timeout(const Duration(milliseconds: 2500));
      _connectedIp = ip;
      _isConnecting = false;
      debugPrint('[PortalClient] Connected to portal stream at $ip:$port');
      return true;
    } catch (e) {
      debugPrint('[PortalClient] Failed to connect to portal stream at $ip:$port ($e)');
      _isConnecting = false;
      _socket = null;
      _connectedIp = null;
      return false;
    }
  }

  /// Send real-time coordinate and penetration updates while dragging
  void sendDragMove({
    required String fileName,
    required double penetration,
    required double normalizedY,
  }) {
    if (!isConnected) return;
    try {
      final payload = jsonEncode({
        'type': 'DRAG_MOVE',
        'fileName': fileName,
        'penetration': penetration,
        'y': normalizedY,
      });
      _socket!.add(payload);
    } catch (e) {
      debugPrint('[PortalClient] sendDragMove error: $e');
    }
  }

  /// Inform peer device that the drag was canceled (dragged back or let go outside portal)
  void sendDragCancel() {
    if (!isConnected) return;
    try {
      _socket!.add(jsonEncode({'type': 'DRAG_CANCEL'}));
    } catch (_) {}
  }

  /// Inform peer device that the file was dropped inside the portal
  void sendDragDrop({required String fileName}) {
    if (!isConnected) return;
    try {
      _socket!.add(jsonEncode({
        'type': 'DRAG_DROP',
        'fileName': fileName,
      }));
    } catch (_) {}
  }

  /// Disconnect cleanly
  Future<void> disconnect() async {
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
    _connectedIp = null;
    _isConnecting = false;
  }
}
