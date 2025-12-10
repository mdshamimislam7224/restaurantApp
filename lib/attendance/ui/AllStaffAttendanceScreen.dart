import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import 'AttendanceCard.dart';
import 'model_class/ApiServiceAttendance.dart';
import 'model_class/AttendanceRecord.dart';
import 'FilterScreen.dart'; // Import your filter screen

class AllStaffAttendanceScreen extends StatefulWidget {
  const AllStaffAttendanceScreen({super.key});

  @override
  State<AllStaffAttendanceScreen> createState() => _AllStaffAttendanceScreenState();
}

class _AllStaffAttendanceScreenState extends State<AllStaffAttendanceScreen> {
  final ApiServiceAttendance _apiService = ApiServiceAttendance();
  bool _isLoading = false;
  String _errorMessage = '';

  // Store attendance data
  AttendanceResponse? _attendanceResponse;

  // Track expanded states
  Map<String, bool> _expandedStates = {};

  // Group daily attendance by staff
  Map<String, List<AttendanceRecord>> _staffAttendanceMap = {};

  // Group logs by staff and date
  Map<String, Map<String, List<AttendanceLog>>> _staffLogsMap = {};

  // Filter state
  Map<String, dynamic> _filters = {};
  bool _hasFilters = false;

  @override
  void initState() {
    super.initState();
    // Initialize with current month
    final today = DateTime.now();
    _filters = {
      'startDate': DateFormat('yyyy-MM-dd').format(DateTime(today.year, today.month, 1)),
      'endDate': DateFormat('yyyy-MM-dd').format(DateTime(today.year, today.month + 1, 0)),
      'staffId': null, // null means all staff
    };
    _loadAllStaffAttendance();
  }

  Future<void> _loadAllStaffAttendance() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.getAllAttendance(
        startDate: _filters['startDate'],
        endDate: _filters['endDate'],
        dailyLimit: 50,
        logLimit: 100,
      );

      setState(() {
        _attendanceResponse = response;
        _organizeData(response);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load attendance: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _organizeData(AttendanceResponse response) {
    // Group daily attendance by staff ID
    final Map<String, List<AttendanceRecord>> staffMap = {};

    for (var record in response.dailyAttendance) {
      if (!staffMap.containsKey(record.staffId)) {
        staffMap[record.staffId] = [];
      }
      staffMap[record.staffId]!.add(record);

      // Initialize expanded state
      final key = '${record.staffId}_${record.date}';
      _expandedStates[key] = false;
    }

    // Group logs by staff ID and date
    final Map<String, Map<String, List<AttendanceLog>>> logsMap = {};

    for (var log in response.attendanceLog) {
      if (!logsMap.containsKey(log.staffId)) {
        logsMap[log.staffId] = {};
      }

      if (!logsMap[log.staffId]!.containsKey(log.date)) {
        logsMap[log.staffId]![log.date] = [];
      }

      logsMap[log.staffId]![log.date]!.add(log);
    }

    setState(() {
      _staffAttendanceMap = staffMap;
      _staffLogsMap = logsMap;
    });
  }

  // Get logs for a specific staff and date
  List<AttendanceLog> _getLogsForStaffAndDate(String staffId, String date) {
    return _staffLogsMap[staffId]?[date] ?? [];
  }

  void _toggleExpand(String staffId, String date) {
    final key = '${staffId}_$date';
    setState(() {
      _expandedStates[key] = !(_expandedStates[key] ?? false);
    });
  }

  // Open filter screen
  Future<void> _openFilterScreen() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => FilterScreen(
          initialStartDate: _filters['startDate'],
          initialEndDate: _filters['endDate'],
          staffId: _filters['staffId'] ?? '',
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _filters.addAll(result);
        _hasFilters = result.isNotEmpty;
      });
      await _loadAllStaffAttendance();
    }
  }

  // Clear all filters
  void _clearFilters() {
    setState(() {
      _filters = {
        'startDate': null,
        'endDate': null,
        'staffId': null,
      };
      _hasFilters = false;
    });
    _loadAllStaffAttendance();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('All Staff Attendance'),
        backgroundColor: const Color(0xFF4361EE),
        elevation: 0,
        actions: [
          // Filter button with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _openFilterScreen,
              ),
              if (_hasFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllStaffAttendance,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips (visible when filters are applied)
          if (_hasFilters)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Filters:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (_filters['startDate'] != null)
                        _buildFilterChip(
                          'From: ${_filters['startDate']}',
                        ),
                      if (_filters['endDate'] != null)
                        _buildFilterChip(
                          'To: ${_filters['endDate']}',
                        ),
                      if (_filters['staffId'] != null && _filters['staffId'] != '')
                        _buildFilterChip(
                          'Staff: ${_filters['staffId']}',
                        ),
                      InkWell(
                        onTap: _clearFilters,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.clear, size: 14, color: Colors.red),
                              SizedBox(width: 4),
                              Text(
                                'Clear All',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildAttendanceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1976D2),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              // Remove specific filter
              if (label.startsWith('From:')) {
                setState(() {
                  _filters.remove('startDate');
                });
              } else if (label.startsWith('To:')) {
                setState(() {
                  _filters.remove('endDate');
                });
              } else if (label.startsWith('Staff:')) {
                setState(() {
                  _filters.remove('staffId');
                });
              }
              _loadAllStaffAttendance();
            },
            child: const Icon(
              Icons.close,
              size: 14,
              color: Color(0xFF1976D2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList() {
    if (_staffAttendanceMap.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group,
              size: 64,
              color: Colors.grey.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _hasFilters
                  ? 'No attendance records for the selected filters'
                  : 'No attendance records found',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            if (_hasFilters)
              ElevatedButton(
                onPressed: _clearFilters,
                child: const Text('Clear Filters'),
              )
            else
              ElevatedButton(
                onPressed: _loadAllStaffAttendance,
                child: const Text('Refresh'),
              ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Summary card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF4361EE),
                  Color(0xFF3A0CA3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  _staffAttendanceMap.length.toString(),
                  'Staff',
                  Icons.group,
                  Colors.white,
                ),
                _buildSummaryItem(
                  _attendanceResponse?.dailyAttendance.length.toString() ?? '0',
                  'Records',
                  Icons.list_alt,
                  Colors.white,
                ),
                _buildSummaryItem(
                  _attendanceResponse?.attendanceLog.length.toString() ?? '0',
                  'Logs',
                  Icons.history,
                  Colors.white,
                ),
              ],
            ),
          ),

          // Attendance list by staff
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Staff Attendance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 12),
                ..._staffAttendanceMap.entries.map((entry) {
                  final staffId = entry.key;
                  final staffRecords = entry.value;

                  // Get staff name from first record
                  final staffName = staffRecords.isNotEmpty ? staffRecords.first.name : 'Unknown';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
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
                        // Staff header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.withOpacity(0.1),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4361EE).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Color(0xFF4361EE),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      staffName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                    Text(
                                      'ID: $staffId',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4361EE).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${staffRecords.length} days',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4361EE),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Staff attendance records
                        ...staffRecords.map((record) {
                          final isExpanded = _expandedStates['${staffId}_${record.date}'] ?? false;
                          final logs = _getLogsForStaffAndDate(staffId, record.date);

                          return Container(
                            margin: const EdgeInsets.all(0),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: Colors.grey.withOpacity(0.1),
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                // Daily record
                                GestureDetector(
                                  onTap: () => _toggleExpand(staffId, record.date),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Date and status
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: _getStatusColor(record.status),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      record.status,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    record.date,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF333333),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              if (record.firstInTime != null || record.lastOutTime != null)
                                                Row(
                                                  children: [
                                                    if (record.firstInTime != null)
                                                      Row(
                                                        children: [
                                                          const Icon(
                                                            Icons.login,
                                                            size: 14,
                                                            color: Colors.green,
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            record.firstInTime!,
                                                            style: const TextStyle(
                                                              fontSize: 12,
                                                              color: Colors.grey,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 12),
                                                        ],
                                                      ),
                                                    if (record.lastOutTime != null)
                                                      Row(
                                                        children: [
                                                          const Icon(
                                                            Icons.logout,
                                                            size: 14,
                                                            color: Colors.red,
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            record.lastOutTime!,
                                                            style: const TextStyle(
                                                              fontSize: 12,
                                                              color: Colors.grey,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                  ],
                                                ),
                                              if (record.hoursWorked != null && record.hoursWorked!.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Text(
                                                    'Hours: ${record.hoursWorked!}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.blue,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              if (logs.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Text(
                                                    '${logs.length} log${logs.length != 1 ? 's' : ''}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey.shade600,
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          isExpanded
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                          color: const Color(0xFF666666),
                                          size: 24,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Attendance logs (expanded)
                                if (isExpanded && logs.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Detailed Logs:',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF666666),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...logs.map((log) {
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8F9FA),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.grey.withOpacity(0.2),
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  width: 30,
                                                  height: 30,
                                                  decoration: BoxDecoration(
                                                    color: log.action == 'IN'
                                                        ? Colors.green.shade50
                                                        : Colors.red.shade50,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: log.action == 'IN'
                                                          ? Colors.green.shade200
                                                          : Colors.red.shade200,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      log.action.substring(0, 1),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        color: log.action == 'IN'
                                                            ? Colors.green
                                                            : Colors.red,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            log.action,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w600,
                                                              color: log.action == 'IN'
                                                                  ? Colors.green
                                                                  : Colors.red,
                                                            ),
                                                          ),
                                                          Text(
                                                            log.time,
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w600,
                                                              color: Color(0xFF333333),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      if (log.notes != null && log.notes!.isNotEmpty)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 4),
                                                          child: Text(
                                                            log.notes!,
                                                            style: const TextStyle(
                                                              fontSize: 12,
                                                              color: Colors.grey,
                                                            ),
                                                          ),
                                                        ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        DateFormat('MMM dd, yyyy hh:mm a')
                                                            .format(log.timestamp),
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      case 'early':
        return Colors.blue;
      case 'half day':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}