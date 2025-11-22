// staff_payment_details_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../alertDialog/customDialog.dart';
import '../api/apiClass.dart';
import '../showToast/Toast_Message.dart';
import 'StaffPaymentDetailsResponse.dart';

class StaffSinglePaymentDetailsScreen extends StatefulWidget {
  final String staffId;
  final String staffJoiningDate;
  const StaffSinglePaymentDetailsScreen({
    Key? key,
    required this.staffId,
    required this.staffJoiningDate
  }) : super(key: key);

  @override
  State<StaffSinglePaymentDetailsScreen> createState() => _StaffSinglePaymentDetailsScreen();
}

class _StaffSinglePaymentDetailsScreen extends State<StaffSinglePaymentDetailsScreen> {
  // Constants
  static const _timeoutDuration = Duration(seconds: 30);

  // Controllers & State
  final Toast_Message toast = Toast_Message();
  final TextEditingController startMonthController = TextEditingController();
  final TextEditingController endMonthController = TextEditingController();

  bool isLoading = false;
  bool hasData = false;
  StaffPaymentData? paymentData;
  String? _staffName;
  String? _staffPosition;
  DateTime? _joiningDate;

  @override
  void initState() {
    super.initState();
    _parseJoiningDate();
    _initializeDates();
    _loadPaymentDetails();
    print('Staff ID: ${widget.staffId}');
    print('Staff Joining Date: ${widget.staffJoiningDate}');
    print('Parsed Joining Date: $_joiningDate');
  }

  void _parseJoiningDate() {
    try {
      // Parse the joining date and get the first day of that month
      if (widget.staffJoiningDate.contains('-')) {
        final parsedDate = DateTime.parse(widget.staffJoiningDate);
        _joiningDate = DateTime(parsedDate.year, parsedDate.month, 1);
      } else if (widget.staffJoiningDate.contains('/')) {
        final parts = widget.staffJoiningDate.split('/');
        if (parts.length == 3) {
          _joiningDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), 1);
        }
      }
    } catch (e) {
      print('Error parsing joining date: $e');
      // If parsing fails, set to current month as fallback
      final now = DateTime.now();
      _joiningDate = DateTime(now.year, now.month, 1);
    }

    // Fallback if still null
    _joiningDate ??= DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  void _initializeDates() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);

    // Set to joining month if current month is before joining, otherwise current month
    if (_joiningDate != null) {
      if (currentMonth.isBefore(_joiningDate!)) {
        startMonthController.text = DateFormat('yyyy-MM').format(_joiningDate!);
        endMonthController.text = DateFormat('yyyy-MM').format(_joiningDate!);
      } else {
        startMonthController.text = DateFormat('yyyy-MM').format(currentMonth);
        endMonthController.text = DateFormat('yyyy-MM').format(currentMonth);
      }
    } else {
      startMonthController.text = DateFormat('yyyy-MM').format(currentMonth);
      endMonthController.text = DateFormat('yyyy-MM').format(currentMonth);
    }
  }

  // ============ API METHODS ============
  Future<void> _loadPaymentDetails() async {
    if (startMonthController.text.isEmpty || endMonthController.text.isEmpty) {
      toast.showToast("Please select date range", Colors.orange, Colors.white);
      return;
    }

    setState(() => isLoading = true);

    try {
      final url = _buildPaymentDetailsUrl();
      print('Fetching URL: $url');

      final response = await http.get(Uri.parse(url)).timeout(_timeoutDuration);
      await _handlePaymentDetailsResponse(response);
    } catch (e) {
      _handleApiError(e);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _buildPaymentDetailsUrl() {
    return '${apiClass().baseUrlStaff}?action=getStaffPaymentDetailsByRange'
        '&startMonth=${startMonthController.text}'
        '&endMonth=${endMonthController.text}'
        '&searchIdOrName=${Uri.encodeComponent(widget.staffId)}';
  }

  Future<void> _handlePaymentDetailsResponse(http.Response response) async {
    print('Response Status: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);

      if (responseData['status'] == 'success') {
        setState(() {
          paymentData = StaffPaymentDetailsResponse.fromJson(responseData).data;
          hasData = true;
          if (paymentData != null && paymentData!.staffDetails.isNotEmpty) {
            _staffName = paymentData!.staffDetails.first.employeeName;
            _staffPosition = paymentData!.staffDetails.first.position;
          }
        });
      } else {
        _handlePaymentDetailsError(responseData);
      }
    } else {
      toast.showToast("Failed to load data", Colors.red, Colors.white);
    }
  }

  void _handlePaymentDetailsError(Map<String, dynamic> responseData) {
    setState(() {
      hasData = true;
      paymentData = null;
    });
    toast.showToast("No payment data found", Colors.orange, Colors.white);
  }

  void _handleApiError(dynamic e) {
    toast.showToast("Network error occurred", Colors.red, Colors.white);
    print('Error: $e');
  }

  // ============ DATE SELECTION WITH RESTRICTION ============
  Future<void> _selectMonth(BuildContext context, TextEditingController controller, bool isStartDate) async {
    final joiningMonth = DateTime(_joiningDate!.year, _joiningDate!.month);
    final currentMonth = DateTime.now();

    // Determine initial year/month
    DateTime selectedDate;
    if (controller.text.isNotEmpty) {
      try {
        selectedDate = DateTime.parse('${controller.text}-01');
      } catch (e) {
        selectedDate = joiningMonth;
      }
    } else {
      selectedDate = joiningMonth;
    }

    // For end date, ensure it starts from at least the start date
    if (!isStartDate && startMonthController.text.isNotEmpty) {
      try {
        final startDate = DateTime.parse('${startMonthController.text}-01');
        if (startDate.isAfter(selectedDate)) {
          selectedDate = startDate;
        }
      } catch (e) {
        print('Error parsing start date: $e');
      }
    }

    final result = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return _MonthPickerDialog(
          initialDate: selectedDate,
          joiningDate: joiningMonth,
          isStartDate: isStartDate,
          startDate: !isStartDate && startMonthController.text.isNotEmpty
              ? DateTime.parse('${startMonthController.text}-01')
              : null,
        );
      },
    );

    if (result != null) {
      final selectedMonth = DateFormat('yyyy-MM').format(result);
      final selectedMonthDate = DateTime(result.year, result.month);
      final joiningMonthDate = DateTime(_joiningDate!.year, _joiningDate!.month);

      // Validate date constraints
      if (isStartDate) {
        // For start date, check if it's before joining date
        if (selectedMonthDate.isBefore(joiningMonthDate)) {
          toast.showToast(
              "Cannot select month before ${DateFormat('MMM yyyy').format(_joiningDate!)}",
              Colors.orange,
              Colors.white
          );
          return;
        }

        // If end date is already set and new start date is after end date, adjust end date
        if (endMonthController.text.isNotEmpty) {
          try {
            final endDate = DateTime.parse('${endMonthController.text}-01');
            final endMonthDate = DateTime(endDate.year, endDate.month);
            if (selectedMonthDate.isAfter(endMonthDate)) {
              endMonthController.text = selectedMonth;
            }
          } catch (e) {
            print('Error parsing end date: $e');
          }
        }
      } else {
        // For end date, check if it's before start date
        if (startMonthController.text.isNotEmpty) {
          try {
            final startDate = DateTime.parse('${startMonthController.text}-01');
            final startMonthDate = DateTime(startDate.year, startDate.month);
            if (selectedMonthDate.isBefore(startMonthDate)) {
              toast.showToast("End month cannot be before start month", Colors.orange, Colors.white);
              return;
            }
          } catch (e) {
            print('Error parsing start date: $e');
          }
        }

        // Check if end date is before joining date
        if (selectedMonthDate.isBefore(joiningMonthDate)) {
          toast.showToast(
              "Cannot select month before ${DateFormat('MMM yyyy').format(_joiningDate!)}",
              Colors.orange,
              Colors.white
          );
          return;
        }
      }

      controller.text = selectedMonth;
    }
  }

  DateTime _getInitialDate(TextEditingController controller, DateTime firstDate) {
    if (controller.text.isNotEmpty) {
      try {
        return DateTime.parse('${controller.text}-01');
      } catch (e) {
        print('Error parsing controller date: $e');
      }
    }
    return firstDate;
  }

  // ============ MODERN UI COMPONENTS ============
  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // gradient: LinearGradient(
        //   begin: Alignment.topLeft,
        //   end: Alignment.bottomRight,
        //   colors: [Colors.blue.shade700, Colors.black26],
        // ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // Profile Avatar

          // Staff Name
          Text(
            _staffName ?? 'Staff Member',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),

          // Staff Position
          if (_staffPosition != null)
            Text(
              _staffPosition!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black.withOpacity(0.8),
              ),
            ),

          const SizedBox(height: 8),
          // Staff ID & Joining Date
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'ID: ${widget.staffId}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (_joiningDate != null)
                Text(
                  'Joined: ${DateFormat('MMM yyyy').format(_joiningDate!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    if (paymentData == null || paymentData!.staffDetails.isEmpty) {
      return const SizedBox();
    }

    final staff = paymentData!.staffDetails.first;
    final summary = staff.paymentSummary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Total Paid Card
          Expanded(
            child: _buildSummaryCard(
              title: "Total Paid",
              amount: summary.totalPaidAllTime,
              color: Colors.green,
              icon: Icons.check_circle_outlined,
            ),
          ),
          const SizedBox(width: 12),

          // Total Due Card
          Expanded(
            child: _buildSummaryCard(
              title: "Total Due",
              amount: summary.totalDueAllTime,
              color: Colors.orange,
              icon: Icons.pending_actions_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required int amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
              if (amount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    amount > 0 ? 'Active' : 'Clear',
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Viewing Period",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_formatMonthDisplay(startMonthController.text)} - ${_formatMonthDisplay(endMonthController.text)}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    if (_joiningDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "Available from ${DateFormat('MMM yyyy').format(_joiningDate!)}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.date_range, color: Colors.blue),
                ),
                onPressed: _showDateRangeDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistory() {
    if (paymentData == null || paymentData!.staffDetails.isEmpty) {
      return _buildEmptyState();
    }

    final staff = paymentData!.staffDetails.first;
    final monthlyPayments = staff.monthlyPayments;

    if (monthlyPayments.isEmpty) {
      return _buildEmptyState();
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.history, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    "Payment History",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "${monthlyPayments.length} months",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Payment List
            Expanded(
              child: ListView.separated(
                itemCount: monthlyPayments.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _buildModernPaymentCard(monthlyPayments[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernPaymentCard(MonthlyPayment monthly) {
    final (statusColor, statusIcon) = _getStatusProperties(monthly.status);
    final double progress = monthly.basicSalary > 0
        ? monthly.totalPaid / monthly.basicSalary
        : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, size: 16, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _formatMonthDisplay(monthly.month),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  monthly.status,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Paid: ${_formatCurrency(monthly.totalPaid)}",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    "Salary: ${_formatCurrency(monthly.basicSalary)}",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                color: statusColor,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 8),
              Text(
                "${(progress * 100).toStringAsFixed(0)}% Paid",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),

          // Payment Details
          if (monthly.payments.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              "Payment Instalments",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            ...monthly.payments.map((payment) => _buildModernPaymentDetail(payment)),
          ],
        ],
      ),
    );
  }

  Widget _buildModernPaymentDetail(PaymentDetail payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.payment, size: 14, color: Colors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatCurrency(payment.paidAmount),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatDate(payment.paymentDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (payment.notes.isNotEmpty)
                  Text(
                    payment.notes,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.payment_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              "No Payment Data",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "No payment records found for the selected period",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.date_range, size: 18),
              label: const Text("Change Date Range"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: _showDateRangeDialog,
            ),
          ],
        ),
      ),
    );
  }

  // ============ DATE RANGE DIALOG WITH RESTRICTIONS ============
  void _showDateRangeDialog() {
    final startController = TextEditingController(text: startMonthController.text);
    final endController = TextEditingController(text: endMonthController.text);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Row(
                children: [
                  Icon(Icons.date_range, color: Colors.blue, size: 24),
                  SizedBox(width: 12),
                  Text(
                    "Select Date Range",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_joiningDate != null)
                Text(
                  "Available from ${DateFormat('MMM yyyy').format(_joiningDate!)}",
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(height: 16),

              // Date Fields
              _buildModernDateField("Start Month", startController, true),
              const SizedBox(height: 16),
              _buildModernDateField("End Month", endController, false),
              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (startController.text.isEmpty || endController.text.isEmpty) {
                          toast.showToast("Please select both dates", Colors.orange, Colors.white);
                          return;
                        }

                        // Validate date range
                        final startDate = DateTime.parse('${startController.text}-01');
                        final endDate = DateTime.parse('${endController.text}-01');

                        if (startDate.isAfter(endDate)) {
                          toast.showToast("Start month cannot be after end month", Colors.orange, Colors.white);
                          return;
                        }

                        if (_joiningDate != null && startDate.isBefore(DateTime(_joiningDate!.year, _joiningDate!.month, 1))) {
                          toast.showToast("Cannot select month before joining date", Colors.orange, Colors.white);
                          return;
                        }

                        startMonthController.text = startController.text;
                        endMonthController.text = endController.text;
                        Navigator.pop(context);
                        _loadPaymentDetails();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Apply"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernDateField(String label, TextEditingController controller, bool isStartDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectMonth(context, controller, isStartDate),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Text(
                  controller.text.isEmpty ? "Select month" : _formatMonthDisplay(controller.text),
                  style: TextStyle(
                    fontSize: 16,
                    color: controller.text.isEmpty ? Colors.grey.shade400 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============ UTILITY METHODS ============
  String _formatCurrency(int amount) => '৳${amount.toStringAsFixed(0)}';

  String _formatMonthDisplay(String month) {
    try {
      final date = DateTime.parse('$month-01');
      return DateFormat('MMM yyyy').format(date);
    } catch (e) {
      return month;
    }
  }

  String _formatDate(String date) {
    try {
      final parsedDate = DateTime.parse(date);
      return DateFormat('dd MMM yyyy').format(parsedDate);
    } catch (e) {
      return date;
    }
  }

  (Color, IconData) _getStatusProperties(String status) {
    switch (status) {
      case 'Fully Paid': return (Colors.green, Icons.check_circle);
      case 'Partially Paid': return (Colors.orange, Icons.pending);
      case 'Unpaid': return (Colors.red, Icons.pending_outlined);
      default: return (Colors.grey, Icons.circle);
    }
  }

  // ============ BUILD METHOD ============
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Profile Header
          _buildProfileHeader(),

          // Summary Cards
          _buildSummaryCards(),

          // Date Filter
          _buildDateFilterCard(),

          // Payment History
          if (isLoading) _buildLoadingState() else _buildPaymentHistory(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Loading Payment Details...",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// Add this custom month picker dialog class in the same file
class _MonthPickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime joiningDate;
  final bool isStartDate;
  final DateTime? startDate;

  const _MonthPickerDialog({
    required this.initialDate,
    required this.joiningDate,
    required this.isStartDate,
    this.startDate,
  });

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int selectedYear;
  late int selectedMonth;

  @override
  void initState() {
    super.initState();
    selectedYear = widget.initialDate.year;
    selectedMonth = widget.initialDate.month;
  }

  bool _isMonthDisabled(int year, int month) {
    final checkDate = DateTime(year, month);
    final joiningMonth = DateTime(widget.joiningDate.year, widget.joiningDate.month);

    // Disable if before joining month
    if (checkDate.isBefore(joiningMonth)) return true;

    // For end date, also disable if before start date
    if (!widget.isStartDate && widget.startDate != null) {
      final startMonth = DateTime(widget.startDate!.year, widget.startDate!.month);
      if (checkDate.isBefore(startMonth)) return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    widget.isStartDate ? "Select Start Month" : "Select End Month",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Info text
            Text(
              "Available from ${DateFormat('MMM yyyy').format(widget.joiningDate)}",
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),

            // Year Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      selectedYear--;
                    });
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    selectedYear.toString(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      selectedYear++;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Month Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final monthNumber = index + 1;
                final isSelected = selectedMonth == monthNumber && selectedYear == DateTime(selectedYear, selectedMonth).year;
                final isDisabled = _isMonthDisabled(selectedYear, monthNumber);

                return InkWell(
                  onTap: isDisabled ? null : () {
                    setState(() {
                      selectedMonth = monthNumber;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDisabled
                          ? Colors.grey.shade200
                          : isSelected
                          ? Colors.blue
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDisabled
                            ? Colors.grey.shade300
                            : isSelected
                            ? Colors.blue.shade700
                            : Colors.blue.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        months[index],
                        style: TextStyle(
                          color: isDisabled
                              ? Colors.grey.shade400
                              : isSelected
                              ? Colors.white
                              : Colors.blue.shade700,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final selected = DateTime(selectedYear, selectedMonth);
                      Navigator.pop(context, selected);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("OK"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}