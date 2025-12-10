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
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _staffIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _staffIdController.text = widget.staffId;
    if (widget.initialStartDate != null) {
      _startDate = DateTime.parse(widget.initialStartDate!);
    }
    if (widget.initialEndDate != null) {
      _endDate = DateTime.parse(widget.initialEndDate!);
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
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
      initialDate: _endDate ?? DateTime.now(),
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
    if (_startDate != null) {
      filters['startDate'] = DateFormat('yyyy-MM-dd').format(_startDate!);
    }
    if (_endDate != null) {
      filters['endDate'] = DateFormat('yyyy-MM-dd').format(_endDate!);
    }
    // Only add staffId if it's not empty
    if (_staffIdController.text.trim().isNotEmpty) {
      filters['staffId'] = _staffIdController.text.trim();
    } else {
      filters['staffId'] = null; // null means all staff
    }
    return filters;
  }
  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
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
              'Clear',
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
              ),
              // Remove enabled: false to make it editable
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
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectStartDate(context),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _startDate != null
                                ? DateFormat('MMM dd, yyyy').format(_startDate!)
                                : 'Start Date',
                            style: TextStyle(
                              color: _startDate != null ? Colors.black : Colors.grey,
                            ),
                          ),
                          const Icon(Icons.calendar_today, size: 20),
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _endDate != null
                                ? DateFormat('MMM dd, yyyy').format(_endDate!)
                                : 'End Date',
                            style: TextStyle(
                              color: _endDate != null ? Colors.black : Colors.grey,
                            ),
                          ),
                          const Icon(Icons.calendar_today, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_startDate != null && _endDate != null && _startDate!.isAfter(_endDate!))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Start date must be before end date',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
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
                    if (_startDate != null && _endDate != null && _startDate!.isAfter(_endDate!)) {
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
}