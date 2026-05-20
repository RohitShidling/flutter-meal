class BulkDeliveryAddress {
  final int stateId;
  final int cityId;
  final String addressLine;
  final String? pincode;
  final String? stateName;
  final String? cityName;
  /// Preferred delivery time, e.g. "1:30 PM" or "13:30".
  final String? deliveryTime;

  const BulkDeliveryAddress({
    required this.stateId,
    required this.cityId,
    required this.addressLine,
    this.pincode,
    this.stateName,
    this.cityName,
    this.deliveryTime,
  });

  Map<String, dynamic> toApiPayload() => {
        'stateId': stateId,
        'cityId': cityId,
        'address': addressLine,
        if (pincode != null && pincode!.trim().isNotEmpty) 'pincode': pincode!.trim(),
        if (deliveryTime != null && deliveryTime!.trim().isNotEmpty) 'deliveryTime': deliveryTime!.trim(),
      };

  String get formatted {
    final parts = <String>[
      addressLine.trim(),
      if (cityName != null && cityName!.isNotEmpty) cityName!,
      if (stateName != null && stateName!.isNotEmpty) stateName!,
      if (pincode != null && pincode!.trim().isNotEmpty) pincode!.trim(),
    ];
    return parts.join(', ');
  }

  bool get isComplete =>
      stateId > 0 && cityId > 0 && addressLine.trim().length >= 5;

  bool get hasDeliveryTime => deliveryTime != null && deliveryTime!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'stateId': stateId,
        'cityId': cityId,
        'addressLine': addressLine,
        'pincode': pincode,
        'stateName': stateName,
        'cityName': cityName,
        'deliveryTime': deliveryTime,
      };

  factory BulkDeliveryAddress.fromJson(Map<String, dynamic> json) {
    return BulkDeliveryAddress(
      stateId: json['stateId'] as int? ?? 0,
      cityId: json['cityId'] as int? ?? 0,
      addressLine: json['addressLine']?.toString() ?? '',
      pincode: json['pincode']?.toString(),
      stateName: json['stateName']?.toString(),
      cityName: json['cityName']?.toString(),
      deliveryTime: json['deliveryTime']?.toString(),
    );
  }
}
