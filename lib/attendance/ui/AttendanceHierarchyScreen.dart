// attendance_hierarchy_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_inventory/attendance/ui/model_class/ApiServiceAttendance.dart';

import 'model_class/AttendanceRecord.dart';


class AttendanceHierarchyScreen extends StatefulWidget {
  const AttendanceHierarchyScreen({Key? key}) : super(key: key);

  @override
  _AttendanceHierarchyScreenState createState() => _AttendanceHierarchyScreenState();
}

class _AttendanceHierarchyScreenState extends State<AttendanceHierarchyScreen> {
  late Future<AttendanceResponse> _attendanceFuture;
  final ApiServiceAttendance _apiService = ApiServiceAttendance();

  // Track expanded states
  final Map<String, bool> _expandedStaff = {};
  final Map<String, Map<String, bool>> _expandedDates = {};

  @override
  void initState() {
    super.initState();
    _attendanceFuture = _fetchAttendanceData();
  }

  Future<AttendanceResponse> _fetchAttendanceData() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final firstDayOfMonth = DateFormat('yyyy-MM-dd').format(
      DateTime(DateTime.now().year, DateTime.now().month, 1),
    );

    return await _apiService.getAttendancespecificStaff(
      startDate: firstDayOfMonth,
      endDate: today,
    );
  }

  void _onRefresh() {
    setState(() {
      _attendanceFuture = _fetchAttendanceData();
      _expandedStaff.clear();
      _expandedDates.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Attendance Hierarchy',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: _onRefresh,
          ),
        ],
      ),
      body: FutureBuilder<AttendanceResponse>(
        future: _attendanceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return _buildEmptyState();
          }

          final data = snapshot.data!;
          return _buildHierarchy(data);
        },
      ),
    );
  }

  Widget _buildHierarchy(AttendanceResponse data) {
    // Group attendance by staff
    final staffAttendance = <String, List<AttendanceRecord>>{};
    for (var record in data.dailyAttendance) {
      staffAttendance.putIfAbsent(record.staffId, () => []);
      staffAttendance[record.staffId]!.add(record);
    }

    // Group logs by staff and date
    final staffDateLogs = <String, Map<String, List<AttendanceLog>>>{};
    for (var log in data.attendanceLog) {
      if (!staffDateLogs.containsKey(log.staffId)) {
        staffDateLogs[log.staffId] = {};
      }
      if (!staffDateLogs[log.staffId]!.containsKey(log.date)) {
        staffDateLogs[log.staffId]![log.date] = [];
      }
      staffDateLogs[log.staffId]![log.date]!.add(log);
    }

    // Get staff info (name, shift from first record)
    final staffInfo = <String, Map<String, dynamic>>{};
    for (var entry in staffAttendance.entries) {
      final firstRecord = entry.value.first;
      staffInfo[entry.key] = {
        'name': firstRecord.name,
        'shiftStart': firstRecord.shiftStart,
        'shiftEnd': firstRecord.shiftEnd,
      };
    }

    final staffIds = staffAttendance.keys.toList()
      ..sort((a, b) => staffInfo[a]!['name'].compareTo(staffInfo[b]!['name']));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: staffIds.length,
      itemBuilder: (context, staffIndex) {
        final staffId = staffIds[staffIndex];
        final info = staffInfo[staffId]!;
        final staffRecords = staffAttendance[staffId]!;
        final dateLogs = staffDateLogs[staffId] ?? {};
        final isStaffExpanded = _expandedStaff[staffId] ?? false;

        return _buildStaffLevel(
          staffId: staffId,
          name: info['name'],
          shiftStart: info['shiftStart'],
          shiftEnd: info['shiftEnd'],
          records: staffRecords,
          dateLogs: dateLogs,
          isStaffExpanded: isStaffExpanded,
        );
      },
    );
  }

  Widget _buildStaffLevel({
    required String staffId,
    required String name,
    required String? shiftStart,
    required String? shiftEnd,
    required List<AttendanceRecord> records,
    required Map<String, List<AttendanceLog>> dateLogs,
    required bool isStaffExpanded,
  }) {
    // Group records by date
    final recordsByDate = <String, List<AttendanceRecord>>{};
    for (var record in records) {
      recordsByDate.putIfAbsent(record.date, () => []);
      recordsByDate[record.date]!.add(record);
    }

    final dates = recordsByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Most recent first

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Level 1: Staff Info (Always visible)
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getStaffColor(staffId),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staffId,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (shiftStart != null && shiftEnd != null)
                  Text(
                    'Shift: ${_formatTime(shiftStart)} - ${_formatTime(shiftEnd)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${records.length} days',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isStaffExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey[500],
                ),
              ],
            ),
            onTap: () {
              setState(() {
                _expandedStaff[staffId] = !isStaffExpanded;
              });
            },
          ),

          // Level 2: Dates (Expanded when staff is expanded)
          if (isStaffExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: Column(
                children: dates.map((date) {
                  final dateRecords = recordsByDate[date]!;
                  final dateLogsForDate = dateLogs[date] ?? [];
                  final isDateExpanded = _expandedDates[staffId]?[date] ?? false;

                  // Use first record for status and hours
                  final firstRecord = dateRecords.first;

                  return _buildDateLevel(
                    staffId: staffId,
                    date: date,
                    status: firstRecord.status,
                    hoursWorked: firstRecord.hoursWorked,
                    firstInTime: firstRecord.firstInTime,
                    lastOutTime: firstRecord.lastOutTime,
                    logsCount: dateLogsForDate.length,
                    isDateExpanded: isDateExpanded,
                    logs: dateLogsForDate,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateLevel({
    required String staffId,
    required String date,
    required String status,
    required String? hoursWorked,
    required String? firstInTime,
    required String? lastOutTime,
    required int logsCount,
    required bool isDateExpanded,
    required List<AttendanceLog> logs,
  }) {
    Color statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey, width: 1),
      ),
      child: Column(
        children: [
          // Level 2: Date Info (Always visible when parent expanded)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _getDayOfMonth(date),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      _getMonthAbbr(date),
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (firstInTime != null && lastOutTime != null)
                  Text(
                    '${_formatTime(firstInTime)} - ${_formatTime(lastOutTime)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Hours: ${hoursWorked ?? "0:00"}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Text(
                    '$logsCount logs',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            trailing: Icon(
              isDateExpanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: Colors.grey[500],
            ),
            onTap: () {
              setState(() {
                if (!_expandedDates.containsKey(staffId)) {
                  _expandedDates[staffId] = {};
                }
                _expandedDates[staffId]![date] = !isDateExpanded;
              });
            },
          ),

          // Level 3: Attendance Logs (Expanded when date is expanded)
          if (isDateExpanded && logs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
              child: Column(
                children: logs.map((log) => _buildLogLevel(log)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogLevel(AttendanceLog log) {
    final isIn = log.action.toUpperCase() == 'IN';
    final time = DateFormat('hh:mm a').format(log.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey),
      ),
      child: Row(
        children: [
          // Action indicator
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isIn ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isIn ? Colors.green : Colors.red,
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                isIn ? Icons.login : Icons.logout,
                size: 12,
                color: isIn ? Colors.green : Colors.red,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Log details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isIn ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        log.action,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isIn ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                if (log.notes != null && log.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      log.notes!,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (log.latitude != null && log.longitude != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 10, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${log.latitude!.toStringAsFixed(4)}, ${log.longitude!.toStringAsFixed(4)}',
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Color _getStaffColor(String staffId) {
    final hash = staffId.hashCode;
    final hue = hash % 360;
    return HSVColor.fromAHSV(1.0, hue.toDouble(), 0.7, 0.8).toColor();
  }

  String _formatTime(String timeStr) {
    try {
      if (timeStr.length >= 5) return timeStr.substring(0, 5);
      return timeStr;
    } catch (e) {
      return timeStr;
    }
  }

  String _getDayOfMonth(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return date.day.toString();
    } catch (e) {
      return '--';
    }
  }

  String _getMonthAbbr(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM').format(date).toUpperCase();
    } catch (e) {
      return '---';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present': return Colors.green;
      case 'late': return Colors.orange;
      case 'absent': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading attendance data...',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
          const SizedBox(height: 16),
          const Text(
            'Failed to load data',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _onRefresh,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No attendance data available',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}