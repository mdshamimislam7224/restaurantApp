import 'dart:convert';
import 'package:intl/intl.dart';

class AttendanceRecord {
  final String staffId;
  final String name;
  final String date;
  final String? firstInTime;
  final String? lastOutTime;
  final String? shiftStart;
  final String? shiftEnd;
  final String status;
  final String? hoursWorked;
  final String? notes;
  final double? lat;
  final double? long;

  AttendanceRecord({
    required this.staffId,
    required this.name,
    required this.date,
    this.firstInTime,
    this.lastOutTime,
    this.shiftStart,
    this.shiftEnd,
    required this.status,
    this.hoursWorked,
    this.notes,
    this.lat,
    this.long,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    // Parse date - convert from ISO to simple date
    String parseDate(String dateStr) {
      try {
        if (dateStr.contains('T')) {
          final dateTime = DateTime.parse(dateStr);
          return DateFormat('yyyy-MM-dd').format(dateTime);
        }
        return dateStr;
      } catch (e) {
        return dateStr;
      }
    }

    // Parse time - extract HH:mm from the weird Google Sheets format
    String? parseTime(String? timeStr) {
      if (timeStr == null) return null;
      try {
        if (timeStr.contains('T')) {
          final dateTime = DateTime.parse(timeStr);
          // Check if it's a Google Sheets time-only value (year 1899)
          if (dateTime.year == 1899) {
            return DateFormat('HH:mm').format(dateTime);
          } else {
            return DateFormat('HH:mm').format(dateTime);
          }
        }
        return timeStr;
      } catch (e) {
        return timeStr;
      }
    }

    // Parse hours worked - handle the weird format
    String? parseHoursWorked(String? hoursWorked) {
      if (hoursWorked == null) return null;
      try {
        if (hoursWorked.contains('T')) {
          final dateTime = DateTime.parse(hoursWorked);
          // Extract hours and minutes
          final hours = dateTime.hour;
          final minutes = dateTime.minute;
          return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
        }
        return hoursWorked;
      } catch (e) {
        return hoursWorked;
      }
    }

    return AttendanceRecord(
      staffId: json['Staff ID']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
      date: parseDate(json['Date']?.toString() ?? ''),
      firstInTime: parseTime(json['Actual In']?.toString()),
      lastOutTime: parseTime(json['Actual Out']?.toString()),
      shiftStart: parseTime(json['Shift Start']?.toString()),
      shiftEnd: parseTime(json['Shift End']?.toString()),
      status: json['Status']?.toString() ?? 'Unknown',
      hoursWorked: parseHoursWorked(json['Hours Worked']?.toString()),
      notes: json['Notes']?.toString(),
      lat: (json['Lat'] is num) ? (json['Lat'] as num).toDouble() : null,
      long: (json['Long'] is num) ? (json['Long'] as num).toDouble() : null,
    );
  }

  // For debugging
  @override
  String toString() {
    return 'AttendanceRecord{date: $date, status: $status, in: $firstInTime, out: $lastOutTime, hours: $hoursWorked}';
  }
}

class AttendanceLog {
  final DateTime timestamp;
  final String date;
  final String staffId;
  final String name;
  final String action;
  final String time;
  final double? latitude;
  final double? longitude;
  final String? notes;

  AttendanceLog({
    required this.timestamp,
    required this.date,
    required this.staffId,
    required this.name,
    required this.action,
    required this.time,
    this.latitude,
    this.longitude,
    this.notes,
  });

  factory AttendanceLog.fromJson(Map<String, dynamic> json) {
    // Parse timestamp
    DateTime parseTimestamp(String? timestampStr) {
      try {
        if (timestampStr != null && timestampStr.contains('T')) {
          return DateTime.parse(timestampStr);
        }
      } catch (e) {
        print('Error parsing timestamp: $e');
      }
      return DateTime.now();
    }

    // Parse date - convert from ISO to simple date
    String parseDate(String? dateStr) {
      if (dateStr == null) return '';
      try {
        if (dateStr.contains('T')) {
          final dateTime = DateTime.parse(dateStr);
          return DateFormat('yyyy-MM-dd').format(dateTime);
        }
        return dateStr;
      } catch (e) {
        return dateStr;
      }
    }

    // Parse time - extract HH:mm from the weird Google Sheets format
    String parseTime(String? timeStr) {
      if (timeStr == null) return '';
      try {
        if (timeStr.contains('T')) {
          final dateTime = DateTime.parse(timeStr);
          return DateFormat('HH:mm').format(dateTime);
        }
        return timeStr;
      } catch (e) {
        return timeStr;
      }
    }

    return AttendanceLog(
      timestamp: parseTimestamp(json['Timestamp']?.toString()),
      date: parseDate(json['Date']?.toString()),
      staffId: json['Staff ID']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
      action: json['Action']?.toString() ?? '',
      time: parseTime(json['Time']?.toString()),
      latitude: (json['Latitude'] is num) ? (json['Latitude'] as num).toDouble() : null,
      longitude: (json['Longitude'] is num) ? (json['Longitude'] as num).toDouble() : null,
      notes: json['Notes']?.toString(),
    );
  }

  // For debugging
  @override
  String toString() {
    return 'AttendanceLog{date: $date, action: $action, time: $time, notes: $notes}';
  }
}

// Keep the rest of your classes unchanged...
class AttendancePagination {
  final int currentPage;
  final int limit;
  final int offset;
  final int recordsOnPage;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;
  final int? nextPage;
  final int? prevPage;

  AttendancePagination({
    required this.currentPage,
    required this.limit,
    required this.offset,
    required this.recordsOnPage,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
    this.nextPage,
    this.prevPage,
  });

  factory AttendancePagination.fromJson(Map<String, dynamic> json) {
    return AttendancePagination(
      currentPage: json['currentPage'] ?? 1,
      limit: json['limit'] ?? 50,
      offset: json['offset'] ?? 0,
      recordsOnPage: json['recordsOnPage'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
      hasNextPage: json['hasNextPage'] ?? false,
      hasPrevPage: json['hasPrevPage'] ?? false,
      nextPage: json['nextPage'],
      prevPage: json['prevPage'],
    );
  }
}

class AttendanceResponse {
  final int dailyAttendanceCount;
  final int attendanceLogCount;
  final Map<String, dynamic> filters;
  final List<AttendanceRecord> dailyAttendance;
  final List<AttendanceLog> attendanceLog;
  final AttendancePagination dailyPagination;
  final AttendancePagination logPagination;

  AttendanceResponse({
    required this.dailyAttendanceCount,
    required this.attendanceLogCount,
    required this.filters,
    required this.dailyAttendance,
    required this.attendanceLog,
    required this.dailyPagination,
    required this.logPagination,
  });

  factory AttendanceResponse.fromJson(Map<String, dynamic> json) {
    try {
      // Parse summary
      final summary = json['summary'] ?? {};
      final dailyAttendanceCount = summary['dailyAttendanceCount'] ?? 0;
      final attendanceLogCount = summary['attendanceLogCount'] ?? 0;
      final filters = summary['filters'] ?? {};

      // Parse daily attendance
      List<AttendanceRecord> dailyAttendance = [];
      final dailyData = json['data']?['dailyAttendance']?['records'];
      if (dailyData is List) {
        print('📊 Parsing ${dailyData.length} daily records...');
        for (var item in dailyData) {
          try {
            final record = AttendanceRecord.fromJson(item);
            print('  ✅ ${record.date}: ${record.firstInTime} - ${record.lastOutTime}');
            dailyAttendance.add(record);
          } catch (e) {
            print('  ❌ Error parsing attendance record: $e');
            print('     Item: $item');
          }
        }
      }

      // Parse attendance log
      List<AttendanceLog> attendanceLog = [];
      final logData = json['data']?['attendanceLog']?['records'];
      if (logData is List) {
        print('📊 Parsing ${logData.length} log records...');
        for (var item in logData) {
          try {
            final log = AttendanceLog.fromJson(item);
            print('  ✅ ${log.date} ${log.action} at ${log.time}');
            attendanceLog.add(log);
          } catch (e) {
            print('  ❌ Error parsing log record: $e');
            print('     Item: $item');
          }
        }
      }

      // Parse pagination
      final pagination = json['pagination'] ?? {};
      final dailyPagination = AttendancePagination.fromJson(pagination['dailyAttendance'] ?? {});
      final logPagination = AttendancePagination.fromJson(pagination['attendanceLog'] ?? {});

      print('🎉 Successfully parsed ${dailyAttendance.length} daily records and ${attendanceLog.length} log records');

      return AttendanceResponse(
        dailyAttendanceCount: dailyAttendanceCount,
        attendanceLogCount: attendanceLogCount,
        filters: Map<String, dynamic>.from(filters),
        dailyAttendance: dailyAttendance,
        attendanceLog: attendanceLog,
        dailyPagination: dailyPagination,
        logPagination: logPagination,
      );
    } catch (e) {
      print('❌ Error parsing AttendanceResponse: $e');
      print('📄 JSON keys: ${json.keys.toList()}');
      rethrow;
    }
  }
}

// PunchResult and StaffInfo remain the same...
class PunchResult {
  final String staffId;
  final String name;
  final String action;
  final String time;
  final String date;
  final String? status;
  final String? firstInTime;
  final String? lastOutTime;
  final String? hoursWorked;

  PunchResult({
    required this.staffId,
    required this.name,
    required this.action,
    required this.time,
    required this.date,
    this.status,
    this.firstInTime,
    this.lastOutTime,
    this.hoursWorked,
  });

  factory PunchResult.fromJson(Map<String, dynamic> json) {
    return PunchResult(
      staffId: json['staffId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      status: json['status']?.toString(),
      firstInTime: json['firstInTime']?.toString(),
      lastOutTime: json['lastOutTime']?.toString(),
      hoursWorked: json['hoursWorked']?.toString(),
    );
  }
}

class StaffInfo {
  final String staffId;
  final String name;
  final String? position;
  final String status;
  final String? shiftStart;
  final String? shiftEnd;
  final bool isActive;
  final bool found;

  StaffInfo({
    required this.staffId,
    required this.name,
    this.position,
    required this.status,
    this.shiftStart,
    this.shiftEnd,
    required this.isActive,
    required this.found,
  });

  factory StaffInfo.fromJson(Map<String, dynamic> json) {
    return StaffInfo(
      staffId: json['staffId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      position: json['position']?.toString(),
      status: json['status']?.toString() ?? 'Unknown',
      shiftStart: json['shiftStart']?.toString(),
      shiftEnd: json['shiftEnd']?.toString(),
      isActive: json['active'] ?? false,
      found: json['found'] ?? false,
    );
  }
}