class PayloadWrapper {
  final String type; // 'FILE_META', 'FILE_DATA', 'CANCEL'
  final Map<String, dynamic> data;

  PayloadWrapper({
    required this.type,
    required this.data,
  });

  factory PayloadWrapper.fromJson(Map<String, dynamic> json) {
    return PayloadWrapper(
      type: json['type'],
      data: Map<String, dynamic>.from(json['data']),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'data': data,
  };
}
