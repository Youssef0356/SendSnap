import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import '../models/device.dart';
import '../models/payload.dart';
import '../models/transfer.dart';

class NearbyService {
  static const String _serviceId = 'com.the356company.sendsnap';
  
  final Nearby _nearby = Nearby();
  
  // Callbacks
  Function(NearbyDevice)? onDeviceFound;
  Function(String)? onDeviceLost;
  Function(String, String)? onConnectionInitiated; // endpointId, deviceName
  Function(String, bool)? onConnectionResult; // endpointId, success
  Function(String)? onDisconnected;
  Function(String, PayloadWrapper)? onMetadataReceived;
  Function(String, int, PayloadTransferUpdate)? onPayloadUpdate; // endpoint, payloadId, update

  Future<bool> startAdvertising(String deviceName) async {
    try {
      return await _nearby.startAdvertising(
        deviceName,
        Strategy.P2P_POINT_TO_POINT,
        onConnectionInitiated: (id, info) {
          onConnectionInitiated?.call(id, info.endpointName);
        },
        onConnectionResult: (id, status) {
          onConnectionResult?.call(id, status == Status.CONNECTED);
        },
        onDisconnected: (id) {
          onDisconnected?.call(id);
        },
        serviceId: _serviceId,
      );
    } catch (e) {
      debugPrint('[NearbyService] Advertising error: $e');
      return false;
    }
  }

  Future<bool> startDiscovery(String deviceName) async {
    try {
      return await _nearby.startDiscovery(
        deviceName,
        Strategy.P2P_POINT_TO_POINT,
        onEndpointFound: (id, name, serviceId) {
          if (serviceId == _serviceId) {
            onDeviceFound?.call(NearbyDevice(
              endpointId: id,
              endpointName: name ?? 'Unknown Device',
              serviceId: serviceId ?? _serviceId,
            ));
          }
        },
        onEndpointLost: (id) {
          onDeviceLost?.call(id);
        },
        serviceId: _serviceId,
      );
    } catch (e) {
      debugPrint('[NearbyService] Discovery error: $e');
      return false;
    }
  }

  Future<void> stopAll() async {
    await _nearby.stopAdvertising();
    await _nearby.stopDiscovery();
    await _nearby.stopAllEndpoints();
  }

  Future<bool> requestConnection(String deviceName, String endpointId) async {
    try {
      return await _nearby.requestConnection(
        deviceName,
        endpointId,
        onConnectionInitiated: (id, info) {
          onConnectionInitiated?.call(id, info.endpointName);
        },
        onConnectionResult: (id, status) {
          onConnectionResult?.call(id, status == Status.CONNECTED);
        },
        onDisconnected: (id) {
          onDisconnected?.call(id);
        },
      );
    } catch (e) {
      debugPrint('[NearbyService] Connection request error: $e');
      return false;
    }
  }

  Future<void> acceptConnection(String endpointId) async {
    await _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: (endpoint, payload) {
        if (payload.type == PayloadType.BYTES) {
          final jsonStr = utf8.decode(payload.bytes!);
          final wrapper = PayloadWrapper.fromJson(jsonDecode(jsonStr));
          onMetadataReceived?.call(endpoint, wrapper);
        } else if (payload.type == PayloadType.FILE) {
          // File incoming - tracking will happen via onPayloadTransferUpdate
          onMetadataReceived?.call(endpoint, PayloadWrapper(
            type: 'FILE_INCOMING',
            data: {
              'payloadId': payload.id, 
              'tempPath': payload.uri ?? payload.filePath ?? '',
            },
          ));
        }
      },
      onPayloadTransferUpdate: (endpoint, update) {
        onPayloadUpdate?.call(endpoint, update.id, update);
      },
    );
  }

  Future<void> rejectConnection(String endpointId) async {
    await _nearby.rejectConnection(endpointId);
  }

  Future<void> sendMetadata(String endpointId, PayloadWrapper wrapper) async {
    final bytes = utf8.encode(jsonEncode(wrapper.toJson()));
    await _nearby.sendBytesPayload(endpointId, Uint8List.fromList(bytes));
  }

  Future<int> sendFile(String endpointId, String filePath) async {
    return await _nearby.sendFilePayload(endpointId, filePath);
  }

  void disconnect(String endpointId) {
    _nearby.disconnectFromEndpoint(endpointId);
  }
}
