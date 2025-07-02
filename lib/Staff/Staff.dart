class Staff {
  final String id;
  final String name;
  final String position;
  final String phone;
  final String salary;
  final String joinDate;
  final String profileImage;

  Staff({
    required this.id,
    required this.name,
    required this.position,
    required this.phone,
    required this.salary,
    required this.joinDate,
    required this.profileImage,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['Staff ID'] ?? '',
      name: json['Staff Name'] ?? '',
      position: json['Staff Position'] ?? '',
      phone: json['Staff Number'] ?? '',
      salary: json['Staff Salary'] ?? '',
      joinDate: json['JoiningDate'] ?? '',
      profileImage: json['Staff profileImage'] ?? '',
    );
  }
}