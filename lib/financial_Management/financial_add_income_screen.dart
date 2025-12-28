import 'package:flutter/material.dart';
import 'CustomField.dart';
import 'financial_ApiService.dart';

class financial_add_income_screen extends StatefulWidget {
  @override
  State<financial_add_income_screen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<financial_add_income_screen> {
  // Form controllers
  final amount = TextEditingController();
  final source = TextEditingController();
  final description = TextEditingController();

  // Data list for displaying records
  List data = [];
  bool loading = true;

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

  String selectedPaymentMethod = 'Cash'; // Default value

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  @override
  void dispose() {
    amount.dispose();
    source.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> fetchData() async {
    setState(() => loading = true);
    data = await financial_ApiService.getList("Income");
    setState(() => loading = false);
  }

  // Show add income dialog
  void _showAddIncomeDialog() {
    // Clear form fields
    source.clear();
    amount.clear();
    description.clear();
    selectedPaymentMethod = 'Cash';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text("Add New Income"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomField(
                    label: "Source *",
                    controller: source,
                   // hintText: "e.g., Daily Sales, Catering",
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
                  if (amount.text.isEmpty || source.text.isEmpty) {
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

                  final ok = await financial_ApiService.addIncome(
                    source.text,
                    description.text,
                    amount.text,
                    selectedPaymentMethod,
                  );

                  if (ok) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Income saved successfully ✔"))
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

  // Format date to readable format
  String formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return "${date.day}/${date.month}/${date.year}";
    } catch (e) {
      return dateString;
    }
  }

  // Format currency
  String formatCurrency(String amount) {
    try {
      double value = double.parse(amount);
      return "৳${value.toStringAsFixed(2)}";
    } catch (e) {
      return "৳$amount";
    }
  }

  // Calculate total income
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

  // Build the income list
  Widget _buildIncomeList() {
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
              "No income records yet",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 10),
            Text(
              "Tap + to add your first income",
              style: TextStyle(color: Colors.grey[500]),
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
                          color: Colors.green,
                        ),
                      ),
                      Text("Total Income", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // List of income records
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
                      backgroundColor: Colors.green[100],
                      child: Icon(Icons.currency_rupee, color: Colors.green),
                    ),
                    title: Text(
                      item["Source"]?.toString() ?? "Unknown Source",
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
                            color: Colors.green[700],
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
                          title: Text("Income Details"),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _detailRow("ID:", item["ID"]?.toString() ?? ""),
                                _detailRow("Source:", item["Source"]?.toString() ?? ""),
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
        title: Text("Income Records"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchData,
            tooltip: "Refresh",
          ),
        ],
      ),
      body: _buildIncomeList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddIncomeDialog,
        child: Icon(Icons.add),
        backgroundColor: Colors.green,
        tooltip: "Add New Income",
      ),
    );
  }
}