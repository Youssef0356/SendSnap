class NearbyDevice {
  final String endpointId;
  final String endpointName;
  final String serviceId;

  NearbyDevice({
    required this.endpointId,
    required this.endpointName,
    required this.serviceId,
  });

  @override
  String toString() => 'NearbyDevice($endpointName)';
}
