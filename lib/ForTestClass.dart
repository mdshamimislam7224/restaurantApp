import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import 'attendance/ui/AttendanceCard.dart';
import 'attendance/ui/PunchButton.dart';
import 'attendance/ui/model_class/ApiServiceAttendance.dart';
import 'attendance/ui/model_class/AttendanceRecord.dart';
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
  final ApiServiceAttendance _apiService = ApiServiceAttendance();
  bool _isLoading = false;
  bool _isPunching = false;
  Position? _currentPosition;
  String _errorMessage = '';
  List<AttendanceRecord> _todayAttendance = [];
  List<AttendanceRecord> _recentAttendance = [];

  @override
  void initState() {
    super.initState();
    // _getCurrentLocation();
    _loadTodayAttendance();
    _loadRecentAttendance();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permissions are denied';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permissions are permanently denied';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _errorMessage = '';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get location: $e';
      });
    }
  }

  Future<void> _loadTodayAttendance() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final response = await _apiService.getAttendancespecificStaff(
        staffId: widget.staffId,
        date: today,
        dailyLimit: 5,
        logLimit: 5,
      );

      setState(() {
        _todayAttendance = response.dailyAttendance;
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

  Future<void> _loadRecentAttendance() async {
    try {
      final response = await _apiService.getAttendancespecificStaff(
        staffId: widget.staffId,
        dailyLimit: 10,
        logLimit: 10,
      );

      setState(() {
        _recentAttendance = response.dailyAttendance;
      });
    } catch (e) {
      // Silently handle error for recent attendance
    }
  }

  Future<void> _punchAttendance(String action) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable location services'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isPunching = true;
    });

    try {
      final result = await _apiService.punchAttendance(
        staffId: widget.staffId,
        action: action,
        latitude: 23.8104,
        longitude: 90.41211,
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
      await _loadTodayAttendance();
      await _loadRecentAttendance();
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF4361EE),
                    Color(0xFF3A0CA3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome,',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.staffName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('h:mm a').format(DateTime.now()),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.white.withOpacity(0.8),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _currentPosition != null
                                    ? 'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}'
                                    : 'Getting location...',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

            // Today's Attendance
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        "Today's Attendance",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),

                    if (_isLoading)
                      const Center(
                        child: CircularProgressIndicator(),
                      )
                    else if (_todayAttendance.isNotEmpty)
                      Column(
                        children: _todayAttendance.map((record) {
                          return AttendanceCard(
                            date: record.date,
                            status: record.status,
                            inTime: record.firstInTime,
                            outTime: record.lastOutTime,
                            hoursWorked: record.hoursWorked,
                            onTap: () {
                              // Show details
                            },
                          );
                        }).toList(),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 64,
                              color: Colors.grey.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No attendance recorded today',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Recent Attendance
                    if (_recentAttendance.isNotEmpty) ...[
                      const Text(
                        'Recent Attendance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._recentAttendance.take(3).map((record) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    record.date,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Status: ${record.status}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _getStatusColor(record.status),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (record.hoursWorked != null && record.hoursWorked!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE3F2FD),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    record.hoursWorked!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1976D2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 20),
                    ],

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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
      default:
        return Colors.grey;
    }
  }
}