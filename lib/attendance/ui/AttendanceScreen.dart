import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../Location/LocationService.dart';
import '../../alertDialog/customDialog.dart';
import 'AttendanceCard.dart';
import 'PunchButton.dart';
import 'model_class/ApiServiceAttendance.dart';
import 'model_class/AttendanceRecord.dart';
import 'FilterScreen.dart'; // Make sure to import your FilterScreen

class AttendanceScreen extends StatefulWidget {
  final String staffId;
  final String staffName;

  const AttendanceScreen({
    super.key,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final LocationService _locationService = LocationService();
  String? latitude;
  String? longitude;
  int frameSkipCount = 0;
  int successCounter = 0;
  bool dataSendChecker = false;
  customDialog? customdialog;

  final ApiServiceAttendance _apiService = ApiServiceAttendance();
  bool _isLoading = false;
  bool _isPunching = false;
  Position? _currentPosition;
  String _errorMessage = '';

  // Store attendance data
  AttendanceResponse? _attendanceResponse;

  // Track expanded states for daily attendance records
  Map<String, bool> _expandedStates = {};

  // Filter state
  Map<String, dynamic> _filters = {
    'startDate': null,
    'endDate': null,
  };
  bool _hasFilters = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      customdialog = customDialog(context);
      customdialog!.showLoading("Checking permissions...");

    });

    Future.microtask(() async {
      final allGranted = await _checkPermissions();
      if (allGranted) {
        _getCurrentLocation();
      } else {
        customdialog?.dismiss();
        customdialog!.showError("Error", "Please grant all permissions to use this app.");
      }
    });
  }
  Future<void> _getCurrentLocation() async {
    final locationSuccess = await fetchLocation();
    if (locationSuccess) {
      _loadAttendanceData();
    } else {

    }
  }

  Future<bool> fetchLocation() async {
    int retryCount = 0;
    const int maxRetries = 12;
    const Duration retryDelay = Duration(seconds: 5);

    Future<bool> tryFetchLocation() async {
      try {
        await _requestLocationPermission();
        await _startLocationService();

        if (latitude != null && longitude != null) {
          _incrementSuccessCounter();
          return true;
        }

        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(retryDelay);
          return await tryFetchLocation();
        }
        return false;
      } catch (e) {
        print("Location fetching error: $e");
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(retryDelay);
          return await tryFetchLocation();
        }
        return false;
      }
    }

    return await tryFetchLocation();
  }
  Future<void> _requestLocationPermission() async {
    if (await Permission.location.isDenied) {
      await Permission.location.request();
    }
    _startLocationService();
  }
  Future<void> _startLocationService() async {
    await _locationService.startLocationUpdates(context, onSuccess: (locationData) {
      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          latitude = locationData.latitude.toString();
          longitude = locationData.longitude.toString();
        });
        print("latitude: $latitude, Longitude: $longitude");
        _locationService.stopLocationUpdates();

        if (!dataSendChecker && customdialog != null && Navigator.canPop(context)) {
          Future.delayed(Duration(milliseconds: 5), () {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                 customdialog?.dismiss();
              }
            });
          });
        }
      }
    });
  }
  void _incrementSuccessCounter() {
    successCounter++;
    if (successCounter == 2) {
      if (customdialog != null) {
        customdialog?.dismiss();
      }
    }
  }
  Future<void> _loadAttendanceData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Default to current month if no filters are set
      DateTime startDate;
      DateTime endDate;

      if (_filters['startDate'] != null && _filters['endDate'] != null) {
        startDate = DateTime.parse(_filters['startDate']);
        endDate = DateTime.parse(_filters['endDate']);
      } else {
        final today = DateTime.now();
        startDate = DateTime(today.year, today.month, 1);
        endDate = DateTime(today.year, today.month + 1, 0);
      }

      final response = await _apiService.getAttendancespecificStaff(
        staffId: widget.staffId,
        startDate: DateFormat('yyyy-MM-dd').format(startDate),
        endDate: DateFormat('yyyy-MM-dd').format(endDate),
        dailyLimit: 50,
        logLimit: 50,
      );
      setState(() {
        print("Attendance response:"+response.toString());
        _attendanceResponse = response;
        _expandedStates.clear(); // Clear previous states

        // Initialize expanded states
        for (var record in response.dailyAttendance) {
          _expandedStates[record.date] = false;
        }
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

  // Get attendance logs for a specific date
  List<AttendanceLog> _getLogsForDate(String date) {
    if (_attendanceResponse == null) return [];

    return _attendanceResponse!.attendanceLog
        .where((log) => log.date == date)
        .toList();
  }

  void _toggleExpand(String date) {
    setState(() {
      _expandedStates[date] = !(_expandedStates[date] ?? false);
    });
  }

  Future<void> _punchAttendance(String action) async {
    setState(() {
      _isPunching = true;
    });

    try {
      final result = await _apiService.punchAttendance(
        staffId: widget.staffId,
        action: action,
        latitude: double.parse(latitude!),
        longitude: double.parse(longitude!),
        notes: 'Punched from mobile app',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully ${action.toLowerCase()}ed!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Refresh attendance data
      await _loadAttendanceData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to punch: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isPunching = false;
      });
    }
  }

  // Open filter screen
  Future<void> _openFilterScreen() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => FilterScreen(
          initialStartDate: _filters['startDate'],
          initialEndDate: _filters['endDate'],
          staffId: widget.staffId,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _filters.addAll(result);
        _hasFilters = result.isNotEmpty;
      });
      await _loadAttendanceData();
    }
  }

  // Clear all filters
  void _clearFilters() {
    setState(() {
      _filters = {
        'startDate': null,
        'endDate': null,
      };
      _hasFilters = false;
    });
    _loadAttendanceData();
  }

  // Format date range for display
  String _getDateRangeText() {
    if (_filters['startDate'] != null && _filters['endDate'] != null) {
      final start = DateFormat('MMM dd, yyyy').format(DateTime.parse(_filters['startDate']));
      final end = DateFormat('MMM dd, yyyy').format(DateTime.parse(_filters['endDate']));
      return '$start - $end';
    }
    final today = DateTime.now();
    final start = DateFormat('MMM dd, yyyy').format(DateTime(today.year, today.month, 1));
    final end = DateFormat('MMM dd, yyyy').format(DateTime(today.year, today.month + 1, 0));
    return '$start - $end';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('h:mm a').format(DateTime.now()),
                                    style: TextStyle(
                                      color: Colors.black.withOpacity(0.8),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _loadAttendanceData,
                              icon: const Icon(
                                Icons.refresh,
                                color: Colors.black,
                                size: 20,
                              ),
                              tooltip: 'Refresh',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Colors.black.withOpacity(0.8),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getDateRangeText(),
                                style: TextStyle(
                                  color: Colors.black.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.black.withOpacity(0.8),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                    latitude != null && longitude != null ? 'Lat: ${double.parse(latitude!).toStringAsFixed(4)}, Lng: ${double.parse(longitude!).toStringAsFixed(4)}'
                                    : 'Getting location...',
                                style: TextStyle(
                                  color: Colors.black.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),



                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,

                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Filter button
                                IconButton(
                                  onPressed: _openFilterScreen,
                                  icon: Stack(
                                    children: [
                                      const Icon(
                                        Icons.filter_list,
                                        color: Colors.black,
                                        size: 24,
                                      ),
                                      if (_hasFilters)
                                        Positioned(
                                          right: 0,
                                          top: 0,
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
                                ),
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.black,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                      ],
                    ),
                  ),
                ],
              ),
            ),

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
                            'From: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(_filters['startDate']))}',
                          ),
                        if (_filters['endDate'] != null)
                          _buildFilterChip(
                            'To: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(_filters['endDate']))}',
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

            // Punch Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: PunchButton(
                      label: 'Clock In',
                      icon: Icons.login,
                      color: const Color(0xFF4CAF50),
                      isLoading: _isPunching,
                      onPressed: () => _punchAttendance('in'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PunchButton(
                      label: 'Clock Out',
                      icon: Icons.logout,
                      color: const Color(0xFFF44336),
                      isLoading: _isPunching,
                      onPressed: () => _punchAttendance('out'),
                    ),
                  ),
                ],
              ),
            ),
            // Recent Attendance with expandable logs
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Attendance Records",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        if (_attendanceResponse != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_attendanceResponse!.dailyAttendance.length} records',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 50),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_attendanceResponse != null &&
                        _attendanceResponse!.dailyAttendance.isNotEmpty)
                      Column(
                        children: _attendanceResponse!.dailyAttendance.map((record) {
                          final isExpanded = _expandedStates[record.date] ?? false;
                          final logs = _getLogsForDate(record.date);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: _getStatusColor(record.status),
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
                                // Daily Attendance Header
                                GestureDetector(
                                  onTap: () => _toggleExpand(record.date),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.center,
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
                                                      color: Color(0xFF333333),
                                                    ),
                                                  ),
                                                  if (record.hoursWorked != null &&
                                                      record.hoursWorked!.isNotEmpty)
                                                    const SizedBox(width: 8),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.access_time,
                                                          size: 14,
                                                          color: Colors.blue.shade600,
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          record.hoursWorked != null
                                                            ? 'Worked Hours: ${record.hoursWorked!}'
                                                            : '',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color: Colors.blue.shade600,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              ),

                                              const SizedBox(height: 8),
                                              if (record.firstInTime != null)
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.login,
                                                          size: 14,
                                                          color: Colors.green,
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          'In: ${record.firstInTime}',
                                                          style: const TextStyle(
                                                            fontSize: 13,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ],
                                                    ),

                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.logout,
                                                          size: 14,
                                                          color: Colors.red,
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          'Out: ${record.lastOutTime}',
                                                          style: const TextStyle(
                                                            fontSize: 13,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
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

                                // Attendance Logs (expanded section)
                                if (isExpanded)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F9FA),
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                                      border: Border(
                                        top: BorderSide(
                                          color: Colors.grey.withOpacity(0.1),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.history,
                                              size: 16,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'Attendance Logs',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF666666),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                logs.length.toString(),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1976D2),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        if (logs.isEmpty)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            child: Center(
                                              child: Text(
                                                'No detailed logs available',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          Column(
                                            children: logs.asMap().entries.map((entry) {
                                              final index = entry.key;
                                              final log = entry.value;
                                              final isLast = index == logs.length - 1;

                                              return Container(
                                                margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
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
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
                        child: Column(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 64,
                              color: Colors.grey.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _hasFilters
                                  ? 'No attendance records for selected date range'
                                  : 'No attendance records found',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Use the buttons above to clock in/out',
                              style: TextStyle(
                                color: Colors.grey.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                            if (_hasFilters)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: ElevatedButton(
                                  onPressed: _clearFilters,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4361EE),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Clear Filters'),
                                ),
                              ),
                          ],
                        ),
                      ),

                    if (_errorMessage.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
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
              }
              _loadAttendanceData();
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green.withOpacity(0.3);
      case 'late':
        return Colors.orange.withOpacity(0.3);
      case 'absent':
        return Colors.red.withOpacity(0.3);
      case 'early':
        return Colors.blue.withOpacity(0.3);
      case 'half day':
        return Colors.purple.withOpacity(0.3);
      default:
        return Colors.grey.withOpacity(0.3);
    }
  }

  Future<bool> _checkPermissions() async {
    try {
      final List<Permission> permissions = [
        Permission.camera,
        Permission.location,
      ];

      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          permissions.addAll([
            Permission.photos,
            Permission.videos,
          ]);
        } else {
          permissions.add(Permission.storage);
        }
      } else if (Platform.isIOS) {
        permissions.add(Permission.photos);
      }

      for (var permission in permissions) {
        final status = await permission.status;
        if (status.isDenied || status.isPermanentlyDenied) {
          final result = await permission.request();
          if (!result.isGranted) {
            return false;
          }
        }
      }

      return true;
    } catch (e) {
      print("Permission check error: $e");
      return false;
    }
  }
}