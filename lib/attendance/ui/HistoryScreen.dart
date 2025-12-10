import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'AttendanceCard.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setStateIfMounted(() {
      _isLoading = true;
      _error = '';
    });

    try {
      print('📡 Loading attendance data for ${widget.staffId}...');

      // Load data
      final response = await ApiServiceAttendance().getAttendancespecificStaff(staffId: widget.staffId);

      if (mounted) {
        setStateIfMounted(() {
          _dailyRecords = response.dailyAttendance;
          _allLogs = response.attendanceLog;

          // Group logs by date
          _groupLogsByDate();
        });
      }

      print('✅ Loaded ${_dailyRecords.length} daily records and ${_allLogs.length} log records');

    } catch (e) {
      print('❌ Load error: $e');
      if (mounted) {
        setStateIfMounted(() {
          _error = 'Failed to load: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setStateIfMounted(() {
          _isLoading = false;
        });
      }
    }
  }

  void _groupLogsByDate() {
    _logsByDate.clear();

    for (var log in _allLogs) {
      // Extract date from timestamp or date field
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

    // Sort logs within each date by timestamp (newest first)
    _logsByDate.forEach((date, logs) {
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });

    print('📊 Grouped logs into ${_logsByDate.length} dates');
  }

  // Get logs for a specific date
  List<AttendanceLog> _getLogsForDate(String date) {
    if (date.contains('T')) {
      final dateTime = DateTime.parse(date);
      final dateKey = DateFormat('yyyy-MM-dd').format(dateTime);
      return _logsByDate[dateKey] ?? [];
    }
    return _logsByDate[date] ?? [];
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance - ${widget.staffName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : _dailyRecords.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No attendance records found'),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadData,
        child: ListView.builder(
          itemCount: _dailyRecords.length,
          itemBuilder: (context, index) {
            final record = _dailyRecords[index];
            final dailyLogs = _getLogsForDate(record.date);

            return AttendanceCard(
              date: record.date,
              status: record.status,
              inTime: record.firstInTime,
              outTime: record.lastOutTime,
              hoursWorked: record.hoursWorked,
              notes: record.notes,
              dailyLogs: dailyLogs,
              onTap: () {
                print('📅 Tapped on ${record.date} with ${dailyLogs.length} logs');
              },
            );
          },
        ),
      ),
    );
  }
}