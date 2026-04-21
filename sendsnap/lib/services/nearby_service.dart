import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import '../models/device.dart';
import '../models/payload.dart';

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
      debugPrint('[NearbyService] Starting advertising as $deviceName...');
      bool success = await _nearby.startAdvertising(
        deviceName,
        Strategy.P2P_POINT_TO_POINT,
        onConnectionInitiated: (id, info) {
          debugPrint('[NearbyService] Connection initiated with $id (${info.endpointName})');
          onConnectionInitiated?.call(id, info.endpointName);
        },
        onConnectionResult: (id, status) {
          debugPrint('[NearbyService] Connection result with $id: $status');
          onConnectionResult?.call(id, status == Status.CONNECTED);
        },
        onDisconnected: (id) {
          debugPrint('[NearbyService] Disconnected from $id');
          onDisconnected?.call(id);
        },
        serviceId: _serviceId,
      );
      debugPrint('[NearbyService] Advertising success: $success');
      return success;
    } catch (e) {
      debugPrint('[NearbyService] Advertising CRITICAL error: $e');
      return false;
    }
  }

  Future<bool> startDiscovery(String deviceName) async {
    try {
      debugPrint('[NearbyService] Starting discovery for $deviceName...');
      bool success = await _nearby.startDiscovery(
        deviceName,
        Strategy.P2P_POINT_TO_POINT,
        onEndpointFound: (id, name, serviceId) {
          debugPrint('[NearbyService] Device found: $name (ID: $id, Service: $serviceId)');
          if (serviceId == _serviceId) {
            onDeviceFound?.call(NearbyDevice(
              endpointId: id,
              endpointName: name,
              serviceId: serviceId,
            ));
          } else {
            debugPrint('[NearbyService] Skipping device with different ServiceId: $serviceId');
          }
        },
        onEndpointLost: (id) {
          debugPrint('[NearbyService] Device lost: $id');
          if (id != null) {
            onDeviceLost?.call(id);
          }
        },
        serviceId: _serviceId,
      );
      debugPrint('[NearbyService] Discovery success: $success');
      return success;
    } catch (e) {
      debugPrint('[NearbyService] Discovery CRITICAL error: $e');
      return false;
    }
  }

  Future<void> stopAll() async {
    try {
      await _nearby.stopAdvertising();
    } catch (e) {
      debugPrint('[NearbyService] stopAdvertising error: $e');
    }
    try {
      await _nearby.stopDiscovery();
    } catch (e) {
      debugPrint('[NearbyService] stopDiscovery error: $e');
    }
    try {
      await _nearby.stopAllEndpoints();
    } catch (e) {
      debugPrint('[NearbyService] stopAllEndpoints error: $e');
    }
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
    try {
      await _nearby.acceptConnection(
        endpointId,
        onPayLoadRecieved: (endpoint, payload) {
          if (payload.type == PayloadType.BYTES) {
            try {
              final jsonStr = utf8.decode(payload.bytes!);
              final wrapper = PayloadWrapper.fromJson(jsonDecode(jsonStr));
              onMetadataReceived?.call(endpoint, wrapper);
            } catch (e) {
              debugPrint('[NearbyService] Error parsing bytes payload: $e');
            }
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
    } catch (e) {
      debugPrint('[NearbyService] acceptConnection error: $e');
    }
  }

  Future<void> rejectConnection(String endpointId) async {
    try {
      await _nearby.rejectConnection(endpointId);
    } catch (e) {
      debugPrint('[NearbyService] rejectConnection error: $e');
    }
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
