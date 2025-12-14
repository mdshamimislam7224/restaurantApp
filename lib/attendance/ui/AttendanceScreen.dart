import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../Location/LocationService.dart';
import '../../alertDialog/customDialog.dart';
import 'PunchButton.dart';
import 'model_class/ApiServiceAttendance.dart';
import 'model_class/AttendanceRecord.dart';
import 'FilterScreen.dart';

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
  // Services
  final LocationService _locationService = LocationService();
  final ApiServiceAttendance _apiService = ApiServiceAttendance();
  customDialog? customdialog;

  // Location
  String? latitude;
  String? longitude;

  // UI State
  bool _isLoading = false;
  bool _isPunching = false;
  bool _isLoadingMore = false;
  String _errorMessage = '';

  // Attendance Data
  AttendanceResponse? _attendanceResponse;
  final List<AttendanceRecord> _dailyAttendanceList = [];
  final Map<String, List<AttendanceLog>> _attendanceLogsMap = {};
  final Map<String, bool> _expandedStates = {};

  // Pagination
  int _currentPage = 1;
  final int _pageSize = 2;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();

  // Filter State
  Map<String, dynamic> _filters = {
    'startDate': null,
    'endDate': null,
    'staffId': null,
  };
  bool _hasFilters = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      customdialog = customDialog(context);
      customdialog!.showLoading("Checking permissions...");

      Future.microtask(() async {
        final allGranted = await _checkPermissions();
        if (allGranted) {
          await _getCurrentLocation();
        } else {
          customdialog?.dismiss();
          customdialog!.showError("Error", "Please grant all permissions to use this app.");
        }
      });
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100 &&
          _hasMoreData &&
          !_isLoadingMore &&
          !_isLoading) {
        _loadMoreAttendance();
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      await _requestLocationPermission();
      await _startLocationService();
    } catch (e) {
      print("Location error: $e");
      customdialog?.dismiss();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to get location: $e")),
      );
    }
  }

  Future<void> _requestLocationPermission() async {
    if (await Permission.location.isDenied) {
      await Permission.location.request();
    }
  }

  Future<void> _startLocationService() async {
    await _locationService.startLocationUpdates(
      context,
      onSuccess: (locationData) {
        if (locationData.latitude != null && locationData.longitude != null) {
          setState(() {
            latitude = locationData.latitude.toString();
            longitude = locationData.longitude.toString();
          });
          print("Location: $latitude, $longitude");
          _locationService.stopLocationUpdates();
          customdialog?.dismiss();
          _loadAttendanceData();
        }
      },
    );
  }

  Future<void> _loadAttendanceData({bool reset = true}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _dailyAttendanceList.clear();
        _attendanceLogsMap.clear();
        _expandedStates.clear();
        _hasMoreData = true;
        _errorMessage = '';
      });
    }

    try {
      final response = await _apiService.getAttendancespecificStaff(
        staffId: _filters['staffId'] ?? widget.staffId,
        startDate: _getFormattedStartDate(),
        endDate: _getFormattedEndDate(),
        dailyPage: _currentPage,
        dailyLimit: _pageSize,
        logPage: 1,
        logLimit: 2,
      );

      _processAttendanceResponse(response, reset: reset);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load attendance: ${e.toString()}';
        _hasMoreData = false;
      });
      print("Load error: $e");
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreAttendance() async {
    if (!_hasMoreData || _isLoadingMore || _isLoading) return;

    setState(() {
      _isLoadingMore = true;
    });

    _currentPage++;
    await _loadAttendanceData(reset: false);
  }

  void _processAttendanceResponse(AttendanceResponse response, {required bool reset}) {
    if (reset) {
      _dailyAttendanceList.clear();
      _attendanceLogsMap.clear();
    }

    // Add new daily attendance records
    _dailyAttendanceList.addAll(response.dailyAttendance);

    // Cache logs for each date
    for (var date in response.dailyAttendance.map((e) => e.date)) {
      _expandedStates[date] = false;

      if (!_attendanceLogsMap.containsKey(date)) {
        final logs = response.attendanceLog
            .where((log) => log.date == date)
            .toList();
        _attendanceLogsMap[date] = logs;
      }
    }

    // Check if we have more data to load
    if (response.dailyAttendance.length < _pageSize) {
      _hasMoreData = false;
    }

    setState(() {
      _attendanceResponse = response;
    });
  }

  List<AttendanceLog> _getLogsForDate(String date) {
    return _attendanceLogsMap[date] ?? [];
  }

  String _getFormattedStartDate() {
    if (_filters['startDate'] != null) {
      return DateFormat('yyyy-MM-dd').format(
        DateTime.parse(_filters['startDate']),
      );
    }
    final today = DateTime.now();
    return DateFormat('yyyy-MM-dd').format(
      DateTime(today.year, today.month, 1),
    );
  }

  String _getFormattedEndDate() {
    if (_filters['endDate'] != null) {
      return DateFormat('yyyy-MM-dd').format(
        DateTime.parse(_filters['endDate']),
      );
    }
    final today = DateTime.now();
    return DateFormat('yyyy-MM-dd').format(
      DateTime(today.year, today.month + 1, 0),
    );
  }

  Future<void> _punchAttendance(String action) async {
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location not available")),
      );
      return;
    }

    setState(() {
      _isPunching = true;
    });

    try {
      await _apiService.punchAttendance(
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
        _filters = result;
        _hasFilters = result['startDate'] != null ||
            result['endDate'] != null ||
            (result['staffId'] != null && result['staffId'] != widget.staffId);
      });
      await _loadAttendanceData();
    }
  }

  void _clearFilters() {
    setState(() {
      _filters = {
        'startDate': null,
        'endDate': null,
        'staffId': widget.staffId,
      };
      _hasFilters = false;
    });
    _loadAttendanceData();
  }

  String _getDateRangeText() {
    final start = _filters['startDate'] != null
        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(_filters['startDate']))
        : DateFormat('MMM dd, yyyy').format(DateTime(DateTime.now().year, DateTime.now().month, 1));

    final end = _filters['endDate'] != null
        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(_filters['endDate']))
        : DateFormat('MMM dd, yyyy').format(DateTime(DateTime.now().year, DateTime.now().month + 1, 0));

    String staffText = '';
    if (_filters['staffId'] != null && _filters['staffId'] != widget.staffId) {
      staffText = ' (Staff: ${_filters['staffId']})';
    }

    return '$start - $end$staffText';
  }

  Widget _buildAttendanceRecord(AttendanceRecord record) {
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
          _buildDailyAttendanceHeader(record, isExpanded),
          if (isExpanded) _buildAttendanceLogsSection(record.date, logs),
        ],
      ),
    );
  }

  Widget _buildDailyAttendanceHeader(AttendanceRecord record, bool isExpanded) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedStates[record.date] = !isExpanded;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildStatusChip(record.status),
                      const SizedBox(width: 8),
                      Text(
                        record.date,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                  if (record.hoursWorked != null && record.hoursWorked!.isNotEmpty)
                    _buildWorkedHours(record.hoursWorked!),
                  if (record.firstInTime != null || record.lastOutTime != null)
                    _buildTimeInfo(record.firstInTime, record.lastOutTime),
                ],
              ),
            ),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: const Color(0xFF666666),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildWorkedHours(String hoursWorked) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            size: 14,
            color: Colors.blue.shade600,
          ),
          const SizedBox(width: 6),
          Text(
            'Worked Hours: $hoursWorked',
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(String? firstInTime, String? lastOutTime) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (firstInTime != null)
            _buildTimeItem(Icons.login, 'In: $firstInTime', Colors.green),
          if (lastOutTime != null)
            _buildTimeItem(Icons.logout, 'Out: $lastOutTime', Colors.red),
        ],
      ),
    );
  }

  Widget _buildTimeItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildAttendanceLogsSection(String date, List<AttendanceLog> logs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLogsHeader(logs.length),
          const SizedBox(height: 12),
          if (logs.isEmpty)
            _buildNoLogsMessage()
          else
            Column(children: logs.map(_buildLogItem).toList()),
        ],
      ),
    );
  }

  Widget _buildLogsHeader(int logCount) {
    return Row(
      children: [
        Icon(Icons.history, size: 16, color: Colors.grey.shade600),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            logCount.toString(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1976D2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoLogsMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          'No detailed logs available',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
      ),
    );
  }

  Widget _buildLogItem(AttendanceLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLogAvatar(log.action),
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
                        color: log.action == 'IN' ? Colors.green : Colors.red,
                      ),
                    ),
                    Text(log.time, style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    )),
                  ],
                ),
                if (log.notes != null && log.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      log.notes!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('MMM dd, yyyy hh:mm a').format(log.timestamp),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogAvatar(String action) {
    final isIn = action == 'IN';
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: isIn ? Colors.green.shade50 : Colors.red.shade50,
        shape: BoxShape.circle,
        border: Border.all(
          color: isIn ? Colors.green.shade200 : Colors.red.shade200,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          action.substring(0, 1),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isIn ? Colors.green : Colors.red,
          ),
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
          Text(label, style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF1976D2),
          )),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              if (label.startsWith('From:')) {
                setState(() => _filters.remove('startDate'));
              } else if (label.startsWith('To:')) {
                setState(() => _filters.remove('endDate'));
              } else if (label.startsWith('Staff:')) {
                setState(() => _filters['staffId'] = widget.staffId);
              }
              _loadAttendanceData();
            },
            child: const Icon(Icons.close, size: 14, color: Color(0xFF1976D2)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    return switch (statusLower) {
      'present' => Colors.green.withOpacity(0.3),
      'late' => Colors.orange.withOpacity(0.3),
      'absent' => Colors.red.withOpacity(0.3),
      'early' => Colors.blue.withOpacity(0.3),
      'half day' => Colors.purple.withOpacity(0.3),
      _ => Colors.grey.withOpacity(0.3),
    };
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (_hasFilters) _buildFilterChips(),
            _buildPunchButtons(),
            _buildAttendanceList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
                    _buildActionButtons(),
                  ],
                ),
                const SizedBox(height: 8),
                _buildDateRangeInfo(),
                const SizedBox(height: 8),
                _buildLocationInfo(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Text("Filter:", style: TextStyle(
          color: Colors.black.withOpacity(0.8),
          fontSize: 14,
        )),
        IconButton(
          onPressed: _openFilterScreen,
          icon: Stack(
            children: [
              const Icon(Icons.filter_list, color: Colors.black, size: 24),
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
                    constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: _loadAttendanceData,
          icon: const Icon(Icons.refresh, color: Colors.black, size: 20),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildDateRangeInfo() {
    return Row(
      children: [
        Icon(Icons.calendar_today, color: Colors.black.withOpacity(0.8), size: 16),
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
    );
  }

  Widget _buildLocationInfo() {
    return Row(
      children: [
        Icon(Icons.location_on, color: Colors.black.withOpacity(0.8), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            latitude != null && longitude != null
                ? 'Lat: ${double.parse(latitude!).toStringAsFixed(4)}, Lng: ${double.parse(longitude!).toStringAsFixed(4)}'
                : 'Getting location...',
            style: TextStyle(
              color: Colors.black.withOpacity(0.8),
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Filters:', style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          )),
          const SizedBox(width: 8),
          Wrap(
            spacing: 8,
            children: [
              if (_filters['startDate'] != null)
                _buildFilterChip('From: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(_filters['startDate']))}'),
              if (_filters['endDate'] != null)
                _buildFilterChip('To: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(_filters['endDate']))}'),
              if (_filters['staffId'] != null && _filters['staffId'] != widget.staffId)
                _buildFilterChip('Staff: ${_filters['staffId']}'),
              _buildClearAllButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClearAllButton() {
    return InkWell(
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
            Text('Clear All', style: TextStyle(
              fontSize: 12,
              color: Colors.red,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildPunchButtons() {
    return Padding(
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
    );
  }

  Widget _buildAttendanceList() {
    return Expanded(
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          if (scrollNotification is ScrollEndNotification &&
              _scrollController.position.extentAfter == 0 &&
              _hasMoreData &&
              !_isLoadingMore &&
              !_isLoading) {
            _loadMoreAttendance();
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadAttendanceData();
          },
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: _buildAttendanceHeader(),
              ),
              if (_isLoading && _dailyAttendanceList.isEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(),
                  ),
                ),
              if (_dailyAttendanceList.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      if (index < _dailyAttendanceList.length) {
                        return _buildAttendanceRecord(_dailyAttendanceList[index]);
                      }
                      return null;
                    },
                    childCount: _dailyAttendanceList.length,
                  ),
                ),
              if (_isLoadingMore)
                SliverToBoxAdapter(
                  child: _buildLoadingMoreIndicator(),
                ),
              if (!_hasMoreData && _dailyAttendanceList.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildNoMoreRecords(),
                ),
              if (_errorMessage.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildErrorMessage(),
                ),
              if (_dailyAttendanceList.isEmpty && !_isLoading)
                SliverToBoxAdapter(
                  child: _buildEmptyState(),
                ),
              SliverToBoxAdapter(
                child: SizedBox(height: _hasMoreData ? 50 : 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
              if (_dailyAttendanceList.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_dailyAttendanceList.length} records',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1976D2),
                    ),
                  ),
                ),
            ],
          ),
          if (_currentPage > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Page $_currentPage',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          const CircularProgressIndicator(strokeWidth: 2),
          const SizedBox(height: 8),
          Text(
            'Loading more...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMoreRecords() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: Text(
        'No more records',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
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
            child: Text(_errorMessage, style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
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
            style: const TextStyle(color: Colors.grey, fontSize: 16),
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
    );
  }
}