enum DeviceStatus { ready, busy, offline }

class NearbyDevice {
  final String id;
  final String name;
  final String ip;
  final int port;
  final DeviceStatus status;

  const NearbyDevice({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    this.status = DeviceStatus.ready,
  });

  NearbyDevice copyWith({
    String? id,
    String? name,
    String? ip,
    int? port,
    DeviceStatus? status,
  }) {
    return NearbyDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ip': ip,
        'port': port,
        'status': status.name,
      };

  factory NearbyDevice.fromJson(Map<String, dynamic> json) {
    return NearbyDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      ip: json['ip'] as String,
      port: json['port'] as int,
      status: DeviceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DeviceStatus.ready,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NearbyDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'NearbyDevice(id: $id, name: $name, ip: $ip:$port)';
}
