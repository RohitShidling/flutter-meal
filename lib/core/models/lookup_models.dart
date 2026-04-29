class SchoolModel {
  final String id;
  final String name;
  final String address;
  final String city;
  final String state;

  SchoolModel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
  });

  factory SchoolModel.fromJson(Map<String, dynamic> json) {
    return SchoolModel(
      id: json['id'],
      name: json['name'],
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'state': state,
    };
  }
}

class StandardModel {
  final int id;
  final String name;
  final String displayName;

  StandardModel({
    required this.id,
    required this.name,
    required this.displayName,
  });

  factory StandardModel.fromJson(Map<String, dynamic> json) {
    return StandardModel(
      id: json['id'],
      name: json['name'],
      displayName: json['display_name'],
    );
  }
}

class MealSizeModel {
  final int id;
  final String name;
  final String displayName;

  MealSizeModel({
    required this.id,
    required this.name,
    required this.displayName,
  });

  factory MealSizeModel.fromJson(Map<String, dynamic> json) {
    return MealSizeModel(
      id: json['id'],
      name: json['name'],
      displayName: json['display_name'],
    );
  }
}

class CorporateLocationModel {
  final String id;
  final String name;
  final String address;
  final String city;
  final String state;

  CorporateLocationModel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
  });

  factory CorporateLocationModel.fromJson(Map<String, dynamic> json) {
    return CorporateLocationModel(
      id: json['id'],
      name: json['name'],
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
    );
  }
}
