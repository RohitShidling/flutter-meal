class ChildModel {
  final String? id;
  final String name;
  final String rollNumber;
  final String schoolId;
  final int standardId;
  final int mealSizeId;
  final String mealTime;
  final String? schoolName;
  final String? standardName;
  final String? mealSizeName;

  ChildModel({
    this.id,
    required this.name,
    required this.rollNumber,
    required this.schoolId,
    required this.standardId,
    required this.mealSizeId,
    required this.mealTime,
    this.schoolName,
    this.standardName,
    this.mealSizeName,
  });

  factory ChildModel.fromJson(Map<String, dynamic> json) {
    return ChildModel(
      id: json['id'],
      name: json['name'],
      rollNumber: json['roll_number'] ?? json['rollNumber'],
      schoolId: json['school_id'] ?? json['schoolId'],
      standardId: json['standard_id'] ?? json['standardId'],
      mealSizeId: int.tryParse('${json['meal_size_id'] ?? json['mealSizeId'] ?? 0}') ?? 0,
      mealTime: json['meal_time'] ?? json['mealTime'],
      schoolName: json['school_name'],
      standardName: json['standard_name'],
      mealSizeName: json['meal_size_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'rollNumber': rollNumber,
      'schoolId': schoolId,
      'standardId': standardId,
      'mealSizeId': mealSizeId,
      'mealTime': mealTime,
    };
  }
}
