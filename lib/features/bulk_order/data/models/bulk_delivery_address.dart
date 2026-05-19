class BulkDeliveryAddress {
  final int stateId;
  final int cityId;
  final String addressLine;
  final String? pincode;
  final String? stateName;
  final String? cityName;

  const BulkDeliveryAddress({
    required this.stateId,
    required this.cityId,
    required this.addressLine,
    this.pincode,
    this.stateName,
    this.cityName,
  });

  Map<String, dynamic> toApiPayload() => {
        'stateId': stateId,
        'cityId': cityId,
        'address': addressLine,
        if (pincode != null && pincode!.trim().isNotEmpty) 'pincode': pincode!.trim(),
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
}
