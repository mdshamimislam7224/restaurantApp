import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FilterScreen extends StatefulWidget {
  final String? initialStartDate;
  final String? initialEndDate;
  final String staffId;

  const FilterScreen({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    required this.staffId,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  final TextEditingController _staffIdController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Set default dates to current month
    final today = DateTime.now();
    _startDate = DateTime(today.year, today.month, 1);
    _endDate = DateTime(today.year, today.month + 1, 0);

    // Override with initial values if provided
    if (widget.initialStartDate != null) {
      _startDate = DateTime.parse(widget.initialStartDate!);
    }
    if (widget.initialEndDate != null) {
      _endDate = DateTime.parse(widget.initialEndDate!);
    }

    _staffIdController.text = widget.staffId;
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Map<String, dynamic> _getFilters() {
    final filters = <String, dynamic>{};

    // Always include startDate and endDate with default values
    filters['startDate'] = DateFormat('yyyy-MM-dd').format(_startDate);
    filters['endDate'] = DateFormat('yyyy-MM-dd').format(_endDate);

    // Staff ID - use trimmed value or null if empty
    final staffId = _staffIdController.text.trim();
    filters['staffId'] = staffId.isNotEmpty ? staffId : null;

    return filters;
  }

  void _clearFilters() {
    setState(() {
      // Reset to current month
      final today = DateTime.now();
      _startDate = DateTime(today.year, today.month, 1);
      _endDate = DateTime(today.year, today.month + 1, 0);
      _staffIdController.text = widget.staffId;
    });
  }

  void _setCurrentMonth() {
    setState(() {
      final today = DateTime.now();
      _startDate = DateTime(today.year, today.month, 1);
      _endDate = DateTime(today.year, today.month + 1, 0);
    });
  }

  void _setPreviousMonth() {
    setState(() {
      final today = DateTime.now();
      _startDate = DateTime(today.year, today.month - 1, 1);
      _endDate = DateTime(today.year, today.month, 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filter Attendance'),
        actions: [
          TextButton(
            onPressed: _clearFilters,
            child: const Text(
              'Reset',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Date Presets
            const Text(
              'Quick Presets',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _setCurrentMonth,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: _isCurrentMonth()
                            ? const Color(0xFF4361EE)
                            : Colors.grey,
                        width: _isCurrentMonth() ? 2 : 1,
                      ),
                      backgroundColor: _isCurrentMonth()
                          ? const Color(0xFF4361EE).withOpacity(0.1)
                          : Colors.transparent,
                    ),
                    child: Text(
                      'Current Month',
                      style: TextStyle(
                        color: _isCurrentMonth()
                            ? const Color(0xFF4361EE)
                            : Colors.grey,
                        fontWeight: _isCurrentMonth()
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _setPreviousMonth,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: _isPreviousMonth()
                            ? const Color(0xFF4361EE)
                            : Colors.grey,
                        width: _isPreviousMonth() ? 2 : 1,
                      ),
                      backgroundColor: _isPreviousMonth()
                          ? const Color(0xFF4361EE).withOpacity(0.1)
                          : Colors.transparent,
                    ),
                    child: Text(
                      'Previous Month',
                      style: TextStyle(
                        color: _isPreviousMonth()
                            ? const Color(0xFF4361EE)
                            : Colors.grey,
                        fontWeight: _isPreviousMonth()
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Text(
              'Staff ID',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _staffIdController,
              decoration: InputDecoration(
                hintText: 'Enter Staff ID (leave empty for all staff)',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Date Range',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Color(0xFF4361EE),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${DateFormat('MMMM yyyy').format(_startDate)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4361EE),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectStartDate(context),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF4361EE).withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'FROM',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM dd, yyyy').format(_startDate),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectEndDate(context),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF4361EE).withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'TO',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM dd, yyyy').format(_endDate),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_getDaysBetween()} days selected',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            if (_startDate.isAfter(_endDate))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.error,
                      color: Theme.of(context).colorScheme.error,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Start date must be before end date',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: Colors.grey),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_startDate.isAfter(_endDate)) {
                      return;
                    }
                    Navigator.pop(context, _getFilters());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4361EE),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods
  bool _isCurrentMonth() {
    final today = DateTime.now();
    return _startDate.month == today.month &&
        _startDate.year == today.year &&
        _startDate.day == 1 &&
        _endDate.month == today.month &&
        _endDate.year == today.year &&
        _endDate.day == DateTime(today.year, today.month + 1, 0).day;
  }

  bool _isPreviousMonth() {
    final today = DateTime.now();
    final lastMonth = DateTime(today.year, today.month - 1, 1);
    return _startDate.month == lastMonth.month &&
        _startDate.year == lastMonth.year &&
        _startDate.day == 1 &&
        _endDate.month == lastMonth.month &&
        _endDate.year == lastMonth.year &&
        _endDate.day == DateTime(lastMonth.year, lastMonth.month + 1, 0).day;
  }

  int _getDaysBetween() {
    return _endDate.difference(_startDate).inDays + 1;
  }
}