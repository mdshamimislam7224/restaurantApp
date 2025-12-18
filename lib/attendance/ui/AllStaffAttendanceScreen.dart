// all_staff_attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_inventory/attendance/ui/model_class/ApiServiceAttendance.dart';
import 'package:url_launcher/url_launcher.dart';

import 'model_class/AttendanceRecord.dart';

class AllStaffAttendanceScreen extends StatefulWidget {
  const AllStaffAttendanceScreen({Key? key}) : super(key: key);

  @override
  _AllStaffAttendanceScreenState createState() => _AllStaffAttendanceScreenState();
}

class _AllStaffAttendanceScreenState extends State<AllStaffAttendanceScreen> {
  late Future<AttendanceResponse> _attendanceFuture;
  final ApiServiceAttendance _apiService = ApiServiceAttendance();

  // Search and filter variables
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showFilters = false;
  bool _isPunching = false;
  String? _currentPunchingStaffId; // Track which staff is being punched

  // Pagination variables
  int _dailyCurrentPage = 1;
  int _logCurrentPage = 1;
  final int _dailyLimit =30;
  final int _logLimit = 100;
  bool _hasMoreDaily = true;
  bool _hasMoreLog = true;
  bool _isLoadingMore = false;

  // Track expanded states PER STAFF
  final Map<String, bool> _expandedStaff = {};
  final Map<String, Map<String, bool>> _expandedDates = {};

  // Data storage
  List<AttendanceRecord> _allDailyRecords = [];
  List<AttendanceLog> _allLogRecords = [];
  AttendanceResponse? _currentResponse;

  // Current location
  double? _currentLatitude;
  double? _currentLongitude;

  @override
  void initState() {
    super.initState();
    // Set default date range to current month
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;
    _attendanceFuture = _fetchAttendanceData();
  }

  Future<AttendanceResponse> _fetchAttendanceData({bool loadMore = false}) async {
    try {
      if (!loadMore) {
        _dailyCurrentPage = 1;
        _logCurrentPage = 1;
        _allDailyRecords.clear();
        _allLogRecords.clear();
      }

      final response = await _apiService.getAttendancespecificStaff(
        startDate: _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null,
        endDate: _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
        dailyPage: _dailyCurrentPage,
        logPage: _logCurrentPage,
        dailyLimit: _dailyLimit,
        logLimit: _logLimit,
      );

      if (loadMore) {
        // Append new data
        _allDailyRecords.addAll(response.dailyAttendance);
        _allLogRecords.addAll(response.attendanceLog);

        // Update pagination flags
        _hasMoreDaily = response.dailyPagination.hasNextPage;
        _hasMoreLog = response.logPagination.hasNextPage;

        // Create updated response with combined data
        return AttendanceResponse(
          dailyAttendanceCount: response.dailyAttendanceCount,
          attendanceLogCount: response.attendanceLogCount,
          filters: response.filters,
          dailyAttendance: List.from(_allDailyRecords),
          attendanceLog: List.from(_allLogRecords),
          dailyPagination: response.dailyPagination,
          logPagination: response.logPagination,
        );
      } else {
        // First load
        _allDailyRecords = response.dailyAttendance;
        _allLogRecords = response.attendanceLog;
        _hasMoreDaily = response.dailyPagination.hasNextPage;
        _hasMoreLog = response.logPagination.hasNextPage;
        return response;
      }
    } catch (e) {
      print('Error fetching data: $e');
      rethrow;
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || (!_hasMoreDaily && !_hasMoreLog)) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _dailyCurrentPage++;
      _logCurrentPage++;

      final response = await _fetchAttendanceData(loadMore: true);

      setState(() {
        _currentResponse = response;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
        _dailyCurrentPage--;
        _logCurrentPage--;
      });
      print('Error loading more data: $e');
    }
  }

  void _onRefresh() {
    setState(() {
      _attendanceFuture = _fetchAttendanceData();
      _expandedStaff.clear();
      _expandedDates.clear();
    });
  }

  void _applyFilters() {
    setState(() {
      _showFilters = false;
      _attendanceFuture = _fetchAttendanceData();
      _expandedStaff.clear();
      _expandedDates.clear();
    });
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      final now = DateTime.now();
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = now;
      _showFilters = false;
      _attendanceFuture = _fetchAttendanceData();
      _expandedStaff.clear();
      _expandedDates.clear();
    });
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // TextField with flexible width
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by name or ID...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF64748B)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Filter button
                IconButton(
                  icon: Icon(
                    _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                    color: _showFilters ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
                  ),
                  onPressed: () {
                    setState(() {
                      _showFilters = !_showFilters;
                    });
                  },
                ),

                // Refresh button
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF4F46E5)),
                  onPressed: _onRefresh,
                ),
              ],
            ),
          ),
          // Filters Panel
          if (_showFilters)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                children: [
                  // Date Range Selection
                  const Row(
                    children: [
                      Icon(Icons.date_range, size: 18, color: Color(0xFF4F46E5)),
                      SizedBox(width: 8),
                      Text(
                        'Date Range',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'From',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => _selectStartDate(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                                    const SizedBox(width: 8),
                                    Text(
                                      _startDate != null
                                          ? DateFormat('dd/MM/yyyy').format(_startDate!)
                                          : 'Select date',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'To',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => _selectEndDate(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                                    const SizedBox(width: 8),
                                    Text(
                                      _endDate != null
                                          ? DateFormat('dd/MM/yyyy').format(_endDate!)
                                          : 'Select date',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Filter Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _applyFilters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check, size: 18),
                              SizedBox(width: 8),
                              Text('Apply Filters'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _clearFilters,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.clear, size: 18),
                              SizedBox(width: 8),
                              Text('Clear'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Main Content
          Expanded(
            child: FutureBuilder<AttendanceResponse>(
              future: _attendanceFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !_isLoadingMore) {
                  return _buildLoadingState();
                }
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }
                if (!snapshot.hasData) {
                  return _buildEmptyState();
                }
                final data = snapshot.data!;
                _currentResponse = data;
                return _buildHierarchy(data);
              },
            ),
          ),
        ],
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

    // Filter staff based on search query
    final filteredStaffIds = staffAttendance.keys.where((staffId) {
      if (_searchQuery.isEmpty) return true;

      final firstRecord = staffAttendance[staffId]!.first;
      final name = firstRecord.name.toLowerCase();
      final id = staffId.toLowerCase();

      return name.contains(_searchQuery) || id.contains(_searchQuery);
    }).toList();

    // Sort by name
    filteredStaffIds.sort((a, b) {
      final nameA = staffAttendance[a]!.first.name.toLowerCase();
      final nameB = staffAttendance[b]!.first.name.toLowerCase();
      return nameA.compareTo(nameB);
    });

    return Column(
      children: [
        // Results Summary
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${filteredStaffIds.length} staff found',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    '${data.dailyAttendance.length} daily records • ${data.attendanceLog.length} log records',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              if (_startDate != null && _endDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Staff List
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent &&
                  !_isLoadingMore &&
                  (_hasMoreDaily || _hasMoreLog)) {
                _loadMoreData();
                return true;
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: () async {
                _onRefresh();
              },
              color: const Color(0xFF4F46E5),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  ...filteredStaffIds.map((staffId) {
                    final staffRecords = staffAttendance[staffId]!;
                    final firstRecord = staffRecords.first;
                    final dateLogs = staffDateLogs[staffId] ?? {};
                    final isStaffExpanded = _expandedStaff[staffId] ?? false;

                    return _buildStaffCard(
                      staffId: staffId,
                      name: firstRecord.name,
                      shiftStart: firstRecord.shiftStart,
                      shiftEnd: firstRecord.shiftEnd,
                      totalDays: staffRecords.length,
                      records: staffRecords,
                      dateLogs: dateLogs,
                      isStaffExpanded: isStaffExpanded,
                    );
                  }).toList(),

                  // Loading More Indicator
                  if (_isLoadingMore)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: const Center(
                        child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                      ),
                    ),

                  // No More Data Message
                  if (!_hasMoreDaily && !_hasMoreLog && filteredStaffIds.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: const Center(
                        child: Text(
                          'No more records to load',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPunchButtons(String staffId, String staffName) {
    final isPunchingThisStaff = _isPunching && _currentPunchingStaffId == staffId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildPunchButton(
              label: 'Clock In',
              icon: Icons.login,
              color: const Color(0xFF4CAF50),
              isLoading: isPunchingThisStaff,
              onPressed: () => _punchAttendance('in', staffId, staffName),
              staffId: staffId,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildPunchButton(
              label: 'Clock Out',
              icon: Icons.logout,
              color: const Color(0xFFF44336),
              isLoading: isPunchingThisStaff,
              onPressed: () => _punchAttendance('out', staffId, staffName),
              staffId: staffId,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPunchButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required VoidCallback onPressed,
    required String staffId,
  }) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: isLoading ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                else
                  Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _punchAttendance(String action, String staffId, String staffName) async {
    // For testing, use default coordinates
    // In production, you should get real location
    _currentLatitude = 23.7965; // Default latitude for testing
    _currentLongitude = 90.4024; // Default longitude for testing

    if (_currentLatitude == null || _currentLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location not available")),
      );
      return;
    }

    setState(() {
      _isPunching = true;
      _currentPunchingStaffId = staffId;
    });

    try {
      await _apiService.punchAttendance(
        staffId: staffId,
        action: action,
        latitude: _currentLatitude!,
        longitude: _currentLongitude!,
        notes: 'Punched from All Staff view',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$staffName successfully ${action.toLowerCase()}ed!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Refresh data after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        _onRefresh();
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to punch: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isPunching = false;
        _currentPunchingStaffId = null;
      });
    }
  }

  Widget _buildStaffCard({
    required String staffId,
    required String name,
    required String? shiftStart,
    required String? shiftEnd,
    required int totalDays,
    required List<AttendanceRecord> records,
    required Map<String, List<AttendanceLog>> dateLogs,
    required bool isStaffExpanded,
  }) {
    final isPunchingThisStaff = _isPunching && _currentPunchingStaffId == staffId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 5,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Level 1: Staff Header (Always visible)
          InkWell(
            onTap: () {
              setState(() {
                _expandedStaff[staffId] = !isStaffExpanded;
              });
            },
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Staff Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: $staffId',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (shiftStart != null && shiftEnd != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Shift: ${_formatTime(shiftStart)} - ${_formatTime(shiftEnd)}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),



                  // Days Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4F46E5).withOpacity(0.1),
                          const Color(0xFF7C3AED).withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$totalDays days',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),

                  // Expand Icon
                  const SizedBox(width: 12),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isStaffExpanded
                          ? const Color(0xFF4F46E5).withOpacity(0.1)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isStaffExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: isStaffExpanded ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Level 2: Dates List (Expanded when THIS staff is expanded)
          if (isStaffExpanded) ...[
            Divider(height: 1, color: Color(0xFF4F46E5)),
            // Punch Buttons (Full width when expanded)
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildPunchButtons(staffId, name),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: records.map((record) {
                  final dateLogsForDate = dateLogs[record.date] ?? [];
                  final isDateExpanded = _expandedDates[staffId]?[record.date] ?? false;

                  return _buildDateCard(
                    staffId: staffId,
                    record: record,
                    logs: dateLogsForDate,
                    isDateExpanded: isDateExpanded,
                    onTap: () {
                      setState(() {
                        // Initialize the map for this staff if needed
                        if (!_expandedDates.containsKey(staffId)) {
                          _expandedDates[staffId] = {};
                        }
                        _expandedDates[staffId]![record.date] = !isDateExpanded;
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ... Rest of your existing methods remain the same (_buildDateCard, _buildModernLogItem, etc.)
  // I've kept them the same as in your original code

  Widget _buildDateCard({
    required String staffId,
    required AttendanceRecord record,
    required List<AttendanceLog> logs,
    required bool isDateExpanded,
    required VoidCallback onTap,
  }) {
    final statusColor = _getStatusColor(record.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDateExpanded ? statusColor.withOpacity(0.3) : const Color(0xFFF1F5F9),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Level 2: Date Header
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  // Date Box
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: statusColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getDayOfWeek(record.date),
                          style: TextStyle(
                            fontSize: 10,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getDayNumber(record.date),
                          style: TextStyle(
                            fontSize: 14,
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Date Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                record.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(record.date),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),
                        // Time Chips (IN and OUT separately)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (record.firstInTime != null)
                              _buildModernTimeChip(
                                icon: Icons.login_rounded,
                                time: _formatTime(record.firstInTime!),
                                color: const Color(0xFF10B981),
                              ),
                            if (record.lastOutTime != null)
                              _buildModernTimeChip(
                                icon: Icons.logout_rounded,
                                time: _formatTime(record.lastOutTime!),
                                color: const Color(0xFFEF4444),
                              ),
                            if (record.hoursWorked != null && record.hoursWorked!.isNotEmpty)
                              _buildModernTimeChip(
                                icon: Icons.schedule_rounded,
                                time: record.hoursWorked!,
                                color: const Color(0xFF3B82F6),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Logs Count & Expand Icon
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${logs.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const Text(
                        'logs',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDateExpanded
                          ? statusColor.withOpacity(0.15)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isDateExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: isDateExpanded ? statusColor : const Color(0xFF94A3B8),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Level 3: Attendance Logs (Expanded when date is expanded)
          if (isDateExpanded) ...[
            const Divider(height: 1, color: Color(0xFF4F46E5)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logs Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.history_rounded, size: 16, color: Color(0xFF4F46E5)),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Activity Logs',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${logs.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Logs List
                  if (logs.isEmpty)
                    _buildNoLogsMessage()
                  else
                    ...logs.map((log) => _buildModernLogItem(log)).toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernTimeChip({
    required IconData icon,
    required String time,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernLogItem(AttendanceLog log) {
    final isIn = log.action == 'IN';
    final actionColor = isIn ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final time = DateFormat('hh:mm a').format(log.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: Row(
        children: [
          // Log Icon
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: actionColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                isIn ? Icons.login_rounded : Icons.logout_rounded,
                size: 15,
                color: actionColor,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Log Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: actionColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        log.action,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: actionColor,
                        ),
                      ),
                    ),
                    Text(
                      log.time,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 11, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 5),
                    Text(
                      log.date,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Notes section (only shows if notes exist)
                    if (log.notes != null && log.notes!.isNotEmpty)
                      Flexible(
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.notes_rounded,
                                  size: 12,
                                  color: Color(0xFF94A3B8)
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  log.notes!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF475569),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(),

                    // Location icon
                    _build_LocationIcon(log),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _build_LocationIcon(AttendanceLog log) {
    return Container(
      padding: EdgeInsets.all(6),
      child: (log.latitude != null && log.longitude != null)
          ? Tooltip(
        message: 'Tap to view location on map',
        child: GestureDetector(
          onTap: () => _showAgreeConfirmationDialog(
            log.latitude.toString(),
            log.longitude.toString(),
          ),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF4285F4),
                  Color(0xFF34A853),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF4285F4).withOpacity(0.3),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      )
          : Tooltip(
        message: 'Location not available',
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              'NA',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAgreeConfirmationDialog(String latitude, String longitude) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location'),
          content: Text('Do you want to Open Maps?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Open'),
              onPressed: () {
                if(latitude.isNotEmpty && longitude.isNotEmpty) {
                  Navigator.of(context).pop();
                  locationRequest(double.parse(latitude), double.parse(longitude));
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> locationRequest(double latitude, double longitude) async {
    final String mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    final String fallbackUrl = 'https://maps.google.com/?q=$latitude,$longitude';
    final String geoUrl = 'geo:$latitude,$longitude';
    final String googleMapsAppUrl = 'comgooglemaps://?q=$latitude,$longitude';
    final String appleMapsUrl = 'maps://?q=$latitude,$longitude';

    print('Location URL: $mapsUrl');

    try {
      if (await canLaunchUrl(Uri.parse(mapsUrl))) {
        await launchUrl(
          Uri.parse(mapsUrl),
          mode: LaunchMode.externalApplication,
        );
        return;
      }

      if (await canLaunchUrl(Uri.parse(fallbackUrl))) {
        await launchUrl(
          Uri.parse(fallbackUrl),
          mode: LaunchMode.externalApplication,
        );
        return;
      }

      if (await canLaunchUrl(Uri.parse(geoUrl))) {
        await launchUrl(
          Uri.parse(geoUrl),
          mode: LaunchMode.externalApplication,
        );
        return;
      }

      if (await canLaunchUrl(Uri.parse(googleMapsAppUrl))) {
        await launchUrl(
          Uri.parse(googleMapsAppUrl),
          mode: LaunchMode.externalApplication,
        );
        return;
      }

      if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
        await launchUrl(
          Uri.parse(appleMapsUrl),
          mode: LaunchMode.externalApplication,
        );
        return;
      }

      throw Exception('No map application found');

    } catch (e) {
      print('Error launching URL: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open maps. URL: $mapsUrl'),
          duration: Duration(seconds: 3),
        ),
      );
      throw 'Could not launch map: $e';
    }
  }



  Widget _buildNoLogsMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.info_outline_rounded, size: 28, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),
          const Text(
            'No activity logs',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _formatTime(String timeStr) {
    try {
      if (timeStr.length >= 5) return timeStr.substring(0, 5);
      return timeStr;
    } catch (e) {
      return timeStr;
    }
  }

  String _getDayOfWeek(String date) {
    try {
      final dateTime = DateTime.parse(date);
      return DateFormat('EEE').format(dateTime).toUpperCase();
    } catch (e) {
      return '---';
    }
  }

  String _getDayNumber(String date) {
    try {
      final dateTime = DateTime.parse(date);
      return dateTime.day.toString();
    } catch (e) {
      return '--';
    }
  }

  String _formatDate(String date) {
    try {
      final dateTime = DateTime.parse(date);
      return DateFormat('MMMM dd, yyyy').format(dateTime);
    } catch (e) {
      return date;
    }
  }

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    return switch (statusLower) {
      'present' => const Color(0xFF10B981),
      'late' => const Color(0xFFF59E0B),
      'absent' => const Color(0xFFEF4444),
      'early' => const Color(0xFF3B82F6),
      'half day' => const Color(0xFF8B5CF6),
      _ => Colors.grey,
    };
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF4F46E5)),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.error_outline, size: 40, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _onRefresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Try Again', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(Icons.history, size: 60, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Records Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
          if (_searchQuery.isNotEmpty || _startDate != null || _endDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton(
                onPressed: _clearFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Clear Filters'),
              ),
            ),
        ],
      ),
    );
  }
}