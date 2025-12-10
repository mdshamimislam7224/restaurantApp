import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'model_class/AttendanceRecord.dart';

class AttendanceCard extends StatefulWidget {
  final String date;
  final String status;
  final String? inTime;
  final String? outTime;
  final String? hoursWorked;
  final String? notes;
  final List<AttendanceLog>? dailyLogs; // Add this for daily logs
  final VoidCallback? onTap;

  const AttendanceCard({
    super.key,
    required this.date,
    required this.status,
    this.inTime,
    this.outTime,
    this.hoursWorked,
    this.notes,
    this.dailyLogs,
    this.onTap,
  });

  @override
  State<AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends State<AttendanceCard> {
  bool _isExpanded = false;

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return const Color(0xFF4CAF50);
      case 'late':
        return const Color(0xFFFF9800);
      case 'absent':
        return const Color(0xFFF44336);
      case 'early':
        return const Color(0xFF2196F3);
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Icons.check_circle;
      case 'late':
        return Icons.watch_later;
      case 'absent':
        return Icons.cancel;
      case 'early':
        return Icons.alarm;
      default:
        return Icons.help;
    }
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      if (dateTimeStr.contains('T')) {
        final dateTime = DateTime.parse(dateTimeStr);
        // Check if it's a time-only value (Google Sheets special dates)
        final year = dateTime.year;
        if (year == 1899) {
          // Time-only value
          return DateFormat('hh:mm a').format(dateTime);
        } else {
          // Full date-time value
          return DateFormat('MMM dd, yyyy').format(dateTime);
        }
      }
      return dateTimeStr;
    } catch (e) {
      return dateTimeStr;
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '--:--';
    return _formatDateTime(timeStr);
  }

  String _formatDate(String dateStr) {
    return _formatDateTime(dateStr);
  }

  String _getDayName(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEEE').format(date);
    } catch (e) {
      return '';
    }
  }

  // Parse hours worked from the weird format
  String _formatHoursWorked(String? hoursWorked) {
    if (hoursWorked == null || hoursWorked.isEmpty) return '';

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
        widget.onTap?.call();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Date and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(widget.date),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getDayName(widget.date),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 100),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(widget.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(widget.status),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(widget.status),
                          size: 12,
                          color: _getStatusColor(widget.status),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(widget.status),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Summary: In/Out times and hours
            Row(
              children: [
                if (widget.inTime != null)
                  Expanded(
                    child: _buildSummaryItem(
                      'Clock In',
                      _formatTime(widget.inTime),
                      Icons.login,
                      Colors.green,
                    ),
                  ),
                if (widget.inTime != null && widget.outTime != null)
                  const SizedBox(width: 8),
                if (widget.outTime != null)
                  Expanded(
                    child: _buildSummaryItem(
                      'Clock Out',
                      _formatTime(widget.outTime),
                      Icons.logout,
                      Colors.red,
                    ),
                  ),
              ],
            ),

            if (widget.hoursWorked != null && widget.hoursWorked!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.timer, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'Hours:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatHoursWorked(widget.hoursWorked),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),

            // Expand indicator
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isExpanded ? 'Hide details' : 'Tap for details',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                    size: 20,
                  ),
                ],
              ),
            ),

            // Expanded section with attendance logs
            if (_isExpanded && widget.dailyLogs != null && widget.dailyLogs!.isNotEmpty)
              Column(
                children: [
                  const Divider(height: 20),
                  const Text(
                    'Daily Punch Logs',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.dailyLogs!.map((log) => _buildLogItem(log)).toList(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildLogItem(AttendanceLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: log.action == 'IN' ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              log.action == 'IN' ? Icons.login : Icons.logout,
              size: 18,
              color: log.action == 'IN' ? Colors.green : Colors.red,
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
                        fontWeight: FontWeight.bold,
                        color: log.action == 'IN' ? Colors.green : Colors.red,
                      ),
                    ),
                    Text(
                      _formatTime(log.time),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (log.notes != null && log.notes!.isNotEmpty)
                  Text(
                    log.notes!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Text(
                  '${log.latitude != null ? log.latitude!.toStringAsFixed(4) : 'N/A'}, ${log.longitude != null ? log.longitude!.toStringAsFixed(4) : 'N/A'}',
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
  }
}