import 'package:flutter/material.dart';

import 'CustomField.dart';
import 'financial_ApiService.dart';

class financialadd_expense_screen extends StatefulWidget {
  @override
  State<financialadd_expense_screen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<financialadd_expense_screen> {
  final amount = TextEditingController();
  final description = TextEditingController();
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
    'Other'
  ];
  List data = [];
  bool loading = true;
  String selectedPaymentMethod = 'Cash'; // Default value
  String selectedExpense = 'Food'; // Default value

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  @override
  void dispose() {
    amount.dispose();
    description.dispose();
    super.dispose();
  }
  Future<void> fetchData() async {
    setState(() => loading = true);
    data = await financial_ApiService.getList("Expenses");
    setState(() => loading = false);
  }
  Future<void> submit() async {
    print("Submitted");
    final ok = await financial_ApiService.addExpense(
      selectedExpense,
      description.text,
      amount.text,
      "Cash",
    );
    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Saved ✔")));
      setState(() {
        description.clear();
        amount.clear();
        selectedPaymentMethod = 'Cash';
        selectedExpense = 'Food';
      });
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed ❌")));
    }
  }

  void _showAddExpenseDialog() {
    // Clear form fields
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
                    // hintText: "Enter amount",
                    // prefixIcon: Icon(Icons.currency_rupee, size: 20),
                  ),

                  SizedBox(height: 16),

                  CustomField(
                    label: "Description",
                    controller: description,
                    // hintText: "Optional notes",
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
                  // Validate inputs
                  if (amount.text.isEmpty || selectedExpense.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Amount and Source are required"))
                    );
                    return;
                  }

                  if (double.tryParse(amount.text) == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Please enter a valid amount"))
                    );
                    return;
                  }

                  final ok = await financial_ApiService.addExpense(
                    selectedExpense,
                    description.text,
                    amount.text,
                    selectedPaymentMethod,
                  );

                  if (ok) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Expense saved successfully ✔"))
                    );

                    // Refresh list data
                    fetchData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Failed to save ❌"))
                    );
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
            ElevatedButton.icon(
              onPressed: _showAddExpenseDialog,
              icon: Icon(Icons.add),
              label: Text("Add First Expense"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
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
          // Summary Card with Add Button
          Card(
            margin: EdgeInsets.all(12),
            elevation: 3,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          Text(
                            data.length.toString(),
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
                              color: Colors.red, // Changed to red for expense
                            ),
                          ),
                          Text("Total Expense", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Add Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showAddExpenseDialog,
                      icon: Icon(Icons.add_circle_outline),
                      label: Text("Add New Expense"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
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
                      backgroundColor: Colors.red[100], // Changed to red for expense
                      child: Icon(Icons.attach_money, color: Colors.red),
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
                                item["Method"]?.toString() ?? "Cash",
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
                            color: Colors.red[700], // Changed to red for expense
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          item["ID"]?.toString() ?? "",
                          style: TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                      ],
                    ),
                    onTap: () {
                      // Show details dialog
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
                                _detailRow("Method:", item["Method"]?.toString() ?? ""),
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
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchData,
            tooltip: "Refresh",
          ),
        ],
      ),
      body: _buildExpenseList(),
    );
  }
}
