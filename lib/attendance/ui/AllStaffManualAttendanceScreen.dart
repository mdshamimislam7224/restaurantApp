import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'model_class/ApiServiceAttendance.dart';
import 'model_class/AttendanceRecord.dart';

class SingleStaffAttendanceScreen extends StatefulWidget {
  final String staffId;
  final String staffName;

  const SingleStaffAttendanceScreen({
    super.key,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<SingleStaffAttendanceScreen> createState() => _SingleStaffAttendanceScreenState();
}

class _SingleStaffAttendanceScreenState extends State<SingleStaffAttendanceScreen> {
  final ApiServiceAttendance _apiService = ApiServiceAttendance();

  // State variables
  bool _isLoading = false;
  bool _isRefreshing = false;
  String _errorMessage = '';
  DateTime _selectedDate = DateTime.now();

  // Data
  List<AttendanceRecord> _attendanceRecords = [];

  // Filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'All';
  final List<String> _statusFilters = ['All', 'Present', 'Absent', 'Late', 'Early'];

  // Pagination
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _mainScrollController = ScrollController();

  // Timer for auto-refresh
  Timer? _refreshTimer;

  // Stats
  int _presentCount = 0;
  int _absentCount = 0;
  int _lateCount = 0;
  int _earlyCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStaffAttendance();
    _setupScrollListener();

    // Auto-refresh every 5 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        _loadStaffAttendance(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _mainScrollController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100 &&
          _hasMoreData &&
          !_isLoadingMore &&
          !_isLoading &&
          !_isRefreshing) {
        _loadMoreAttendance();
      }
    });
  }

  Future<void> _loadStaffAttendance({bool silent = false, bool reset = true}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        if (reset) {
          _currentPage = 1;
          _attendanceRecords.clear();
          _hasMoreData = true;
        }
      });
    } else {
      setState(() {
        _isRefreshing = true;
      });
    }

    try {
      // Fetch attendance for specific staff
      final response = await _apiService.getAttendancespecificStaff(
        staffId: widget.staffId,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        dailyPage: reset ? 1 : _currentPage,
        dailyLimit: _pageSize,
      );

      if (reset) {
        _attendanceRecords = response.dailyAttendance;
      } else {
        _attendanceRecords.addAll(response.dailyAttendance);
      }

      // Check if we have more data to load
      if (response.dailyAttendance.length < _pageSize) {
        _hasMoreData = false;
      }

      // Calculate statistics
      _calculateStats();

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load attendance: ${e.toString()}';
        _hasMoreData = false;
      });
      print('Error loading staff attendance: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _isLoadingMore = false;
      });
    }
  }

  void _calculateStats() {
    _presentCount = _attendanceRecords
        .where((record) => record.status.toLowerCase() == 'present')
        .length;
    _absentCount = _attendanceRecords
        .where((record) => record.status.toLowerCase() == 'absent')
        .length;
    _lateCount = _attendanceRecords
        .where((record) => record.status.toLowerCase() == 'late')
        .length;
    _earlyCount = _attendanceRecords
        .where((record) => record.status.toLowerCase() == 'early')
        .length;
  }

  Future<void> _loadMoreAttendance() async {
    if (!_hasMoreData || _isLoadingMore || _isLoading || _isRefreshing) return;

    setState(() {
      _isLoadingMore = true;
    });

    _currentPage++;
    await _loadStaffAttendance(silent: true, reset: false);
  }

  void _applyFilters() {
    // For single staff, we just filter the existing records
    // No need for complex filtering since it's just one staff
    _calculateStats();
  }

  Future<void> _onDateSelected(DateTime date) async {
    setState(() {
      _selectedDate = date;
      _currentPage = 1;
      _attendanceRecords.clear();
      _hasMoreData = true;
    });
    await _loadStaffAttendance();
  }

  Widget _buildSpinner() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4361EE)),
          ),
          const SizedBox(height: 16),
          Text(
            _isRefreshing ? 'Refreshing...' : 'Loading attendance...',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Fetching data for ${DateFormat('MMM d, yyyy').format(_selectedDate)}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
                      widget.staffName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${widget.staffId}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.calendar_today,
                      color: Colors.blue.shade600,
                    ),
                    onPressed: () => _showDatePicker(),
                    tooltip: 'Select Date',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: _isRefreshing ? Colors.grey : Colors.blue.shade600,
                    ),
                    onPressed: _isRefreshing ? null : () => _loadStaffAttendance(),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, size: 14, color: Colors.blue.shade700),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _showDatePicker(),
                      child: Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_attendanceRecords.length} records',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4361EE),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      await _onDateSelected(picked);
    }
  }

  Widget _buildStatsCards() {
    final totalCount = _attendanceRecords.length;
    final attendanceRate = totalCount > 0
        ? (_presentCount / totalCount * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Total', totalCount.toString(), Colors.blue, Icons.calendar_today),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard('Present', _presentCount.toString(), Colors.green, Icons.check_circle),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Absent', _absentCount.toString(), Colors.red, Icons.cancel),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard('Late', _lateCount.toString(), Colors.orange, Icons.watch_later),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Early', _earlyCount.toString(), Colors.purple, Icons.alarm),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard('Rate', '$attendanceRate%', Colors.teal, Icons.trending_up),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceRecord record) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getStatusColor(record.status).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date and Status Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    record.date,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(record.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(record.status),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      record.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(record.status),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Attendance Details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Shift Info
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailItem(
                            'Shift',
                            '${record.shiftStart ?? 'N/A'} - ${record.shiftEnd ?? 'N/A'}',
                            Icons.schedule,
                            Colors.blue,
                          ),
                        ),
                        Expanded(
                          child: _buildDetailItem(
                            'Hours',
                            record.hoursWorked ?? 'N/A',
                            Icons.access_time,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Check-in/Check-out Info
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailItem(
                            'Check-in',
                            record.firstInTime ?? 'N/A',
                            Icons.login,
                            Colors.green,
                          ),
                        ),
                        Expanded(
                          child: _buildDetailItem(
                            'Check-out',
                            record.lastOutTime ?? 'N/A',
                            Icons.logout,
                            Colors.red,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Location & Notes
                    if (record.lat != null && record.long != null)
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailItem(
                              'Location',
                              '${record.lat!.toStringAsFixed(4)}, ${record.long!.toStringAsFixed(4)}',
                              Icons.location_on,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),

                    if (record.notes != null && record.notes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _buildDetailItem(
                          'Notes',
                          record.notes!,
                          Icons.notes,
                          Colors.purple,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'late':
        return Colors.orange;
      case 'early':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Failed to load attendance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadStaffAttendance,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4361EE),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No attendance records for ${DateFormat('MMM d, yyyy').format(_selectedDate)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Attendance records will appear here once recorded',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _onDateSelected(DateTime.now()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4361EE),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Today'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
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
      ),
    );
  }

  Widget _buildNoMoreRecords() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          'No more records',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text('${widget.staffName}\'s Attendance'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF333333),
        actions: [
          if (_isRefreshing)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.blue.shade600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading && _attendanceRecords.isEmpty
          ? _buildSpinner()
          : SingleChildScrollView(
        controller: _mainScrollController,
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildHeader(),
            _buildStatsCards(),
            const SizedBox(height: 8),

            // Fixed Height ListView for Attendance Records
            Container(
              height: 500, // Fixed height for the ListView
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildAttendanceList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceList() {
    if (_errorMessage.isNotEmpty && _attendanceRecords.isEmpty) {
      return _buildErrorState();
    }

    if (_attendanceRecords.isEmpty && !_isLoadingMore) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => _loadStaffAttendance(silent: true, reset: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(8),
        itemCount: _attendanceRecords.length + (_isLoadingMore ? 1 : 0) + (_hasMoreData ? 0 : 1),
        itemBuilder: (context, index) {
          if (index < _attendanceRecords.length) {
            return _buildAttendanceCard(_attendanceRecords[index]);
          } else if (index == _attendanceRecords.length && _isLoadingMore) {
            return _buildLoadingMoreIndicator();
          } else {
            return _buildNoMoreRecords();
          }
        },
      ),
    );
  }
}