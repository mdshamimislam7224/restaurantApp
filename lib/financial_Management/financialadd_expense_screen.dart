import 'package:flutter/material.dart';
import '../alertDialog/customDialog.dart';
import 'CustomField.dart';
import 'financial_ApiService.dart';

class financialadd_expense_screen extends StatefulWidget {
  @override
  State<financialadd_expense_screen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<financialadd_expense_screen> {
  // Form controllers
  final amount = TextEditingController();
  final description = TextEditingController();

  // Filter controllers
  final searchIdController = TextEditingController();
  final searchMethodController = TextEditingController();
  final startDateController = TextEditingController();
  final endDateController = TextEditingController();

  // Data list for displaying records
  List data = [];
  bool loading = true;

  // Pagination
  int currentPage = 1;
  int totalPages = 1;
  int totalRecords = 0;
  int recordsPerPage = 10;

  // Available payment methods
  final List<String> paymentMethods = [
    'Cash',
    'Bkash',
    'Nagad',
    'Rocket',
    'Card',
    'Bank Transfer',
    'Other'
  ];

  final List<String> expandSource = [
    'Food',
    'Bill',
    'Rent',
    'Salary',
    'Personal',
    'Maintenance Cost',
    'Transportation',
    'Entertainment',
    'Healthcare',
    'Education',
    'Other'
  ];

  String selectedPaymentMethod = 'Cash';
  String selectedExpense = 'Food';
  customDialog? customdialog;

  @override
  void initState() {
    super.initState();
    customdialog = customDialog(context);
    fetchData();
  }

  @override
  void dispose() {
    amount.dispose();
    description.dispose();
    searchIdController.dispose();
    searchMethodController.dispose();
    startDateController.dispose();
    endDateController.dispose();
    super.dispose();
  }

  Future<void> fetchData() async {
    setState(() => loading = true);

    final response = await FinancialApiService.getList(
      sheet: "Expenses",
      page: currentPage,
      limit: recordsPerPage,
      searchId: searchIdController.text.isEmpty ? null : searchIdController.text,
      searchMethod: searchMethodController.text.isEmpty ? null : searchMethodController.text,
      startDate: startDateController.text.isEmpty ? null : startDateController.text,
      endDate: endDateController.text.isEmpty ? null : endDateController.text,
    );

    setState(() {
      data = response['data'] ?? [];
      totalPages = response['pagination']['totalPages'] ?? 1;
      totalRecords = response['pagination']['total'] ?? 0;
      loading = false;
    });
  }

  // Show filter dialog
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Filter Expense Records"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomField(
                label: "Search by ID (e.g., expense2912)",
                controller: searchIdController,
              ),
              SizedBox(height: 12),
              CustomField(
                label: "Payment Method (e.g., Cash, Bkash)",
                controller: searchMethodController,
              ),
              SizedBox(height: 12),
              // Start Date Field
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    startDateController.text =
                    "${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}";
                  }
                },
                child: AbsorbPointer(
                  child: CustomField(
                    label: "Start Date (MM/DD/YYYY)",
                    controller: startDateController,
                  ),
                ),
              ),
              SizedBox(height: 12),
              // End Date Field
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    endDateController.text =
                    "${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}";
                  }
                },
                child: AbsorbPointer(
                  child: CustomField(
                    label: "End Date (MM/DD/YYYY)",
                    controller: endDateController,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Clear filters
              searchIdController.clear();
              searchMethodController.clear();
              startDateController.clear();
              endDateController.clear();
              Navigator.pop(context);
              currentPage = 1;
              fetchData();
            },
            child: Text("Clear"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              currentPage = 1;
              fetchData();
            },
            child: Text("Apply"),
          ),
        ],
      ),
    );
  }

  // Show add expense dialog
  void _showAddExpenseDialog() {
    amount.clear();
    description.clear();
    selectedPaymentMethod = 'Cash';
    selectedExpense = 'Food';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text("Add New Expense"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Expense Category *",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: selectedExpense,
                      isExpanded: true,
                      underline: SizedBox(),
                      icon: Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
                      items: expandSource.map((String method) {
                        return DropdownMenuItem<String>(
                          value: method,
                          child: Text(method),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedExpense = newValue!;
                        });
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  CustomField(
                    label: "Amount *",
                    controller: amount,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                  SizedBox(height: 16),
                  CustomField(
                    label: "Description",
                    controller: description,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Payment Method *",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: selectedPaymentMethod,
                      isExpanded: true,
                      underline: SizedBox(),
                      icon: Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
                      items: paymentMethods.map((String method) {
                        return DropdownMenuItem<String>(
                          value: method,
                          child: Text(method),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedPaymentMethod = newValue!;
                        });
                      },
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
              ElevatedButton(
                onPressed: () async {
                  if (amount.text.isEmpty || selectedExpense.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Amount and Category are required"))
                    );
                    return;
                  }
                  else if (double.tryParse(amount.text) == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Please enter a valid amount"))
                    );
                    return;
                  }
                  else {
                    customdialog!.showLoading("Saving...", subtitle: "Please wait");
                    final result = await FinancialApiService.addExpense(
                      selectedExpense,
                      description.text,
                      amount.text,
                      selectedPaymentMethod,
                    );
                    if (result['success'] == true) {
                      if (customdialog != null) {
                        customdialog!.dismiss();
                      }
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Expense saved successfully ✔"))
                      );
                      fetchData();
                    } else {
                      if (customdialog != null) {
                        customdialog!.dismiss();
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Failed to save ❌"))
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  // Show edit dialog
  void _showEditDialog(Map<String, dynamic> item) {
    amount.text = item["Amount"]?.toString() ?? "";
    description.text = item["Description"]?.toString() ?? "";
    selectedExpense = item["Category"]?.toString() ?? "Food";
    selectedPaymentMethod = item["Payment Method"]?.toString() ?? "Cash";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text("Edit Expense"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Expense Category *",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: selectedExpense,
                      isExpanded: true,
                      underline: SizedBox(),
                      icon: Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
                      items: expandSource.map((String method) {
                        return DropdownMenuItem<String>(
                          value: method,
                          child: Text(method),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedExpense = newValue!;
                        });
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  CustomField(
                    label: "Amount *",
                    controller: amount,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                  SizedBox(height: 16),
                  CustomField(
                    label: "Description",
                    controller: description,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Payment Method *",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: selectedPaymentMethod,
                      isExpanded: true,
                      underline: SizedBox(),
                      icon: Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
                      items: paymentMethods.map((String method) {
                        return DropdownMenuItem<String>(
                          value: method,
                          child: Text(method),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedPaymentMethod = newValue!;
                        });
                      },
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
              ElevatedButton(
                onPressed: () async {
                  if (amount.text.isEmpty || selectedExpense.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Amount and Category are required"))
                    );
                    return;
                  }
                  else {
                    customdialog!.showLoading("Updating...", subtitle: "Please wait");
                    final result = await FinancialApiService.updateExpense(
                      id: item["ID"].toString(),
                      category: selectedExpense,
                      description: description.text,
                      amount: amount.text,
                      method: selectedPaymentMethod,
                    );

                    if (result['success'] == true) {
                      if (customdialog != null) {
                        customdialog!.dismiss();
                      }
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Expense updated successfully ✔"))
                      );
                      fetchData();
                    } else {
                      if (customdialog != null) {
                        customdialog!.dismiss();
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Failed to update ❌"))
                      );
                    }

                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
                child: Text("Update"),
              ),
            ],
          );
        },
      ),
    );
  }

  // Delete expense
  Future<void> _deleteExpense(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirm Delete"),
        content: Text("Are you sure you want to delete this expense record?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      customdialog!.showLoading("Deleting...", subtitle: "Please wait");
      final result = await FinancialApiService.deleteExpense(id);
      if (result['success'] == true) {
        if (customdialog != null) {
          customdialog!.dismiss();
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Expense deleted successfully ✔"))
        );
        fetchData();
      } else {
        if (customdialog != null) {
          customdialog!.dismiss();
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to delete ❌"))
        );
      }
    }
  }

  String formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return "${date.day}/${date.month}/${date.year}";
    } catch (e) {
      return dateString;
    }
  }

  String formatCurrency(String amount) {
    try {
      double value = double.parse(amount);
      return "৳${value.toStringAsFixed(2)}";
    } catch (e) {
      return "৳$amount";
    }
  }

  String _calculateTotal() {
    double total = 0;
    for (var item in data) {
      try {
        total += double.parse(item["Amount"]?.toString() ?? "0");
      } catch (e) {
        total += 0;
      }
    }
    return total.toStringAsFixed(2);
  }

  Widget _buildExpenseList() {
    if (loading) {
      return Center(child: CircularProgressIndicator());
    }

    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
            SizedBox(height: 20),
            Text(
              "No expense records yet",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 10),
            Text(
              "Tap the + button to add your first expense",
              style: TextStyle(color: Colors.grey[500]),
            ),
            SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _showAddExpenseDialog,
              icon: Icon(Icons.add),
              label: Text("Add Your First Expense"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchData,
      child: Column(
        children: [
          // Summary Card
          Card(
            margin: EdgeInsets.all(12),
            elevation: 3,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text(
                        totalRecords.toString(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text("Total Entries", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        "৳${_calculateTotal()}",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      Text("Page Total", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: _showAddExpenseDialog,
                    child: Icon(Icons.add, color: Colors.white),
                    backgroundColor: Colors.red,
                  ),
                ],
              ),
            ),
          ),

          // List of expense records
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: data.length,
              itemBuilder: (context, index) {
                var item = data[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red[100],
                      child: Icon(Icons.shopping_cart, color: Colors.red),
                    ),
                    title: Text(
                      item["Category"]?.toString() ?? "Unknown Category",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4),
                        Text(
                          item["Description"]?.toString() ?? "No description",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Chip(
                              label: Text(
                                item["Payment Method"]?.toString() ?? "Cash",
                                style: TextStyle(fontSize: 10, color: Colors.white),
                              ),
                              backgroundColor: Colors.blue,
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                            ),
                            SizedBox(width: 8),
                            Text(
                              formatDate(item["Date"]?.toString() ?? ""),
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatCurrency(item["Amount"]?.toString() ?? "0"),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => _showEditDialog(item),
                              child: Icon(Icons.edit, size: 18, color: Colors.blue),
                            ),
                            SizedBox(width: 8),
                            InkWell(
                              onTap: () => _deleteExpense(item["ID"].toString()),
                              child: Icon(Icons.delete, size: 18, color: Colors.red),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text("Expense Details"),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _detailRow("ID:", item["ID"]?.toString() ?? ""),
                                _detailRow("Category:", item["Category"]?.toString() ?? ""),
                                _detailRow("Amount:", formatCurrency(item["Amount"]?.toString() ?? "0")),
                                _detailRow("Method:", item["Payment Method"]?.toString() ?? ""),
                                _detailRow("Date:", formatDate(item["Date"]?.toString() ?? "")),
                                _detailRow("Description:", item["Description"]?.toString() ?? "No description"),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text("Close"),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // Pagination Controls
          if (totalPages > 1)
            Container(
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.first_page),
                    onPressed: currentPage > 1 ? () {
                      setState(() => currentPage = 1);
                      fetchData();
                    } : null,
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_left),
                    onPressed: currentPage > 1 ? () {
                      setState(() => currentPage--);
                      fetchData();
                    } : null,
                  ),
                  Text(
                    "Page $currentPage of $totalPages",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right),
                    onPressed: currentPage < totalPages ? () {
                      setState(() => currentPage++);
                      fetchData();
                    } : null,
                  ),
                  IconButton(
                    icon: Icon(Icons.last_page),
                    onPressed: currentPage < totalPages ? () {
                      setState(() => currentPage = totalPages);
                      fetchData();
                    } : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Expense Records"),
        actions: [
          // Add button in AppBar
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: "Filter",
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchData,
            tooltip: "Refresh",
          ),
        ],
      ),
      body: _buildExpenseList(),
      // FloatingActionButton that's always visible
    );
  }
}