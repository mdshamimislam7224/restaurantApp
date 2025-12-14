import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'model_class/ApiServiceAttendance.dart';
import 'model_class/AttendanceRecord.dart';

class HistoryScreen extends StatefulWidget {
  final String staffId;
  final String staffName;

  const HistoryScreen({
    super.key,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = false;
  String _error = '';
  List<AttendanceRecord> _dailyRecords = [];
  List<AttendanceLog> _allLogs = [];
  Map<String, List<AttendanceLog>> _logsByDate = {};

  // Track expanded states
  bool _isUserExpanded = false;
  final Map<String, bool> _expandedDates = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      print('📡 Loading attendance data for ${widget.staffId}...');

      final response = await ApiServiceAttendance().getAttendancespecificStaff(staffId: widget.staffId);

      if (mounted) {
        setState(() {
          _dailyRecords = response.dailyAttendance;
          _allLogs = response.attendanceLog;
          _groupLogsByDate();

          for (var record in _dailyRecords) {
            _expandedDates[record.date] = false;
          }
        });
      }

      print('✅ Loaded ${_dailyRecords.length} daily records and ${_allLogs.length} log records');

    } catch (e) {
      print('❌ Load error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _groupLogsByDate() {
    _logsByDate.clear();

    for (var log in _allLogs) {
      String dateKey;
      if (log.date.contains('T')) {
        final dateTime = DateTime.parse(log.date);
        dateKey = DateFormat('yyyy-MM-dd').format(dateTime);
      } else {
        dateKey = log.date;
      }

      if (!_logsByDate.containsKey(dateKey)) {
        _logsByDate[dateKey] = [];
      }
      _logsByDate[dateKey]!.add(log);
    }

    _logsByDate.forEach((date, logs) {
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });

    print('📊 Grouped logs into ${_logsByDate.length} dates');
  }

  List<AttendanceLog> _getLogsForDate(String date) {
    if (date.contains('T')) {
      final dateTime = DateTime.parse(date);
      final dateKey = DateFormat('yyyy-MM-dd').format(dateTime);
      return _logsByDate[dateKey] ?? [];
    }
    return _logsByDate[date] ?? [];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Attendance History',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : _error.isNotEmpty
          ? _buildErrorState()
          : _dailyRecords.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFF4F46E5),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildUserCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
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
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                elevation: 0,
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
            'No Records Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start by clocking in to see your attendance',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard() {
    int totalDays = _dailyRecords.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // User Header - Click to expand
          InkWell(
            onTap: () {
              setState(() {
                _isUserExpanded = !_isUserExpanded;
                print('🔄 User card ${_isUserExpanded ? "EXPANDED" : "COLLAPSED"}');
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 56,
                    height: 56,
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
                    child: const Center(
                      child: Icon(Icons.person_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.staffName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${widget.staffId}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Expand Icon with animation hint
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _isUserExpanded
                          ? const Color(0xFF4F46E5).withOpacity(0.1)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isUserExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: _isUserExpanded ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 🔽 THIS SECTION IS HIDDEN UNTIL YOU CLICK THE USER CARD 🔽
          // Expandable Date Cards
          if (_isUserExpanded) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: _dailyRecords.map((record) => _buildDateCard(record)).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateCard(AttendanceRecord record) {
    final isDateExpanded = _expandedDates[record.date] ?? false;
    final logs = _getLogsForDate(record.date);
    final statusColor = _getStatusColor(record.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDateExpanded ? statusColor.withOpacity(0.3) : const Color(0xFFF1F5F9),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Date Header
          InkWell(
            onTap: () {
              setState(() {
                _expandedDates[record.date] = !isDateExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Date Box
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
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
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getDayNumber(record.date),
                          style: TextStyle(
                            fontSize: 20,
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
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDate(record.date),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Time Chips
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (record.firstInTime != null)
                              _buildModernTimeChip(
                                icon: Icons.login_rounded,
                                time: record.firstInTime!,
                                color: const Color(0xFF10B981),
                              ),
                            if (record.lastOutTime != null)
                              _buildModernTimeChip(
                                icon: Icons.logout_rounded,
                                time: record.lastOutTime!,
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
                  // Expand Icon
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
          // Expandable Logs Section
          if (isDateExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
                          fontSize: 14,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: Row(
        children: [
          // Log Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: actionColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                isIn ? Icons.login_rounded : Icons.logout_rounded,
                size: 20,
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
                          fontWeight: FontWeight.w700,
                          color: actionColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    Text(
                      log.time,
                      style: const TextStyle(
                        fontSize: 15,
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
                      DateFormat('MMM dd, yyyy • hh:mm a').format(log.timestamp),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (log.notes != null && log.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notes_rounded, size: 12, color: Color(0xFF94A3B8)),
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
                ],
              ],
            ),
          ),
        ],
      ),
    );
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
        children: [
          Container(
            width: 60,
            height: 60,
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

  String _getDayOfWeek(String date) {
    try {
      DateTime dateTime;
      if (date.contains('T')) {
        dateTime = DateTime.parse(date);
      } else {
        dateTime = DateFormat('yyyy-MM-dd').parse(date);
      }
      return DateFormat('EEE').format(dateTime).toUpperCase();
    } catch (e) {
      return '---';
    }
  }

  String _getDayNumber(String date) {
    try {
      DateTime dateTime;
      if (date.contains('T')) {
        dateTime = DateTime.parse(date);
      } else {
        dateTime = DateFormat('yyyy-MM-dd').parse(date);
      }
      return dateTime.day.toString();
    } catch (e) {
      return '--';
    }
  }

  String _formatDate(String date) {
    try {
      DateTime dateTime;
      if (date.contains('T')) {
        dateTime = DateTime.parse(date);
      } else {
        dateTime = DateFormat('yyyy-MM-dd').parse(date);
      }
      return DateFormat('MMMM dd, yyyy').format(dateTime);
    } catch (e) {
      return date;
    }
  }
}