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
  DateTime? _selectedDate;
  DateTime? _startDate;
  DateTime? _endDate;
  String _dateFilterType = "all"; // Changed default to "all"

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
      // First filter by type
      List<Map<String, dynamic>> tempRecords = List.from(allCostingRecords);

      if (_selectedFilterType != "All") {
        tempRecords = tempRecords
            .where((record) => record['type'] == _selectedFilterType)
            .toList();
      }

      // Then filter by date
      if (_dateFilterType == "single" && _selectedDate != null) {
        String dateString = DateFormat('yyyy-MM-dd').format(_selectedDate!);
        tempRecords = tempRecords
            .where((record) {
          try {
            String recordDate = record['date']?.toString() ?? '';
            // Handle different date formats
            if (recordDate.contains(' ')) {
              recordDate = recordDate.split(' ')[0];
            }
            return recordDate == dateString;
          } catch (e) {
            return false;
          }
        })
            .toList();
      } else if (_dateFilterType == "range" && _startDate != null && _endDate != null) {
        tempRecords = tempRecords.where((record) {
          try {
            String dateStr = record['date']?.toString() ?? '';
            if (dateStr.contains(' ')) {
              dateStr = dateStr.split(' ')[0];
            }
            DateTime recordDate = DateTime.parse(dateStr);
            // Check if recordDate is between startDate and endDate (inclusive)
            return (recordDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
                recordDate.isBefore(_endDate!.add(const Duration(days: 1))));
          } catch (e) {
            return false;
          }
        }).toList();
      }

      filteredCostingRecords = tempRecords;
    });
  }

  void deleteCostingRecord(String id) async {
    final db = await DBHelper.db;
    await db.delete('costing_records', where: 'id = ?', whereArgs: [id]);
    loadCostingRecords();
  }

  void _showDateFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Filter by Date"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text("All Dates"),
                      leading: Radio<String>(
                        value: "all",
                        groupValue: _dateFilterType,
                        onChanged: (value) {
                          setState(() {
                            _dateFilterType = value!;
                          });
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text("Single Date"),
                      leading: Radio<String>(
                        value: "single",
                        groupValue: _dateFilterType,
                        onChanged: (value) {
                          setState(() {
                            _dateFilterType = value!;
                          });
                        },
                      ),
                      trailing: _dateFilterType == "single"
                          ? TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2023),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedDate = picked;
                            });
                          }
                        },
                        child: Text(
                          _selectedDate != null
                              ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                              : "Select Date",
                        ),
                      )
                          : null,
                    ),
                    ListTile(
                      title: const Text("Date Range"),
                      leading: Radio<String>(
                        value: "range",
                        groupValue: _dateFilterType,
                        onChanged: (value) {
                          setState(() {
                            _dateFilterType = value!;
                          });
                        },
                      ),
                      subtitle: _dateFilterType == "range"
                          ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate ?? DateTime.now(),
                                firstDate: DateTime(2023),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() {
                                  _startDate = picked;
                                });
                              }
                            },
                            child: Text(
                              _startDate != null
                                  ? "From: ${DateFormat('dd/MM/yyyy').format(_startDate!)}"
                                  : "Select Start Date",
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _endDate ?? DateTime.now(),
                                firstDate: _startDate ?? DateTime(2023),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() {
                                  _endDate = picked;
                                });
                              }
                            },
                            child: Text(
                              _endDate != null
                                  ? "To: ${DateFormat('dd/MM/yyyy').format(_endDate!)}"
                                  : "Select End Date",
                            ),
                          ),
                        ],
                      )
                          : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _dateFilterType = "all";
                      _selectedDate = null;
                      _startDate = null;
                      _endDate = null;
                    });
                    _filterCostingRecords();
                  },
                  child: const Text("Clear"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _filterCostingRecords();
                  },
                  child: const Text("Apply"),
                ),
              ],
            );
          },
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

  Widget _buildSummaryCard(String title, double amount, Color color, Color bgColor) {
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

            // Filter Controls Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Filters",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Type Filter
                      DropdownButtonFormField<String>(
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
                      const SizedBox(height: 12),
                      // Date Filter Button
                      ElevatedButton.icon(
                        onPressed: _showDateFilterDialog,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _dateFilterType == "all"
                              ? "All Dates"
                              : _dateFilterType == "single" && _selectedDate != null
                              ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                              : _dateFilterType == "range" && _startDate != null && _endDate != null
                              ? "${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}"
                              : "Filter by Date",
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          foregroundColor: Colors.blue.shade800,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      // Clear filters button if any filter is active
                      if (_dateFilterType != "all" || _selectedFilterType != "All")
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _dateFilterType = "all";
                                _selectedFilterType = "All";
                                _selectedDate = null;
                                _startDate = null;
                                _endDate = null;
                              });
                              _filterCostingRecords();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade50,
                              foregroundColor: Colors.red.shade800,
                              minimumSize: const Size(double.infinity, 40),
                            ),
                            child: const Text("Clear All Filters"),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Records List
            const SizedBox(height: 8),
            filteredCostingRecords.isEmpty
                ? Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No records found",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (_dateFilterType != "all" || _selectedFilterType != "All")
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _dateFilterType = "all";
                          _selectedFilterType = "All";
                          _selectedDate = null;
                          _startDate = null;
                          _endDate = null;
                        });
                        _filterCostingRecords();
                      },
                      child: const Text("Clear all filters"),
                    ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: filteredCostingRecords.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final record = filteredCostingRecords[index];
                final isPaid = record['paymentStatus'] == 'Paid';
                final cardColor = isPaid ? Colors.green.shade50 : Colors.orange.shade50;
                final buttonText = isPaid ? 'Mark as Pending' : 'Mark as Paid';
                final buttonColor = isPaid ? Colors.orange.shade100 : Colors.green.shade100;
                final textColor = isPaid ? Colors.orange.shade800 : Colors.green.shade800;
                final newStatus = isPaid ? 'Pending' : 'Paid';

                // Format date for display
                String displayDate = record['date']?.toString() ?? '';
                try {
                  if (displayDate.contains(' ')) {
                    displayDate = displayDate.split(' ')[0];
                  }
                  DateTime date = DateTime.parse(displayDate);
                  displayDate = DateFormat('dd/MM/yyyy').format(date);
                } catch (e) {
                  // Keep original format if parsing fails
                }

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
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record['type'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            displayDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
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
            const SizedBox(height: 80),
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
    final TextEditingController dateController = TextEditingController();

    String selectedType = "Ingredients";
    String selectedStatus = "Pending";

    // Initialize with current date
    DateTime initialDate = DateTime.now();
    String selectedDate = DateFormat('yyyy-MM-dd').format(initialDate);
    dateController.text = DateFormat('dd/MM/yyyy').format(initialDate);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                            if (val != null) {
                              setState(() {
                                selectedType = val;
                              });
                            }
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
                          controller: dateController,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: initialDate,
                              firstDate: DateTime(2023),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() {
                                initialDate = picked;
                                selectedDate = DateFormat('yyyy-MM-dd').format(picked);
                                dateController.text = DateFormat('dd/MM/yyyy').format(picked);
                              });
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
                            if (val != null) {
                              setState(() {
                                selectedStatus = val;
                              });
                            }
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

                                  // Generate ID
                                  final now = DateTime.now();
                                  final timePart = "${now.hour}${now.minute}${now.second}${now.millisecond}";
                                  final datePart = DateFormat('ddMMMyyyy').format(initialDate);
                                  final costingID = "${datePart}_$timePart";

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
      },
    );
  }

  void showUpdateDialog(Map<String, dynamic> record) {
    final TextEditingController descController =
    TextEditingController(text: record['description']);
    final TextEditingController amountController =
    TextEditingController(text: record['amount'].toString());
    final TextEditingController dateController = TextEditingController();

    String selectedType = record['type'];
    String selectedStatus = record['paymentStatus'];

    // Parse date from record
    DateTime initialDate;
    try {
      String dateStr = record['date']?.toString() ?? '';
      if (dateStr.contains(' ')) {
        dateStr = dateStr.split(' ')[0];
      }
      initialDate = DateTime.parse(dateStr);
    } catch (e) {
      initialDate = DateTime.now();
    }

    String selectedDate = DateFormat('yyyy-MM-dd').format(initialDate);
    dateController.text = DateFormat('dd/MM/yyyy').format(initialDate);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text("Update Costing Record"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Date Picker Field
                    TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: "Date",
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.calendar_today),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      controller: dateController,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initialDate,
                          firstDate: DateTime(2023),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            initialDate = picked;
                            selectedDate = DateFormat('yyyy-MM-dd').format(picked);
                            dateController.text = DateFormat('dd/MM/yyyy').format(picked);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
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
                        if (val != null) {
                          setState(() {
                            selectedType = val;
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: "Type",
                        border: OutlineInputBorder(),
                      ),
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
                        if (val != null) {
                          setState(() {
                            selectedStatus = val;
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: "Status",
                        border: OutlineInputBorder(),
                      ),
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
                    // Validate inputs
                    if (descController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Description cannot be empty')),
                      );
                      return;
                    }

                    final amount = double.tryParse(amountController.text);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid amount')),
                      );
                      return;
                    }

                    await DBHelper.updateCostingRecord(
                        id: record['id'].toString(),
                        date: selectedDate,
                        type: selectedType,
                        description: descController.text,
                        amount: amount,
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
      },
    );
  }
}