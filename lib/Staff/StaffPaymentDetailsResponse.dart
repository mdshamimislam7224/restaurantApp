// staff_payment_details_model.dart
class StaffPaymentDetailsResponse {
  final String status;
  final StaffPaymentData data;

  StaffPaymentDetailsResponse({
    required this.status,
    required this.data,
  });

  factory StaffPaymentDetailsResponse.fromJson(Map<String, dynamic> json) {
    return StaffPaymentDetailsResponse(
      status: json['status'],
      data: StaffPaymentData.fromJson(json['data']),
    );
  }
}

class StaffPaymentData {
  final String startMonth;
  final String endMonth;
  final int totalStaff;
  final List<StaffDetail> staffDetails;

  StaffPaymentData({
    required this.startMonth,
    required this.endMonth,
    required this.totalStaff,
    required this.staffDetails,
  });

  factory StaffPaymentData.fromJson(Map<String, dynamic> json) {
    return StaffPaymentData(
      startMonth: json['startMonth'],
      endMonth: json['endMonth'],
      totalStaff: json['totalStaff'],
      staffDetails: (json['staffDetails'] as List)
          .map((item) => StaffDetail.fromJson(item))
          .toList(),
    );
  }
}

class StaffDetail {
  final String employeeId;
  final String employeeName;
  final String position;
  final dynamic phone;
  final int basicSalary;
  final String joiningDate;
  final List<MonthlyPayment> monthlyPayments;
  final PaymentSummary paymentSummary;

  StaffDetail({
    required this.employeeId,
    required this.employeeName,
    required this.position,
    required this.phone,
    required this.basicSalary,
    required this.joiningDate,
    required this.monthlyPayments,
    required this.paymentSummary,
  });

  factory StaffDetail.fromJson(Map<String, dynamic> json) {
    return StaffDetail(
      employeeId: json['employeeId'],
      employeeName: json['employeeName'],
      position: json['position'],
      phone: json['phone'],
      basicSalary: json['basicSalary'] is int
          ? json['basicSalary']
          : int.tryParse(json['basicSalary'].toString()) ?? 0,
      joiningDate: json['joiningDate'],
      monthlyPayments: (json['monthlyPayments'] as List)
          .map((item) => MonthlyPayment.fromJson(item))
          .toList(),
      paymentSummary: PaymentSummary.fromJson(json['paymentSummary']),
    );
  }
}

class MonthlyPayment {
  final String month;
  final int basicSalary;
  final int totalPaid;
  final int paymentCount;
  final List<PaymentDetail> payments;
  final int remaining;
  final String status;

  MonthlyPayment({
    required this.month,
    required this.basicSalary,
    required this.totalPaid,
    required this.paymentCount,
    required this.payments,
    required this.remaining,
    required this.status,
  });

  factory MonthlyPayment.fromJson(Map<String, dynamic> json) {
    return MonthlyPayment(
      month: json['month'],
      basicSalary: json['basicSalary'] is int
          ? json['basicSalary']
          : int.tryParse(json['basicSalary'].toString()) ?? 0,
      totalPaid: json['totalPaid'] is int
          ? json['totalPaid']
          : int.tryParse(json['totalPaid'].toString()) ?? 0,
      paymentCount: json['paymentCount'] is int
          ? json['paymentCount']
          : int.tryParse(json['paymentCount'].toString()) ?? 0,
      payments: (json['payments'] as List)
          .map((item) => PaymentDetail.fromJson(item))
          .toList(),
      remaining: json['remaining'] is int
          ? json['remaining']
          : int.tryParse(json['remaining'].toString()) ?? 0,
      status: json['status'],
    );
  }
}

class PaymentDetail {
  final String paymentDate;
  final String salaryMonth;
  final int paidAmount;
  final int basicSalary;
  final int totalPaid;
  final int remaining;
  final String notes;

  PaymentDetail({
    required this.paymentDate,
    required this.salaryMonth,
    required this.paidAmount,
    required this.basicSalary,
    required this.totalPaid,
    required this.remaining,
    required this.notes,
  });

  factory PaymentDetail.fromJson(Map<String, dynamic> json) {
    return PaymentDetail(
      paymentDate: json['paymentDate'],
      salaryMonth: json['salaryMonth'],
      paidAmount: json['paidAmount'] is int
          ? json['paidAmount']
          : int.tryParse(json['paidAmount'].toString()) ?? 0,
      basicSalary: json['basicSalary'] is int
          ? json['basicSalary']
          : int.tryParse(json['basicSalary'].toString()) ?? 0,
      totalPaid: json['totalPaid'] is int
          ? json['totalPaid']
          : int.tryParse(json['totalPaid'].toString()) ?? 0,
      remaining: json['remaining'] is int
          ? json['remaining']
          : int.tryParse(json['remaining'].toString()) ?? 0,
      notes: json['notes'],
    );
  }
}

class PaymentSummary {
  final int totalPaidAllTime;
  final int totalDueAllTime;
  final int advanceBalance;
  final List<DueMonth> dueMonths;
  final List<String> fullyPaidMonths;
  final List<String> partiallyPaidMonths;

  PaymentSummary({
    required this.totalPaidAllTime,
    required this.totalDueAllTime,
    required this.advanceBalance,
    required this.dueMonths,
    required this.fullyPaidMonths,
    required this.partiallyPaidMonths,
  });

  factory PaymentSummary.fromJson(Map<String, dynamic> json) {
    return PaymentSummary(
      totalPaidAllTime: json['totalPaidAllTime'] is int
          ? json['totalPaidAllTime']
          : int.tryParse(json['totalPaidAllTime'].toString()) ?? 0,
      totalDueAllTime: json['totalDueAllTime'] is int
          ? json['totalDueAllTime']
          : int.tryParse(json['totalDueAllTime'].toString()) ?? 0,
      advanceBalance: json['advanceBalance'] is int
          ? json['advanceBalance']
          : int.tryParse(json['advanceBalance'].toString()) ?? 0,
      dueMonths: (json['dueMonths'] as List)
          .map((item) => DueMonth.fromJson(item))
          .toList(),
      fullyPaidMonths: (json['fullyPaidMonths'] as List).cast<String>(),
      partiallyPaidMonths: (json['partiallyPaidMonths'] as List).cast<String>(),
    );
  }
}

class DueMonth {
  final String month;
  final int dueAmount;
  final int paidAmount;

  DueMonth({
    required this.month,
    required this.dueAmount,
    required this.paidAmount,
  });

  factory DueMonth.fromJson(Map<String, dynamic> json) {
    return DueMonth(
      month: json['month'],
      dueAmount: json['dueAmount'] is int
          ? json['dueAmount']
          : int.tryParse(json['dueAmount'].toString()) ?? 0,
      paidAmount: json['paidAmount'] is int
          ? json['paidAmount']
          : int.tryParse(json['paidAmount'].toString()) ?? 0,
    );
  }
}