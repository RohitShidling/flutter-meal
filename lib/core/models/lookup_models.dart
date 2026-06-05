class SchoolModel {
  final String id;
  final String name;
  final String address;
  final String city;
  final String state;
  final bool hasLunchBoxPickup;
  final String? lunchBoxPickupTime;

  SchoolModel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    this.hasLunchBoxPickup = false,
    this.lunchBoxPickupTime,
  });

  factory SchoolModel.fromJson(Map<String, dynamic> json) {
    return SchoolModel(
      id: json['id'] is int ? json['id'].toString() : json['id'],
      name: json['name'],
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      hasLunchBoxPickup: json['has_lunch_box_pickup'] ?? false,
      lunchBoxPickupTime: json['lunch_box_pickup_time'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'has_lunch_box_pickup': hasLunchBoxPickup,
      'lunch_box_pickup_time': lunchBoxPickupTime,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'state_id': stateId,
      'name': name,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'city_id': cityId,
      'name': name,
    };
  }
}

class DivisionModel {
  final int id;
  final String name;

  DivisionModel({
    required this.id,
    required this.name,
  });

  factory DivisionModel.fromJson(Map<String, dynamic> json) {
    return DivisionModel(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class ContactUsModel {
  final String title;
  final String subtitle;
  final String email;
  final String phone;
  final String footer;
  final String appName;
  final String aboutTitle;
  final String aboutDescription;
  final String aboutFooter;
  final String licenseText;
  final String websiteUrl;

  ContactUsModel({
    required this.title,
    required this.subtitle,
    required this.email,
    required this.phone,
    required this.footer,
    this.appName = 'Buuttii',
    this.aboutTitle = 'About Buuttii',
    this.aboutDescription = 'Buuttii helps parents, teachers, and professionals manage daily meal subscriptions, menus, and skips in one place.',
    this.aboutFooter = '',
    this.licenseText = '',
    this.websiteUrl = 'https://buuttii.com/',
  });

  factory ContactUsModel.fromJson(Map<String, dynamic> json) {
    return ContactUsModel(
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      footer: (json['footer'] ?? '').toString(),
      appName: (json['app_name'] ?? json['brand_name'] ?? 'Buuttii').toString(),
      aboutTitle: (json['about_title'] ?? json['aboutTitle'] ?? 'About ${json['app_name'] ?? json['brand_name'] ?? 'Buuttii'}').toString(),
      aboutDescription: (json['about_description'] ?? json['aboutDescription'] ?? 'Buuttii helps parents, teachers, and professionals manage daily meal subscriptions, menus, and skips in one place.').toString(),
      aboutFooter: (json['about_footer'] ?? json['aboutFooter'] ?? '').toString(),
      licenseText: (json['license_text'] ?? json['licenseText'] ?? '').toString(),
      websiteUrl: (json['website_url'] ?? json['websiteUrl'] ?? 'https://buuttii.com/').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'email': email,
      'phone': phone,
      'footer': footer,
      'app_name': appName,
      'about_title': aboutTitle,
      'about_description': aboutDescription,
      'about_footer': aboutFooter,
      'license_text': licenseText,
      'website_url': websiteUrl,
    };
  }
}
