import 'package:flutter/material.dart';
import '../localDB/DBHelper.dart';

class CostingRecordScreen extends StatefulWidget {
  const CostingRecordScreen({super.key});

  @override
  State<CostingRecordScreen> createState() => _CostingRecordScreenState();
}

class _CostingRecordScreenState extends State<CostingRecordScreen> {
  List<Map<String, dynamic>> costingRecords = [];

  @override
  void initState() {
    super.initState();
    loadCostingRecords();
  }

  Future<void> loadCostingRecords() async {
    final db = await DBHelper.db;
    final result = await db.query('costing_records');
    setState(() {
      costingRecords = result;
    });
  }

  void deleteCostingRecord(int id) async {
    final db = await DBHelper.db;
    await db.delete('costing_records', where: 'id = ?', whereArgs: [id]);
    loadCostingRecords();
  }

  void showUpdateDialog(Map<String, dynamic> record) {
    final TextEditingController descController = TextEditingController(text: record['description']);
    final TextEditingController amountController = TextEditingController(text: record['amount'].toString());
    String selectedType = record['type'];
    String selectedStatus = record['paymentStatus'];
    showDialog(
      context: context,
      barrierDismissible: false, // Not cancelable
      builder: (_) {
        return AlertDialog(
          title: const Text("Update Costing Record"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                items: ["Ingredients","Meal Bill","Rent","Staff Salary", "Bill", "Maintenance", "Others"]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) selectedType = val;
                },
                decoration: const InputDecoration(labelText: "Type"),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: "Description"),
              ),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Amount"),
              ),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await DBHelper.updateCostingRecord(id: record['id'], date: record['date'], type: selectedType, description: descController.text, amount: double.parse(amountController.text), paymentStatus: selectedStatus);
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

  @override
  Widget build(BuildContext context) {
    double totalCost = costingRecords.fold(0, (sum, item) => sum + (item['amount'] as double));
    return Scaffold(
      appBar: AppBar(title: const Text("Costing Records")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total Cost:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text("৳${totalCost.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: costingRecords.length,
              itemBuilder: (context, index) {
                final record = costingRecords[index];
                return Dismissible(
                  key: Key(record['id'].toString()),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  secondaryBackground: Container(
                    color: Colors.blue,
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
                          content: const Text("Are you sure you want to delete this record?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
                          ],
                        ),
                      );
                      return confirm;
                    }
                  },
                  onDismissed: (_) => deleteCostingRecord(record['id']),
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      title: Text(record['type']),
                      subtitle: Text(record['description']),
                      trailing: SizedBox(
                        height: 60, // Limit height to avoid overflow
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("৳${record['amount']}"),
                            const SizedBox(height: 4),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: record['paymentStatus'] == 'Paid' ? Colors.green[100] : Colors.orange[100],
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () async {
                                final newStatus = record['paymentStatus'] == 'Paid' ? 'Pending' : 'Paid';
                                await DBHelper.updateCostingPaymentStatus(
                                  id: record['id'],
                                  paymentStatus: newStatus,
                                );
                                loadCostingRecords();
                              },
                              child: Text(
                                record['paymentStatus'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: record['paymentStatus'] == 'Paid' ? Colors.green[800] : Colors.orange[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),


                  ),
                );
              },
            ),
            
          ),
           FloatingActionButton(
            onPressed: _showAddCostDialog,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }


  void _showAddCostDialog() {
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    String selectedType = "Ingredients";
    String selectedStatus = "Pending";
    String selectedDate = DateTime.now().toIso8601String().split("T").first;
    showDialog(
      context: context,
      barrierDismissible: false, // Not cancelable
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => false, // Disable back button
          child: Dialog(
            insetPadding: EdgeInsets.zero,
            child: Scaffold(
              appBar: AppBar(
                title: const Text("Add New Costing"),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        items: ["Ingredients","Meal Bill","Rent","Staff Salary", "Bill", "Maintenance", "Others"]
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) selectedType = val;
                        },
                        decoration: const InputDecoration(labelText: "Type"),
                      ),
                      // Description
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(labelText: "Description"),
                      ),
                      // Amount
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Amount"),
                      ),
                      // Date Picker
                      TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "Date",
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
                          }
                        },
                      ),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        items: ["Pending", "Paid"]
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) selectedStatus = val;
                        },
                        decoration: const InputDecoration(labelText: "Status"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final description = descriptionController.text.trim();
                          final amount = double.tryParse(amountController.text) ?? 0.0;

                          if (description.isNotEmpty && amount > 0) {
                            await DBHelper.insertCostingRecord(
                              date: selectedDate,
                              type: selectedType,
                              description: description,
                              amount: amount,
                              paymentStatus: "Pending",
                            );
                            Navigator.pop(context);
                            loadCostingRecords();
                          }
                        },
                        child: const Text("Add"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }


}
