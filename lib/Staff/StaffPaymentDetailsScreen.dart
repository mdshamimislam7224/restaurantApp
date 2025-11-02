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

class StaffPaymentDetailsScreen extends StatefulWidget {
  const StaffPaymentDetailsScreen({Key? key}) : super(key: key);

  @override
  State<StaffPaymentDetailsScreen> createState() => _StaffPaymentDetailsScreenState();
}

class _StaffPaymentDetailsScreenState extends State<StaffPaymentDetailsScreen> {
  // Constants
  static const _paymentApiUrl = "https://script.google.com/macros/s/AKfycbxJgf70wa2BMQ65h4x0BkeXEQ9XrFBCdwEGCQduCxJyfYCdFeO43rKhGHDnCZbyKP28/exec?action=recordPartialPayment";
  static const _timeoutDuration = Duration(seconds: 30);

  // Controllers & State
  final Toast_Message toast = Toast_Message();
  final TextEditingController startMonthController = TextEditingController();
  final TextEditingController endMonthController = TextEditingController();

  bool isLoading = false;
  bool hasData = false;
  StaffPaymentData? paymentData;
  List<Map<String, dynamic>> staffBasicList = [];

  @override
  void initState() {
    super.initState();
    _initializeDates();
    _loadStaffBasicList();
    fetchPaymentDetails();
  }

  void _initializeDates() {
    final now = DateTime.now();
    startMonthController.text = DateFormat('yyyy-MM').format(DateTime(now.year, now.month - 1, 1));
    endMonthController.text = DateFormat('yyyy-MM').format(now);
  }

  // ============ API METHODS ============
  Future<void> _loadStaffBasicList() async {
    try {
      final response = await http.get(
          Uri.parse("${apiClass.baseUrlStaff}?action=getStaffListBasic")
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        setState(() {
          staffBasicList = (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('Error loading staff list: $e');
    }
  }

  Future<void> fetchPaymentDetails({String? searchQuery}) async {
    if (startMonthController.text.isEmpty || endMonthController.text.isEmpty) {
      toast.showToast("Please select date range", Colors.orange, Colors.white);
      return;
    }

    setState(() => isLoading = true);

    final dialog = customDialog(context);
    dialog.showLoading(
        searchQuery == null ? "Loading Payment Details..." : "Searching for: $searchQuery",
        subtitle: "Please wait"
    );

    try {
      final url = _buildPaymentDetailsUrl(searchQuery);
      print('Fetching URL: $url');

      final response = await http.get(Uri.parse(url)).timeout(_timeoutDuration);
      await _handlePaymentDetailsResponse(response, dialog, searchQuery);
    } catch (e) {
      _handleApiError(e, dialog);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _buildPaymentDetailsUrl(String? searchQuery) {
    String url = '${apiClass.baseUrlStaff}?action=getStaffPaymentDetailsByRange'
        '&startMonth=${startMonthController.text}'
        '&endMonth=${endMonthController.text}';

    if (searchQuery != null && searchQuery.isNotEmpty) {
      url += '&searchIdOrName=${Uri.encodeComponent(searchQuery)}';
    }
    return url;
  }

  Future<void> _handlePaymentDetailsResponse(
      http.Response response, customDialog dialog, String? searchQuery) async {
    print('Response Status: ${response.statusCode}');
    print('Response Body: ${response.body}');

    dialog.dismiss();

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);

      if (responseData['status'] == 'success') {
        setState(() {
          paymentData = StaffPaymentDetailsResponse.fromJson(responseData).data;
          hasData = true;
        });

        _showSuccessToast(searchQuery);
      } else {
        _handlePaymentDetailsError(responseData);
      }
    } else {
      customDialog(context).showError("Server Error", "Failed to load data: ${response.statusCode}");
    }
  }

  void _showSuccessToast(String? searchQuery) {
    final message = searchQuery != null
        ? "Search completed - Found ${paymentData?.totalStaff ?? 0} results"
        : "Data loaded successfully";
    toast.showToast(message, Colors.green, Colors.white);
  }

  void _handlePaymentDetailsError(Map<String, dynamic> responseData) {
    if (responseData['message']?.contains("No employees available") == true) {
      setState(() {
        hasData = true;
        paymentData = null;
      });
      toast.showToast("No employees found for search criteria", Colors.orange, Colors.white);
    } else {
      customDialog(context).showError("Error", responseData['message'] ?? "Failed to load data");
    }
  }

  void _handleApiError(dynamic e, customDialog dialog) {
    dialog.dismiss();

    if (e is http.ClientException || e is SocketException) {
      customDialog(context).showError("Network Error", "Please check your internet connection");
    } else if (e is TimeoutException) {
      customDialog(context).showError("Timeout Error", "Request took too long. Please try again.");
    } else {
      customDialog(context).showError("Error", "An unexpected error occurred");
    }
    print('Error: $e');
  }
  // ============ PAYMENT PROCESSING ============
  Future<void> _processPayment({
    required String employeeId,
    required String employeeName,
    required String salaryMonth,
    required double amount,
    required String notes,
  }) async {
    final dialog = customDialog(context);
    dialog.showLoading("Processing Payment...", subtitle: "Please wait");

    try {
      final payload = _buildPaymentPayload(employeeId, salaryMonth, amount, notes);
      final response = await http.post(Uri.parse(_paymentApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(_timeoutDuration);

      final finalResponse = await _handleRedirect(response);
      await _handlePaymentResponse(finalResponse, dialog, employeeId, employeeName);
    } catch (e) {
      _handleApiError(e, dialog);
    }
  }

  Map<String, dynamic> _buildPaymentPayload(
      String employeeId, String salaryMonth, double amount, String notes
      ) {
    return {
      'employeeId': employeeId,
      'paymentAmount': amount,
      'salaryMonth': salaryMonth,
      'paymentDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'notes': notes,
    };
  }

  Future<http.Response> _handleRedirect(http.Response response) async {
    if (_isRedirectStatus(response.statusCode)) {
      final newLocation = response.headers['location'];
      if (newLocation != null) {
        print('Following redirect to: $newLocation');
        return await http.get(Uri.parse(newLocation)).timeout(_timeoutDuration);
      }
    }
    return response;
  }

  bool _isRedirectStatus(int statusCode) {
    return statusCode == HttpStatus.found ||
        statusCode == HttpStatus.movedPermanently ||
        statusCode == HttpStatus.seeOther ||
        statusCode == HttpStatus.temporaryRedirect ||
        statusCode == HttpStatus.permanentRedirect;
  }

  Future<void> _handlePaymentResponse(
      http.Response response, customDialog dialog, String employeeId, String employeeName
      ) async {
    print('Final Response Status: ${response.statusCode}');
    print('Final Response Body: ${response.body}');

    dialog.dismiss();

    if (response.statusCode == 200) {
      try {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          toast.showToast("Payment recorded successfully", Colors.green, Colors.white);
          await fetchPaymentDetails();
        } else {
          _showPaymentErrorDialog(responseData, employeeId, employeeName);
        }
      } catch (e) {
        customDialog(context).showError("Error", "Invalid response format from server");
      }
    } else {
      customDialog(context).showError("Payment Failed", "Server error: ${response.statusCode}");
    }
  }

  // ============ DATE SELECTION ============
  Future<void> _selectMonth(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );

    if (picked != null) {
      controller.text = DateFormat('yyyy-MM').format(picked);
    }
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );

    if (picked != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  // ============ UI COMPONENTS ============
  Widget _buildSummaryCard() {
    if (paymentData == null) return const SizedBox();

    final totalDueAmount = paymentData!.staffDetails.fold(
        0, (sum, staff) => sum + staff.paymentSummary.totalDueAllTime
    );
    final totalPaidAmount = paymentData!.staffDetails.fold(
        0, (sum, staff) => sum + staff.paymentSummary.totalPaidAllTime
    );
    final partialCount = paymentData!.staffDetails.fold(
        0, (sum, staff) => sum + staff.paymentSummary.partiallyPaidMonths.length
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Period: ${paymentData!.startMonth} to ${paymentData!.endMonth}"),
                    Text("Total Staff: ${paymentData!.totalStaff}"),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.screen_search_desktop_sharp, size: 40, color: Colors.blue),
                  onPressed: _showDateRangeDialog,
                  tooltip: 'Select Date Range',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSummaryItem("Total Paid", Colors.green, totalPaidAmount),
                _buildSummaryItem("Partial", Colors.orange, partialCount),
                _buildSummaryItem("Total Due", Colors.red, totalDueAmount),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, Color color, int count) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(count.toString(),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: TextStyle(fontSize: 12, color: color), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffList() {
    if (paymentData == null) {
      return _buildEmptyState(
          icon: Icons.people_outline,
          message: "No staff data available for selected range",
          action: _showDateRangeDialog,
          actionText: "Select Different Range"
      );
    }

    if (paymentData!.staffDetails.isEmpty) {
      return _buildEmptyState(
          icon: Icons.people_outline,
          message: "No staff data available"
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: paymentData!.staffDetails.length,
        itemBuilder: (context, index) => _buildStaffCard(paymentData!.staffDetails[index]),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    VoidCallback? action,
    String? actionText,
  }) {
    return Container(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(fontSize: 16, color: Colors.grey)),
            if (action != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(actionText!),
                onPressed: action,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStaffCard(StaffDetail staff) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            staff.employeeName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(staff.employeeName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ID: ${staff.employeeId}"),
            Text("Position: ${staff.position}"),
            Text("Salary: ${_formatCurrency(staff.basicSalary)}"),
          ],
        ),
        trailing: staff.paymentSummary.dueMonths.isNotEmpty ? _buildDueBadge(staff) : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildActionButtons(staff),
                const SizedBox(height: 16),
                _buildPaymentSummary(staff.paymentSummary),
                const SizedBox(height: 16),
                const Text("Monthly Payments:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...staff.monthlyPayments.map((monthly) => _buildMonthlyPayment(monthly, staff)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueBadge(StaffDetail staff) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red),
      ),
      child: Text(
        "${staff.paymentSummary.dueMonths.length} due",
        style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActionButtons(StaffDetail staff) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.payment, size: 18),
            label: const Text("Pay Salary"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue),
            ),
            onPressed: () => _showPaySalaryDialog(staff),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.history, size: 18),
            label: const Text("History"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: const BorderSide(color: Colors.green),
            ),
            onPressed: () => _showPaymentHistory(staff),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSummary(PaymentSummary summary) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Payment Summary", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildSummaryRow("Total Paid:", _formatCurrency(summary.totalPaidAllTime)),
          _buildSummaryRow("Total Due:", _formatCurrency(summary.totalDueAllTime),
              isDue: summary.totalDueAllTime > 0),
          _buildSummaryRow("Fully Paid Months:", "${summary.fullyPaidMonths.length}"),
          _buildSummaryRow("Due Months:", "${summary.dueMonths.length}",
              isDue: summary.dueMonths.length > 0),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isDue = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: TextStyle(
          color: isDue ? Colors.red : Colors.green,
          fontWeight: isDue ? FontWeight.bold : FontWeight.normal,
        )),
      ],
    );
  }

  Widget _buildMonthlyPayment(MonthlyPayment monthly, StaffDetail staff) {
    final (statusColor, statusIcon) = _getStatusProperties(monthly.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: statusColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
        color: statusColor.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_formatMonthDisplay(monthly.month),
                  style: const TextStyle(fontWeight: FontWeight.bold))),
              _buildStatusBadge(monthly.status, statusColor),
              if (monthly.remaining > 0) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.payment, size: 18, color: Colors.blue),
                  onPressed: () => _showPaySpecificMonthDialog(staff, monthly),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Paid: ${_formatCurrency(monthly.totalPaid)}"),
              Text("Remaining: ${_formatCurrency(monthly.remaining)}"),
            ],
          ),
          if (monthly.payments.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text("Payment Details:",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ...monthly.payments.map(_buildPaymentDetail),
          ],
        ],
      ),
    );
  }

  (Color, IconData) _getStatusProperties(String status) {
    switch (status) {
      case 'Fully Paid': return (Colors.green, Icons.check_circle);
      case 'Partially Paid': return (Colors.orange, Icons.pending);
      case 'Unpaid': return (Colors.red, Icons.cancel);
      default: return (Colors.grey, Icons.circle);
    }
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPaymentDetail(PaymentDetail payment) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Text(_formatDate(payment.paymentDate), style: const TextStyle(fontSize: 12)),
          const Spacer(),
          Text(_formatCurrency(payment.paidAmount),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ============ DIALOGS ============
  void _showDateRangeDialog() {
    final startController = TextEditingController(text: startMonthController.text);
    final endController = TextEditingController(text: endMonthController.text);
    final nameSearchController = TextEditingController();
    String? selectedStaffId;
    bool searchByName = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(children: [
              Icon(Icons.date_range, color: Colors.blue),
              SizedBox(width: 8),
              Text("Select Date Range", style: TextStyle(color: Colors.blue)),
            ]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Choose the period and search for employees",
                      style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 20),
                  _buildDateField("Start Month *", startController, context),
                  const SizedBox(height: 16),
                  _buildDateField("End Month *", endController, context),
                  const SizedBox(height: 16),
                  _buildSearchTypeToggle(searchByName, setDialogState, nameSearchController),
                  if (!searchByName) _buildIdDropdown(selectedStaffId, setDialogState),
                  if (searchByName) _buildNameSearch(nameSearchController, setDialogState),
                  _buildRangeDisplay(startController, endController),
                  _buildSearchInfo(selectedStaffId, nameSearchController),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
              ),
              _buildLoadButton(selectedStaffId, nameSearchController, startController, endController),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateField(String label, TextEditingController controller, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          decoration: const InputDecoration(
            hintText: "Select month",
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.calendar_today),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          onTap: () => _selectMonth(context, controller),
        ),
      ],
    );
  }

  Widget _buildSearchTypeToggle(bool searchByName, Function setDialogState, TextEditingController nameController) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Search By", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: ChoiceChip(
              label: const Text("Employee ID"),
              selected: !searchByName,
              onSelected: (selected) {
                setDialogState(() {
                  searchByName = false;
                  nameController.clear();
                });
              },
            )),
            const SizedBox(width: 8),
            Expanded(child: ChoiceChip(
              label: const Text("Name"),
              selected: searchByName,
              onSelected: (selected) {
                setDialogState(() {
                  searchByName = true;
                });
              },
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildIdDropdown(String? selectedStaffId, Function setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text("Select Employee ID", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedStaffId,
              isExpanded: true,
              hint: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text("Select Employee ID"),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text("All Employees", style: TextStyle(color: Colors.grey)),
                ),
                ...staffBasicList.map((staff) => DropdownMenuItem(
                  value: staff['staff_id']?.toString() ?? '',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(staff['staff_id']?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(staff['name']?.toString() ?? '',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                )),
              ],
              onChanged: (value) => setDialogState(() => selectedStaffId = value),
            ),
          ),
        ),
        if (selectedStaffId != null) ...[
          const SizedBox(height: 8),
          Text("Selected: $selectedStaffId",
              style: const TextStyle(fontSize: 12, color: Colors.blue, fontStyle: FontStyle.italic)),
        ],
      ],
    );
  }

  Widget _buildNameSearch(TextEditingController controller, Function setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text("Search by Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Enter employee name...",
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixIcon: controller.text.isNotEmpty ? IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () {
                controller.clear();
                setDialogState(() {});
              },
            ) : null,
          ),
          onChanged: (value) => setDialogState(() {}),
        ),
        if (controller.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Searching for names containing: "${controller.text}"',
              style: const TextStyle(fontSize: 12, color: Colors.blue, fontStyle: FontStyle.italic)),
        ],
      ],
    );
  }

  Widget _buildRangeDisplay(TextEditingController start, TextEditingController end) {
    if (start.text.isEmpty || end.text.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
          const SizedBox(width: 4),
          Text("${_formatMonthDisplay(start.text)} - ${_formatMonthDisplay(end.text)}",
              style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSearchInfo(String? selectedStaffId, TextEditingController nameController) {
    if (selectedStaffId == null && nameController.text.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info, size: 16, color: Colors.orange),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              selectedStaffId != null
                  ? "Filtering by ID: $selectedStaffId"
                  : 'Searching for: "${nameController.text}"',
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadButton(
      String? selectedStaffId, TextEditingController nameController,
      TextEditingController startController, TextEditingController endController
      ) {
    final hasFilter = selectedStaffId != null || nameController.text.isNotEmpty;

    return ElevatedButton.icon(
      icon: Icon(hasFilter ? Icons.filter_alt : Icons.search, size: 18),
      label: Text(hasFilter ? "Apply Filter" : "Load All"),
      style: ElevatedButton.styleFrom(
        backgroundColor: hasFilter ? Colors.orange : Colors.blue,
        foregroundColor: Colors.white,
      ),
      onPressed: () {
        if (startController.text.isEmpty || endController.text.isEmpty) {
          toast.showToast("Please select both dates", Colors.orange, Colors.white);
          return;
        }

        startMonthController.text = startController.text;
        endMonthController.text = endController.text;
        Navigator.pop(context);

        final searchQuery = !(nameController.text.isEmpty && selectedStaffId == null)
            ? (selectedStaffId ?? nameController.text)
            : null;

        fetchPaymentDetails(searchQuery: searchQuery);
      },
    );
  }

  // ============ PAYMENT DIALOGS ============
  void _showPaySalaryDialog(StaffDetail staff) {
    final dueMonths = staff.paymentSummary.dueMonths;
    String? selectedMonth;
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Pay Salary - ${staff.employeeName}"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dueMonths.isNotEmpty) ...[
                const Text("Due Months:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...dueMonths.map((due) => Text(
                  "• ${_formatMonthDisplay(due.month)}: ${_formatCurrency(due.dueAmount)} due",
                  style: const TextStyle(color: Colors.red),
                )),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<String>(
                value: selectedMonth,
                decoration: const InputDecoration(labelText: 'Select Month', border: OutlineInputBorder()),
                items: [
                  ...dueMonths.map((due) => DropdownMenuItem(
                    value: due.month,
                    child: Text("${_formatMonthDisplay(due.month)} (Due: ${_formatCurrency(due.dueAmount)})"),
                  )),
                  const DropdownMenuItem(value: 'current', child: Text("Current Month")),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedMonth = value;
                    amountController.text = value == 'current'
                        ? staff.basicSalary.toString()
                        : dueMonths.firstWhere((due) => due.month == value).dueAmount.toString();
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                    labelText: 'Notes (Optional)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => _handlePayNow(
                selectedMonth, amountController.text, staff, notesController.text
            ),
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
  }

  void _handlePayNow(String? selectedMonth, String amount, StaffDetail staff, String notes) {
    if (selectedMonth == null || amount.isEmpty) {
      toast.showToast("Please fill all fields", Colors.orange, Colors.white);
      return;
    }

    final cleanAmount = amount.replaceAll(RegExp(r'[^\d.]'), '');
    if (cleanAmount.isEmpty) {
      toast.showToast("Please enter a valid amount", Colors.orange, Colors.white);
      return;
    }

    try {
      print("selectedMonth: $selectedMonth");
      _processPayment(
        employeeId: staff.employeeId,
        employeeName: staff.employeeName,
        salaryMonth: selectedMonth == 'current'
            ? DateFormat('yyyy-MM').format(DateTime.now())
            : selectedMonth,
        amount: double.parse(cleanAmount),
        notes: notes,
      );
      Navigator.pop(context);
    } catch (e) {
      toast.showToast("Invalid amount format", Colors.red, Colors.white);
    }
  }
  void _showPaySpecificMonthDialog(StaffDetail staff, MonthlyPayment monthly) {
    final amountController = TextEditingController(text: monthly.remaining.toString());
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Pay Salary - ${_formatMonthDisplay(monthly.month)}"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Employee: ${staff.employeeName}"),
              Text("Month: ${_formatMonthDisplay(monthly.month)}"),
              Text("Remaining: ${_formatCurrency(monthly.remaining)}"),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                    labelText: 'Notes (Optional)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => _handleSpecificMonthPayment(
                amountController.text, staff, monthly.month, notesController.text
            ),
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
  }

  void _handleSpecificMonthPayment(String amount, StaffDetail staff, String month, String notes) {
    if (amount.isEmpty) {
      toast.showToast("Please enter amount", Colors.orange, Colors.white);
      return;
    }

    final cleanAmount = amount.replaceAll(RegExp(r'[^\d.]'), '');
    if (cleanAmount.isEmpty) {
      toast.showToast("Please enter a valid amount", Colors.orange, Colors.white);
      return;
    }

    try {
      print("_handleSpecificMonthPayment selectedMonth: $month");
      _processPayment(
        employeeId: staff.employeeId,
        employeeName: staff.employeeName,
        salaryMonth: month,
        amount: double.parse(cleanAmount),
        notes: notes,
      );
      Navigator.pop(context);
    } catch (e) {
      toast.showToast("Invalid amount format", Colors.red, Colors.white);
    }
  }

  void _showPaymentHistory(StaffDetail staff) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text("Payment History - ${staff.employeeName}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: staff.monthlyPayments
                      .expand((monthly) => monthly.payments)
                      .map((payment) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.payment, color: Colors.green),
                      title: Text(_formatCurrency(payment.paidAmount)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${_formatDate(payment.paymentDate)} - ${_formatMonthDisplay(payment.salaryMonth)}"),
                          if (payment.notes.isNotEmpty)
                            Text(payment.notes, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      trailing: Text(
                        payment.totalPaid >= payment.basicSalary ? "Fully Paid" : "Partial",
                        style: TextStyle(
                          color: payment.totalPaid >= payment.basicSalary ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ ADD SALARY DIALOG ============
  void _showAddSalaryDialog() {
    String? selectedStaffId;
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final salaryMonthController = TextEditingController(text: DateFormat('yyyy-MM').format(DateTime.now()));
    final paymentDateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(children: [
              Icon(Icons.payment, color: Colors.green),
              SizedBox(width: 8),
              Text("Add Salary Record"),
            ]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Add new salary payment record",
                      style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 20),
                  _buildStaffDropdown(selectedStaffId, setDialogState, amountController),
                  const SizedBox(height: 16),
                  _buildDateField("Salary Month *", salaryMonthController, context),
                  const SizedBox(height: 16),
                  _buildDateField("Payment Date *", paymentDateController, context),
                  const SizedBox(height: 16),
                  _buildAmountField(amountController),
                  const SizedBox(height: 16),
                  _buildNotesField(notesController),
                  if (selectedStaffId != null) _buildSelectedStaffInfo(selectedStaffId),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add Record"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _handleAddRecord(
                    selectedStaffId, salaryMonthController.text,
                    paymentDateController.text, amountController.text, notesController.text
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStaffDropdown(String? selectedStaffId, Function setDialogState, TextEditingController amountController) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Employee *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedStaffId,
              isExpanded: true,
              hint: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text("Select Employee"),
              ),
              items: staffBasicList.map((staff) {
                final staffId = staff['staff_id']?.toString() ?? '';
                final staffName = staff['name']?.toString() ?? '';
                final staffSalary = staff['salary']?.toString() ?? '0';
                return DropdownMenuItem(
                  value: staffId,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(staffId, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("$staffName - ৳$staffSalary",
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setDialogState(() {
                  selectedStaffId = value;
                  final staff = staffBasicList.firstWhere(
                          (element) => element['staff_id']?.toString() == value, orElse: () => {});
                  amountController.text = staff['salary']?.toString() ?? '0';
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField(TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Payment Amount *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: "Enter amount",
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField(TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Notes (Optional)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Enter notes...",
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildSelectedStaffInfo(String selectedStaffId) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(child: Text("Selected: $selectedStaffId",
              style: const TextStyle(fontSize: 12, color: Colors.blue))),
        ],
      ),
    );
  }

  void _handleAddRecord(
      String? selectedStaffId, String salaryMonth, String paymentDate,
      String amount, String notes
      ) {
    if (selectedStaffId == null || salaryMonth.isEmpty || paymentDate.isEmpty || amount.isEmpty) {
      toast.showToast("Please fill all required fields", Colors.orange, Colors.white);
      return;
    }
    _addSalaryRecord(selectedStaffId, salaryMonth, paymentDate, double.parse(amount), notes);
  }

  Future<void> _addSalaryRecord(
      String employeeId, String salaryMonth, String paymentDate, double amount, String notes
      ) async {
    final dialog = customDialog(context);
    dialog.showLoading("Adding Salary Record...", subtitle: "Please wait");

    try {
      final staff = staffBasicList.firstWhere(
              (element) => element['staff_id']?.toString() == employeeId, orElse: () => {});
      final employeeName = staff['name']?.toString() ?? 'Unknown Staff';

      final payload = {
        'employeeId': employeeId,
        'paymentAmount': amount,
        'salaryMonth': salaryMonth,
        'paymentDate': paymentDate,
        'notes': notes,
      };

      print('Sending payment request: ${json.encode(payload)}');

      final response = await http.post(Uri.parse(_paymentApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(_timeoutDuration);

      final finalResponse = await _handleRedirect(response);
      await _handleAddSalaryResponse(finalResponse, dialog, employeeId, employeeName);
    } catch (e) {
      _handleApiError(e, dialog);
    }
  }

  Future<void> _handleAddSalaryResponse(
      http.Response response, customDialog dialog, String employeeId, String employeeName
      ) async {
    print('Final Response Status: ${response.statusCode}');
    print('Final Response Body: ${response.body}');

    dialog.dismiss();

    if (response.statusCode == 200) {
      try {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          toast.showToast("Salary record added successfully", Colors.green, Colors.white);
          await fetchPaymentDetails();
          if (mounted) Navigator.of(context).pop();
        } else {
          _showPaymentErrorDialog(responseData, employeeId, employeeName);
        }
      } catch (e) {
        customDialog(context).showError("Error", "Invalid response format from server");
      }
    } else {
      customDialog(context).showError("Error", "Server returned status code: ${response.statusCode}");
    }
  }

  // ============ ERROR HANDLING ============
  void _showPaymentErrorDialog(Map<String, dynamic> responseData, String employeeId, String employeeName) {
    final errorMessage = responseData['message'] ?? 'Payment failed';
    final errors = responseData['errors'] ?? [];
    final dueMonths = responseData['dueMonths'] ?? [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Text("Payment Validation Failed", overflow: TextOverflow.ellipsis),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildErrorMessage(errorMessage),
              if (errors.isNotEmpty) _buildErrorDetails(errors),
              if (dueMonths.isNotEmpty) _buildDueMonthsSection(dueMonths),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK", style: TextStyle(color: Colors.blue)),
          ),
          if (dueMonths.isNotEmpty)
            ElevatedButton.icon(
              icon: const Icon(Icons.payment, size: 18),
              label: const Text("Pay Oldest Due"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _payOldestDue(dueMonths, employeeId, employeeName);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String errorMessage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Text(errorMessage,
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _buildErrorDetails(List<dynamic> errors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text("Details:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        ...errors.map((error) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(child: Text(error.toString(),
                  style: TextStyle(fontSize: 13, color: Colors.orange[800]))),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildDueMonthsSection(List<dynamic> dueMonths) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text("Pending Due Months:",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: dueMonths.map(_buildDueMonthItem).toList()),
        ),
        const SizedBox(height: 8),
        const Text("Please clear older dues first before paying for newer months.",
            style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _buildDueMonthItem(dynamic dueMonth) {
    final month = dueMonth['month']?.toString() ?? '';
    final paid = dueMonth['paid'] ?? 0;
    final basicSalary = dueMonth['basicSalary'] ?? 0;
    final remaining = dueMonth['remaining'] ?? 0;
    final status = dueMonth['status']?.toString() ?? '';
    final isJoiningMonth = dueMonth['isJoiningMonth'] ?? false;
    final joiningDate = dueMonth['joiningDate']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        leading: Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: _getStatusColor(status),
            shape: BoxShape.circle,
          ),
        ),
        title: Row(children: [
          Text(_formatMonthDisplay(month),
              style: TextStyle(fontWeight: FontWeight.w600, color: _getStatusColor(status))),
          if (isJoiningMonth) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Text("Joining",
                  style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Due: ${_formatCurrency(remaining)} / ${_formatCurrency(basicSalary)}",
                style: const TextStyle(fontSize: 12)),
            if (isJoiningMonth && joiningDate.isNotEmpty)
              Text("Joined: ${_formatDate(joiningDate)}",
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _getStatusColor(status)),
          ),
          child: Text(status,
              style: TextStyle(fontSize: 10, color: _getStatusColor(status), fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'unpaid': return Colors.red;
      case 'partially paid': return Colors.orange;
      case 'fully paid': return Colors.green;
      default: return Colors.grey;
    }
  }

  void _payOldestDue(List<dynamic> dueMonths, String employeeId, String employeeName) {
    if (dueMonths.isEmpty) return;

    final oldestDue = dueMonths.first;
    _showPaySpecificMonthDialogDirect(
      oldestDue['month']?.toString() ?? '',
      oldestDue['remaining'] ?? 0,
      employeeId,
      employeeName,
    );
  }

  void _showPaySpecificMonthDialogDirect(
      String month, int amount, String employeeId, String employeeName
      ) {
    final amountController = TextEditingController(text: amount.toString());
    final notesController = TextEditingController(text: "Clearing oldest due");
    final paymentDateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Pay Oldest Due"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEmployeeInfo(employeeId, employeeName),
                  const SizedBox(height: 16),
                  _buildMonthInfo(month, amount),
                  const SizedBox(height: 16),
                  _buildDateField("Payment Date *", paymentDateController, context),
                  const SizedBox(height: 16),
                  _buildAmountField(amountController),
                  const SizedBox(height: 16),
                  _buildNotesField(notesController),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => _handleOldestDuePayment(
                    amountController.text, employeeId, employeeName, month, notesController.text
                ),
                child: const Text('Pay Now'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmployeeInfo(String employeeId, String employeeName) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Employee: $employeeName", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text("ID: $employeeId", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMonthInfo(String month, int amount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Month: ${_formatMonthDisplay(month)}", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text("Amount Due: ${_formatCurrency(amount)}",
              style: const TextStyle(fontSize: 14, color: Colors.red)),
        ],
      ),
    );
  }

  void _handleOldestDuePayment(
      String amount, String employeeId, String employeeName, String month, String notes
      ) {
    if (amount.isEmpty) {
      toast.showToast("Please enter amount", Colors.orange, Colors.white);
      return;
    }

    try {
      _processPayment(
        employeeId: employeeId,
        employeeName: employeeName,
        salaryMonth: month,
        amount: double.parse(amount),
        notes: notes,
      );
      Navigator.pop(context);
    } catch (e) {
      toast.showToast("Invalid amount format", Colors.red, Colors.white);
    }
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

  // ============ BUILD METHOD ============
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSalaryDialog,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        child: const Icon(Icons.payment),
        tooltip: 'Add Salary Record',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: [
          if (isLoading) _buildLoadingState(),
          if (hasData && !isLoading) _buildDataState(),
          if (!hasData && !isLoading) _buildInitialState(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Loading payment details..."),
          ],
        ),
      ),
    );
  }

  Widget _buildDataState() {
    return Expanded(
      child: Column(
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 8),
          if (paymentData != null && paymentData!.staffDetails.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Staff Details (${paymentData?.totalStaff ?? 0})",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text("Total Due: ${_formatCurrency(paymentData!.staffDetails.fold(
                      0, (sum, staff) => sum + staff.paymentSummary.totalDueAllTime))}",
                      style: const TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          _buildStaffList(),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("Select date range and load data",
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}