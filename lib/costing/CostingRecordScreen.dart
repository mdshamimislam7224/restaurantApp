import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../localDB/DBHelper.dart';

class CostingRecordScreen extends StatefulWidget {
  const CostingRecordScreen({super.key});

  @override
  State<CostingRecordScreen> createState() => _CostingRecordScreenState();
}

class _CostingRecordScreenState extends State<CostingRecordScreen> {
  List<Map<String, dynamic>> allCostingRecords = [];
  List<Map<String, dynamic>> filteredCostingRecords = [];
  String _selectedFilterType = "All";
  String? _idDate;


  @override
  void initState() {
    super.initState();
    loadCostingRecords();
  }

  Future<void> loadCostingRecords() async {
    final db = await DBHelper.db;
    final result = await db.query('costing_records');
    setState(() {
      allCostingRecords = result;
      _filterCostingRecords();
    });
  }

  void _filterCostingRecords() {
    setState(() {
      if (_selectedFilterType == "All") {
        filteredCostingRecords = allCostingRecords;
      } else {
        filteredCostingRecords = allCostingRecords
            .where((record) => record['type'] == _selectedFilterType)
            .toList();
      }});
    }

        void deleteCostingRecord(String id) async {
      final db = await DBHelper.db;
      await db.delete('costing_records', where: 'id = ?', whereArgs: [id]);
      loadCostingRecords();
    }

    void showUpdateDialog(Map<String, dynamic> record) {
      final TextEditingController descController =
      TextEditingController(text: record['description']);
      final TextEditingController amountController =
      TextEditingController(text: record['amount'].toString());
      String selectedType = record['type'];
      String selectedStatus = record['paymentStatus'];

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("Update Costing Record"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    items: [
                      "Ingredients",
                      "Meal Bill",
                      "Rent",
                      "Staff Salary",
                      "Bill",
                      "Maintenance",
                      "Others"
                    ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) selectedType = val;
                    },
                    decoration: const InputDecoration(labelText: "Type"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: "Description",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Amount",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    items: ['Pending', 'Paid']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) selectedStatus = val;
                    },
                    decoration: const InputDecoration(labelText: "Status"),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  await DBHelper.updateCostingRecord(
                      id: record['id'].toString(),
                      date: record['date'],
                      type: selectedType,
                      description: descController.text,
                      amount: double.parse(amountController.text),
                      paymentStatus: selectedStatus);
                  Navigator.pop(context);
                  loadCostingRecords();
                },
                child: const Text("Update"),
              ),
            ],
          );
        },
      );
    }

    Widget _buildSummaryGrid(BuildContext context) {
      double totalCost = filteredCostingRecords.fold(
          0, (sum, item) => sum + (item['amount'] as double));
      double paidCost = filteredCostingRecords
          .where((item) => item['paymentStatus'] == 'Paid')
          .fold(0, (sum, item) => sum + (item['amount'] as double));
      double pendingCost = totalCost - paidCost;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildSummaryCard("Total", totalCost, Theme.of(context).primaryColor, Colors.white),
            _buildSummaryCard("Paid", paidCost, Colors.green, Colors.green.shade50),
            _buildSummaryCard("Pending", pendingCost, Colors.orange, Colors.orange.shade50),
          ],
        ),
      );
    }

    Widget _buildSummaryCard(String title, double amount, Color color,Color bgColor) {
      return Card(
        elevation: 1,
        color: bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
              const SizedBox(height: 4),
              Text("৳${amount.toStringAsFixed(2)}",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      );
    }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummaryGrid(context),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: DropdownButtonFormField<String>(
                value: _selectedFilterType,
                decoration: InputDecoration(
                  labelText: "Filter by Type",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: [
                  "All",
                  "Ingredients",
                  "Meal Bill",
                  "Rent",
                  "Staff Salary",
                  "Bill",
                  "Maintenance",
                  "Others"
                ]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedFilterType = val;
                      _filterCostingRecords();
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            // The ListView.builder is now inside the SingleChildScrollView,
            // so we must remove the Expanded widget and let it size itself
            // with shrinkWrap.
            filteredCostingRecords.isEmpty
                ? const Center(child: Text("No records found."))
                : ListView.builder(
              itemCount: filteredCostingRecords.length,
              shrinkWrap: true, // Key change: size to its children
              physics: const NeverScrollableScrollPhysics(), // Key change: let parent scroll
              itemBuilder: (context, index) {
                final record = filteredCostingRecords[index];
                final isPaid = record['paymentStatus'] == 'Paid';
                final cardColor = isPaid ? Colors.green.shade50 : Colors.orange.shade50;
                final buttonText = isPaid ? 'Mark as Pending' : 'Mark as Paid';
                final buttonColor = isPaid ? Colors.orange.shade100 : Colors.green.shade100;
                final textColor = isPaid ? Colors.orange.shade800 : Colors.green.shade800;
                final newStatus = isPaid ? 'Pending' : 'Paid';

                return Dismissible(
                  key: Key(record['id'].toString()),
                  direction: DismissDirection.horizontal,
                  background: Container(
                    color: Colors.red.shade400,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  secondaryBackground: Container(
                    color: Colors.blue.shade400,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.edit, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.endToStart) {
                      showUpdateDialog(record);
                      return false;
                    } else {
                      final confirm = await showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Delete Record"),
                          content: const Text(
                              "Are you sure you want to delete this record?"),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("Cancel")),
                            ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text("Delete")),
                          ],
                        ),
                      );
                      return confirm;
                    }
                  },
                  onDismissed: (_) => deleteCostingRecord(record['id'].toString()),
                  child: Card(
                    elevation: 2,
                    color: cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          record['type'][0],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        record['type'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(record['description']),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "৳${record['amount']}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: buttonColor,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            onPressed: () async {
                              await DBHelper.updateCostingPaymentStatus(
                                id: record['id'].toString(),
                                paymentStatus: newStatus,
                              );
                              loadCostingRecords();
                            },
                            child: Text(
                              buttonText,
                              style: TextStyle(
                                fontSize: 12,
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCostDialog,
        label: const Text("Add New Cost", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Theme.of(context).primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showAddCostDialog() {
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController amountController = TextEditingController();

    String selectedType = "Ingredients";
    String selectedStatus = "Pending";
    String selectedDate = DateTime.now().toIso8601String().split("T").first;
    _idDate = DateFormat('ddMMMyyyy').format(DateTime.now()); // Initialize _idDate

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Add New Costing",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      items: [
                        "Ingredients",
                        "Meal Bill",
                        "Rent",
                        "Staff Salary",
                        "Bill",
                        "Maintenance",
                        "Others"
                      ]
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) selectedType = val;
                      },
                      decoration: const InputDecoration(
                        labelText: "Type",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: "Description",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Amount",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: "Date",
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                      controller: TextEditingController(text: selectedDate),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2023),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          selectedDate = picked.toIso8601String().split("T").first;
                          _idDate = DateFormat('ddMMMyyyy').format(picked);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      items: ["Pending", "Paid"]
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) selectedStatus = val;
                      },
                      decoration: const InputDecoration(
                        labelText: "Status",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final description = descriptionController.text.trim();
                              final amount = double.tryParse(amountController.text) ?? 0.0;
                              final costingID = generateSaleIdFromDate(_idDate!);

                              if (description.isNotEmpty && amount > 0) {
                                await DBHelper.insertCostingRecord(
                                  id: costingID,
                                  date: selectedDate,
                                  type: selectedType,
                                  description: description,
                                  amount: amount,
                                  paymentStatus: selectedStatus,
                                );
                                Navigator.pop(context);
                                loadCostingRecords();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter valid description and amount'),
                                  ),
                                );
                              }
                            },
                            child: const Text("Add"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String generateSaleIdFromDate(String date) {
    final now = DateTime.now();
    final timePart = "${now.hour}${now.minute}${now.second}${now.millisecond}";
    return "${date}_$timePart";
  }
  }