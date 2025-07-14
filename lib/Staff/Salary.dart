// Create a file: salary_record_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Salary {
  final String date;
  final String employeeId;
  final String name;
  final String month;
  final int basicSalary;
  final int advance;
  final int paidNow;
  final int totalPaid;
  final int remaining;
  final String notes;

  Salary({
    required this.date,
    required this.employeeId,
    required this.name,
    required this.month,
    required this.basicSalary,
    required this.advance,
    required this.paidNow,
    required this.totalPaid,
    required this.remaining,
    required this.notes,
  });

  factory Salary.fromJson(Map<String, dynamic> json) => Salary(
    date: json['Date']?.toString() ?? '',
    employeeId: json['Employee ID']?.toString() ?? '',
    name: json['Employee Name']?.toString() ?? '',
    month: json['Month']?.toString() ?? '',
    basicSalary: int.tryParse(json['Basic Salary']?.toString() ?? '0') ?? 0,
    advance: int.tryParse(json['Advance Paid']?.toString() ?? '0') ?? 0,
    paidNow: int.tryParse(json['Paid Now']?.toString() ?? '0') ?? 0,
    totalPaid: int.tryParse(json['Total Paid']?.toString() ?? '0') ?? 0,
    remaining: int.tryParse(json['Remaining']?.toString() ?? '0') ?? 0,
    notes: json['Notes']?.toString() ?? '',
  );


  Map<String, dynamic> toJson() => {
    'date': date,
    'employeeId': employeeId,
    'employeeName': name,
    'month': month,
    'basicSalary': basicSalary,
    'advance': advance,
    'paidNow': paidNow,
    'totalPaid': totalPaid,
    'remaining': remaining,
    'notes': notes,
  };
}
