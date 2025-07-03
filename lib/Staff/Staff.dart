class Staff {
  final String id;
  final String name;
  final String position;
  final String phone;
  final String salary;
  final String nid;
  final String presentAddress;
  final String permanentAddress;
  final String info;
  final String guardianInfo;
  final String email;
  final String profileImage;
  final String documents;
  final DateTime? joiningDate;

  Staff({
    required this.id,
    required this.name,
    required this.position,
    required this.phone,
    required this.salary,
    required this.nid,
    required this.presentAddress,
    required this.permanentAddress,
    required this.info,
    required this.guardianInfo,
    required this.email,
    required this.profileImage,
    required this.documents,
    this.joiningDate,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['Staff ID']?.toString() ?? '',
      name: json['Staff Name']?.toString() ?? 'Unknown',
      position: json['Staff Position']?.toString() ?? '',
      phone: json['Staff Number']?.toString() ?? '',
      salary: json['Staff Salary']?.toString() ?? '0',
      nid: json['Staff NID']?.toString() ?? '',
      presentAddress: json['Staff present_address']?.toString() ?? '',
      permanentAddress: json['Staff permanent_address']?.toString() ?? '',
      info: json['Staff Info']?.toString() ?? '',
      guardianInfo: json['Staff guardian_info']?.toString() ?? '',
      email: json['Staff Email']?.toString() ?? '',
      profileImage: json['Staff profileImage']?.toString() ?? '',
      documents: json['Staff Document']?.toString() ?? '',
      joiningDate: json['JoiningDate'] != null
          ? DateTime.tryParse(json['JoiningDate'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'Staff ID': id,
    'Staff Name': name,
    'Staff Position': position,
    'Staff Number': phone,
    'Staff Salary': salary,
    'Staff NID': nid,
    'Staff present_address': presentAddress,
    'Staff permanent_address': permanentAddress,
    'Staff Info': info,
    'Staff guardian_info': guardianInfo,
    'Staff Email': email,
    'Staff profileImage': profileImage,
    'Staff Document': documents,
    'JoiningDate': joiningDate?.toIso8601String(),
  };
}