class NearbyDevice {
  final String id;
  final String name;
  final String ip;
  final int port;
  final String deviceType;
  final String serviceId;
  final DateTime lastSeen;

  NearbyDevice({
    required this.id,
    required this.name,
    required this.ip,
    this.port = 53318,
    this.deviceType = 'unknown',
    this.serviceId = 'com.the356company.sendsnap',
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  // Backward compatibility getters
  String get endpointId => id;
  String get endpointName => name;

  NearbyDevice copyWith({
    String? id,
    String? name,
    String? ip,
    int? port,
    String? deviceType,
    String? serviceId,
    DateTime? lastSeen,
  }) {
    return NearbyDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      deviceType: deviceType ?? this.deviceType,
      serviceId: serviceId ?? this.serviceId,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ip': ip,
    'port': port,
    'deviceType': deviceType,
    'serviceId': serviceId,
  };

  factory NearbyDevice.fromJson(Map<String, dynamic> json) => NearbyDevice(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'Unknown',
    ip: json['ip'] as String? ?? '',
    port: json['port'] as int? ?? 53318,
    deviceType: json['deviceType'] as String? ?? 'unknown',
    serviceId: json['serviceId'] as String? ?? 'com.the356company.sendsnap',
  );

  @override
  String toString() => 'NearbyDevice($name, $ip:$port)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NearbyDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
