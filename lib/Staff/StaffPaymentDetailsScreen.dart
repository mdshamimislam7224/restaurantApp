// staff_payment_details_screen.dart
import 'dart:convert';
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
  final Toast_Message toast = Toast_Message();
  bool isLoading = false;
  bool hasData = false;

  // Date controllers
  final TextEditingController startMonthController = TextEditingController();
  final TextEditingController endMonthController = TextEditingController();

  StaffPaymentData? paymentData;
  List<Map<String, dynamic>> staffBasicList = [];

  @override
  void initState() {
    super.initState();
    // Set default values (current month and previous month)
    final now = DateTime.now();
    final currentMonth = DateFormat('yyyy-MM').format(now);
    final previousMonth = DateFormat('yyyy-MM').format(
        DateTime(now.year, now.month - 1, 1)
    );


    startMonthController.text = previousMonth;
    endMonthController.text = currentMonth;

    _loadStaffBasicList();
     fetchPaymentDetails();
  }

  Future<void> _loadStaffBasicList() async {
    try {
      final response = await http.get(
          Uri.parse("${apiClass.baseUrlStaff}?action=getStaffListBasic")
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          staffBasicList = data.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('Error loading staff list: $e');
    }
  }
  // NEW: Show date range selector dialog
  // Updated _showDateRangeDialog with search functionality
  // Updated _showDateRangeDialog with spinner for ID and textfield for name
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
            title: Row(
              children: [
                Icon(Icons.date_range, color: Colors.blue),
                SizedBox(width: 8),
                Text("Select Date Range & Search"),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Choose the period and search for employees",
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 20),

                  // Start Month
                  Text(
                    "Start Month *",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: startController,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: "Select start month",
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onTap: () => _selectMonth(context, startController),
                  ),
                  SizedBox(height: 16),

                  // End Month
                  Text(
                    "End Month *",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: endController,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: "Select end month",
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onTap: () => _selectMonth(context, endController),
                  ),
                  SizedBox(height: 16),

                  // Search Type Toggle
                  Text(
                    "Search By",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text("Employee ID"),
                          selected: !searchByName,
                          onSelected: (selected) {
                            setDialogState(() {
                              searchByName = false;
                              nameSearchController.clear();
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Text("Name"),
                          selected: searchByName,
                          onSelected: (selected) {
                            setDialogState(() {
                              searchByName = true;
                              selectedStaffId = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // ID Spinner (Dropdown)
                  if (!searchByName) ...[
                    Text(
                      "Select Employee ID",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedStaffId,
                          isExpanded: true,
                          hint: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text("Select Employee ID"),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text("All Employees", style: TextStyle(color: Colors.grey)),
                            ),
                            ...staffBasicList.map((staff) {
                              final staffId = staff['staff_id']?.toString() ?? '';
                              final staffName = staff['name']?.toString() ?? '';
                              return DropdownMenuItem(
                                value: staffId,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        staffId,
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        staffName,
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedStaffId = value;
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    if (selectedStaffId != null)
                      Text(
                        "Selected: $selectedStaffId",
                        style: TextStyle(fontSize: 12, color: Colors.blue, fontStyle: FontStyle.italic),
                      ),
                  ],

                  // Name Search TextField
                  if (searchByName) ...[
                    Text(
                      "Search by Name",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: nameSearchController,
                      decoration: InputDecoration(
                        hintText: "Enter employee name...",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        suffixIcon: nameSearchController.text.isNotEmpty
                            ? IconButton(
                          icon: Icon(Icons.clear, size: 18),
                          onPressed: () {
                            nameSearchController.clear();
                            setDialogState(() {});
                          },
                        )
                            : null,
                      ),
                      onChanged: (value) {
                        setDialogState(() {});
                      },
                    ),
                    SizedBox(height: 8),
                    if (nameSearchController.text.isNotEmpty)
                      Text(
                        "Searching for names containing: \"${nameSearchController.text}\"",
                        style: TextStyle(fontSize: 12, color: Colors.blue, fontStyle: FontStyle.italic),
                      ),
                  ],

                  SizedBox(height: 16),

                  // Current range display
                  if (startController.text.isNotEmpty && endController.text.isNotEmpty)
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                          SizedBox(width: 4),
                          Text(
                            "${_formatMonthDisplay(startController.text)} - ${_formatMonthDisplay(endController.text)}",
                            style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                  // Search info
                  if (selectedStaffId != null || nameSearchController.text.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(top: 8),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, size: 16, color: Colors.orange),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              selectedStaffId != null
                                  ? "Filtering by ID: $selectedStaffId"
                                  : "Searching for: \"${nameSearchController.text}\"",
                              style: TextStyle(fontSize: 12, color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
              ),
              ElevatedButton.icon(
                icon: Icon(
                  (selectedStaffId == null && nameSearchController.text.isEmpty)
                      ? Icons.search
                      : Icons.filter_alt,
                  size: 18,
                ),
                label: Text(
                  (selectedStaffId == null && nameSearchController.text.isEmpty)
                      ? "Load All"
                      : "Apply Filter",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (selectedStaffId == null && nameSearchController.text.isEmpty)
                      ? Colors.blue
                      : Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (startController.text.isEmpty || endController.text.isEmpty) {
                    toast.showToast("Please select both dates", Colors.orange, Colors.white);
                    return;
                  }

                  // Update the main controllers
                  startMonthController.text = startController.text;
                  endMonthController.text = endController.text;

                  Navigator.pop(context);

                  // Determine search query
                  String? searchQuery;
                  if (!searchByName && selectedStaffId != null) {
                    searchQuery = selectedStaffId; // Search by ID
                  } else if (searchByName && nameSearchController.text.isNotEmpty) {
                    searchQuery = nameSearchController.text; // Search by name
                  }

                  // Call fetchPaymentDetails with search query
                  fetchPaymentDetails(searchQuery: searchQuery);
                },
              ),
            ],
          );
        },
      ),
    );
  }
  // NEW: Simplified header with current range display
  Future<void> fetchPaymentDetails({String? searchQuery}) async {
    if (startMonthController.text.isEmpty || endMonthController.text.isEmpty) {
      toast.showToast("Please select date range", Colors.orange, Colors.white);
      return;
    }

    setState(() {
      isLoading = true;
      hasData = false;
    });

    final dialog = customDialog(context);
    String loadingMessage = searchQuery == null
        ? "Loading Payment Details..."
        : "Searching for: $searchQuery";

    dialog.showLoading(loadingMessage, subtitle: "Please wait");

    try {
      // Build URL with optional search parameter
      String url = '${apiClass.baseUrlStaff}?action=getStaffPaymentDetailsByRange'
          '&startMonth=${startMonthController.text}'
          '&endMonth=${endMonthController.text}';

      // Add search parameter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        url += '&searchIdOrName=${Uri.encodeComponent(searchQuery)}';
      }

      print('Fetching URL: $url');

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          final staffPaymentResponse = StaffPaymentDetailsResponse.fromJson(responseData);
          setState(() {
            paymentData = staffPaymentResponse.data;
            hasData = true;
          });
          dialog.dismiss();

          if (searchQuery != null && searchQuery.isNotEmpty) {
            toast.showToast("Search completed - Found ${paymentData?.totalStaff ?? 0} results", Colors.green, Colors.white);
          } else {
            toast.showToast("Data loaded successfully", Colors.green, Colors.white);
          }
        } else {
          dialog.dismiss();
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
      } else {
        dialog.dismiss();
        customDialog(context).showError("Server Error", "Failed to load data: ${response.statusCode}");
      }
    } on http.ClientException catch (e) {
      dialog.dismiss();
      customDialog(context).showError("Network Error", "Please check your internet connection");
      print('Network error: $e');
    } on Exception catch (e) {
      dialog.dismiss();
      customDialog(context).showError("Error", "An unexpected error occurred");
      print('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildDateRangeSelector() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Select Date Range",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: startMonthController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "Start Month",
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: () => _selectMonth(context, startMonthController),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: endMonthController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "End Month",
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: () => _selectMonth(context, endMonthController),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.search),
                label: Text("Load Payment Details"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: isLoading ? null : fetchPaymentDetails,
              ),
            ),
          ],
        ),
      ),
    );
  }

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



  Widget _buildSummaryCard() {
    if (paymentData == null) return SizedBox();

    final totalDueAmount = paymentData!.staffDetails.fold(0, (sum, staff) => sum + staff.paymentSummary.totalDueAllTime);
    final totalPaidAmount = paymentData!.staffDetails.fold(0, (sum, staff) => sum + staff.paymentSummary.totalPaidAllTime);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Summary",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
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
                  icon: Icon(Icons.screen_search_desktop_sharp, size: 40, color: Colors.blue),
                  onPressed: _showDateRangeDialog,
                  tooltip: 'Select Date Range',
                ),
              ],
            ),

            SizedBox(height: 8),
            Row(
              children: [
                _buildSummaryItem("Total Paid", Colors.green,totalPaidAmount),
                _buildSummaryItem("Partial", Colors.orange,
                    paymentData!.staffDetails.fold(0, (sum, staff) => sum + staff.paymentSummary.partiallyPaidMonths.length)),
                _buildSummaryItem("Total Due", Colors.red,totalDueAmount),
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
        margin: EdgeInsets.only(right: 8),
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffList() {
    if (paymentData == null) {
      return Container(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                "No staff data available for selected range",
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                icon: Icon(Icons.date_range),
                label: Text("Select Different Range"),
                onPressed: _showDateRangeDialog,
              ),
            ],
          ),
        ),
      );
    }

    if (paymentData!.staffDetails.isEmpty) {
      return Container(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                "No staff data available",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: paymentData!.staffDetails.length,
        itemBuilder: (context, index) {
          final staff = paymentData!.staffDetails[index];
          return _buildStaffCard(staff);
        },
      ),
    );
  }


  Widget _buildStaffCard(StaffDetail staff) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            staff.employeeName[0].toUpperCase(),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          staff.employeeName,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ID: ${staff.employeeId}"),
            Text("Position: ${staff.position}"),
            Text("Salary: ${_formatCurrency(staff.basicSalary)}"),
          ],
        ),
        trailing: staff.paymentSummary.dueMonths.isNotEmpty
            ? Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red),
          ),
          child: Text(
            "${staff.paymentSummary.dueMonths.length} due",
            style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
          ),
        )
            : null,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action Buttons
                _buildActionButtons(staff),
                SizedBox(height: 16),

                // Payment Summary
                _buildPaymentSummary(staff.paymentSummary),
                SizedBox(height: 16),

                // Monthly Payments
                Text(
                  "Monthly Payments:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                ...staff.monthlyPayments.map((monthly) => _buildMonthlyPayment(monthly, staff)).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildActionButtons(StaffDetail staff) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: Icon(Icons.payment, size: 18),
            label: Text("Pay Salary"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: BorderSide(color: Colors.blue),
            ),
            onPressed: () => _showPaySalaryDialog(staff),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            icon: Icon(Icons.history, size: 18),
            label: Text("History"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: BorderSide(color: Colors.green),
            ),
            onPressed: () => _showPaymentHistory(staff),
          ),
        ),
      ],
    );
  }
  Widget _buildPaymentSummary(PaymentSummary summary) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Payment Summary",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total Paid:"),
              Text(_formatCurrency(summary.totalPaidAllTime)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total Due:"),
              Text(
                _formatCurrency(summary.totalDueAllTime),
                style: TextStyle(
                  color: summary.totalDueAllTime > 0 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Fully Paid Months:"),
              Text("${summary.fullyPaidMonths.length}"),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Due Months:"),
              Text(
                "${summary.dueMonths.length}",
                style: TextStyle(
                  color: summary.dueMonths.length > 0 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyPayment(MonthlyPayment monthly, StaffDetail staff) {
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.circle;

    switch (monthly.status) {
      case 'Fully Paid':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Partially Paid':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'Unpaid':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
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
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatMonthDisplay(monthly.month),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
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
              if (monthly.remaining > 0) ...[
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.payment, size: 18, color: Colors.blue),
                  onPressed: () => _showPaySpecificMonthDialog(staff, monthly),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Paid: ${_formatCurrency(monthly.totalPaid)}"),
              Text("Remaining: ${_formatCurrency(monthly.remaining)}"),
            ],
          ),
          if (monthly.payments.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              "Payment Details:",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            ...monthly.payments.map((payment) => _buildPaymentDetail(payment)).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentDetail(PaymentDetail payment) {
    return Container(
      margin: EdgeInsets.only(top: 4),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 12, color: Colors.grey),
          SizedBox(width: 4),
          Text(
            _formatDate(payment.paymentDate),
            style: TextStyle(fontSize: 12),
          ),
          Spacer(),
          Text(
            _formatCurrency(payment.paidAmount),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

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
                Text("Due Months:", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ...dueMonths.map((due) => Text(
                  "• ${_formatMonthDisplay(due.month)}: ${_formatCurrency(due.dueAmount)} due",
                  style: TextStyle(color: Colors.red),
                )).toList(),
                SizedBox(height: 16),
              ],
              DropdownButtonFormField<String>(
                value: selectedMonth,
                decoration: InputDecoration(
                  labelText: 'Select Month',
                  border: OutlineInputBorder(),
                ),
                items: [
                  ...dueMonths.map((due) => DropdownMenuItem(
                    value: due.month,
                    child: Text("${_formatMonthDisplay(due.month)} (Due: ${_formatCurrency(due.dueAmount)})"),
                  )),
                  DropdownMenuItem(
                    value: 'current',
                    child: Text("Current Month"),
                  ),
                ],
                onChanged: (value) => selectedMonth = value,
              ),
              SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                  prefixText: '৳',
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (selectedMonth != null && amountController.text.isNotEmpty) {
                _processSalaryPayment(
                  staff.employeeId,
                  staff.employeeName,
                  selectedMonth!,
                  double.parse(amountController.text),
                  notesController.text,
                );
                Navigator.pop(context);
              } else {
                toast.showToast("Please fill all fields", Colors.orange, Colors.white);
              }
            },
            child: Text('Pay Now'),
          ),
        ],
      ),
    );
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
              SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                  prefixText: '৳',
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (amountController.text.isNotEmpty) {
                _processSalaryPayment(
                  staff.employeeId,
                  staff.employeeName,
                  monthly.month,
                  double.parse(amountController.text),
                  notesController.text,
                );
                Navigator.pop(context);
              }
            },
            child: Text('Pay Now'),
          ),
        ],
      ),
    );
  }

  void _showPaymentHistory(StaffDetail staff) {
    // Navigate to payment history screen or show dialog
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                "Payment History - ${staff.employeeName}",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    ...staff.monthlyPayments.expand((monthly) => monthly.payments).map((payment) => Card(
                      margin: EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(Icons.payment, color: Colors.green),
                        title: Text(_formatCurrency(payment.paidAmount)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${_formatDate(payment.paymentDate)} - ${_formatMonthDisplay(payment.salaryMonth)}"),
                            if (payment.notes.isNotEmpty)
                              Text(payment.notes, style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                  ],
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processSalaryPayment(
      String employeeId,
      String employeeName,
      String salaryMonth,
      double amount,
      String notes) async {
    final dialog = customDialog(context);
    dialog.showLoading("Processing Payment...", subtitle: "Please wait");

    try {
      final payload = {
        'employeeId': employeeId,
        'paymentAmount': amount,
        'salaryMonth': salaryMonth == 'current'
            ? DateFormat('yyyy-MM').format(DateTime.now())
            : salaryMonth,
        'paymentDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'notes': notes,
      };

      final response = await http.post(
        Uri.parse('${apiClass.baseUrlStaff}?action=recordPartialPayment'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 30));

      final responseData = json.decode(response.body);

      dialog.dismiss();
      print('Payment Response Status: ${response.statusCode}');
      print('Payment Response Body: ${response.body}');

      if (response.statusCode == 200 && responseData['status'] == 'success') {
        toast.showToast("Payment recorded successfully", Colors.green, Colors.white);
        // Refresh the data
        await fetchPaymentDetails();
      } else {
        customDialog(context).showError(
            "Payment Failed",
            responseData['message'] ?? "Failed to record payment"
        );
      }
    } catch (e) {
      dialog.dismiss();
      customDialog(context).showError("Error", "Failed to process payment: $e");
    }
  }

  String _formatCurrency(int amount) {
    return '৳${amount.toStringAsFixed(0)}';
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (isLoading) ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Loading payment details..."),
                  ],
                ),
              ),
            ),
          ] else if (hasData) ...[
            _buildSummaryCard(),
            SizedBox(height: 8),
            if (paymentData != null && paymentData!.staffDetails.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Staff Details (${paymentData?.totalStaff ?? 0})",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Total Due: ${_formatCurrency(paymentData!.staffDetails.fold(0, (sum, staff) => sum + staff.paymentSummary.totalDueAllTime))}",
                      style: TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 8),
            _buildStaffList(), // This is now properly expanded
          ] else ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
                    SizedBox(height: 16),
                    Text(
                      "Select date range and load data",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
