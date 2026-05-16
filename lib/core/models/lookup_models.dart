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
  final int sortOrder;

  MealSizeModel({
    required this.id,
    required this.name,
    required this.displayName,
    this.sortOrder = 0,
  });

  factory MealSizeModel.fromJson(Map<String, dynamic> json) {
    return MealSizeModel(
      id: json['id'],
      name: json['name'],
      displayName: json['display_name'],
      sortOrder: int.tryParse('${json['sort_order'] ?? 0}') ?? 0,
    );
  }

  /// Highest tier in the catalog (e.g. Large / Extra Large).
  static int? largestTierId(List<MealSizeModel> sizes) {
    if (sizes.isEmpty) return null;
    MealSizeModel? top;
    for (final s in sizes) {
      if (top == null || s.sortOrder > top.sortOrder || (s.sortOrder == top.sortOrder && s.id > top.id)) {
        top = s;
      }
    }
    return top?.id;
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

class StateModel {
  final int id;
  final String name;

  StateModel({required this.id, required this.name});

  factory StateModel.fromJson(Map<String, dynamic> json) {
    return StateModel(
      id: json['id'],
      name: json['name'],
    );
  }
}

class CityModel {
  final int id;
  final int stateId;
  final String name;

  CityModel({required this.id, required this.stateId, required this.name});

  factory CityModel.fromJson(Map<String, dynamic> json) {
    return CityModel(
      id: json['id'],
      stateId: json['state_id'],
      name: json['name'],
    );
  }
}

class CompanyModel {
  final int id;
  final int cityId;
  final String name;

  CompanyModel({required this.id, required this.cityId, required this.name});

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['id'],
      cityId: json['city_id'],
      name: json['name'],
    );
  }
}
