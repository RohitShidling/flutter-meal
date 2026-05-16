class TeacherProfileModel {
  final String? id;
  final String name;
  final String schoolCollegeName;
  final String city;
  final String state;
  final String location;
  final String status;
  final int? mealSizeId;
  final String? mealTime;

  TeacherProfileModel({
    this.id,
    required this.name,
    required this.schoolCollegeName,
    required this.city,
    required this.state,
    required this.location,
    this.status = 'active',
    this.mealSizeId,
    this.mealTime,
  });

  factory TeacherProfileModel.fromJson(Map<String, dynamic> json) {
    final parsedId = json['id'] ??
        json['teacher_id'] ??
        json['profile_id'] ??
        json['entity_id'];
    return TeacherProfileModel(
      id: parsedId?.toString(),
      name: json['name']?.toString() ?? '',
      schoolCollegeName: json['school_college_name']?.toString() ??
          json['schoolCollegeName']?.toString() ??
          '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      mealSizeId: json['meal_size_id'] is int
          ? json['meal_size_id'] as int
          : int.tryParse('${json['meal_size_id'] ?? json['mealSizeId'] ?? ''}'),
      mealTime: json['meal_time']?.toString() ?? json['mealTiming']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'school_college_name': schoolCollegeName,
      'city': city,
      'state': state,
      'location': location,
      'status': status,
      'meal_size_id': mealSizeId,
      'meal_time': mealTime,
    };
  }
}

class ProfessionalProfileModel {
  final String? id;
  final String name;
  final String companyName;
  final String corporateLocationId;
  final String city;
  final String state;
  final String lunchTime;
  final String? corporateLocationName;
  final int? mealSizeId;

  ProfessionalProfileModel({
    this.id,
    required this.name,
    required this.companyName,
    required this.corporateLocationId,
    required this.city,
    required this.state,
    required this.lunchTime,
    this.corporateLocationName,
    this.mealSizeId,
  });

  factory ProfessionalProfileModel.fromJson(Map<String, dynamic> json) {
    final parsedId = json['id'] ??
        json['professional_id'] ??
        json['profile_id'] ??
        json['entity_id'];
    return ProfessionalProfileModel(
      id: parsedId?.toString(),
      name: json['name'],
      companyName: json['company_name'],
      corporateLocationId: json['corporate_location_id'],
      city: json['city'],
      state: json['state'],
      lunchTime: json['lunch_time'],
      corporateLocationName: json['corporate_location_name'],
      mealSizeId: json['meal_size_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'company_name': companyName,
      'corporate_location_id': corporateLocationId,
      'city': city,
      'state': state,
      'lunch_time': lunchTime,
      'meal_size_id': mealSizeId,
    };
  }
}
