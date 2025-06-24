import 'package:flutter/material.dart';
import '../localDB/DBHelper.dart';

class SellRecordScreen extends StatefulWidget {
  const SellRecordScreen({super.key});

  @override
  State<SellRecordScreen> createState() => _SellRecordScreenState();
}

class _SellRecordScreenState extends State<SellRecordScreen> {
  List<Map<String, dynamic>> sales = [];
  List<Map<String, dynamic>> saleItems = [];

  @override
  void initState() {
    super.initState();
    loadSales();
  }

  Future<void> loadSales() async {
    final db = await DBHelper.db;
    final result = await db.query('sales', orderBy: 'date DESC');
    setState(() {
      sales = result;
    });
  }

  Future<void> loadSaleItems(String saleId) async {
    final db = await DBHelper.db;
    final result = await db.query('sales_items', where: 'saleId = ?', whereArgs: [saleId]);
    setState(() {
      saleItems = result;
    });
  }

  void deleteSale(String id) async {
    final db = await DBHelper.db;
    await db.delete('sales_items', where: 'saleId = ?', whereArgs: [id]);
    await db.delete('sales', where: 'id = ?', whereArgs: [id]);
    loadSales();
  }

  void showUpdateDialog(Map<String, dynamic> sale) async {
    final TextEditingController discountController =
    TextEditingController(text: sale['discount'].toString());
    final TextEditingController totalController =
    TextEditingController(text: sale['total'].toString());
    String selectedMethod = sale['paymentMethod'] ?? 'Cash';
    String selectedStatus = sale['paymentStatus'] ?? 'Unpaid';

    await loadSaleItems(sale['id']);
    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Update Sale Entry"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...saleItems.map((item) {
                      final qtyController = TextEditingController(text: item['quantity'].toString());
                      return ListTile(
                        title: Text(item['name']),
                        subtitle: Text("Price: ${item['price']}"),
                        trailing: SizedBox(
                          width: 50,
                          child: TextField(
                            controller: qtyController,
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              item['quantity'] = int.tryParse(value) ?? 1;
                              item['total'] = item['quantity'] * item['price'];
                            },
                          ),
                        ),
                      );
                    }).toList(),
                    TextField(
                      controller: discountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Discount"),
                    ),
                    DropdownButton<String>(
                      value: selectedMethod,
                      items: ["Cash", "Card", "Mobile"]
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() => selectedMethod = val);
                        }
                      },
                    ),
                    DropdownButton<String>(
                      value: selectedStatus,
                      items: ["Unpaid", "Paid"]
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() => selectedStatus = val);
                        }
                      },
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
                    final updatedItems = saleItems.map((e) => {
                      'id': e['id'],
                      'quantity': e['quantity'],
                      'total': e['quantity'] * e['price']
                    }).toList();
                    await DBHelper.updateFullSale(
                      id: sale['id'],
                      paymentMethod: selectedMethod,
                      paymentStatus: selectedStatus,
                      discount: double.tryParse(discountController.text) ?? 0.0,
                      total: double.tryParse(totalController.text) ?? 0.0,
                      items: updatedItems,
                    );
                    Navigator.pop(context);
                    loadSales();
                  },
                  child: const Text("Update"),
                )
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sell Records")),
      body: ListView.builder(
        itemCount: sales.length,
        itemBuilder: (context, index) {
          final sale = sales[index];
          return Card(
            child: ListTile(
              title: Text("ID: ${sale['id']}, Total: ${sale['total']}"),
              subtitle: Text("Date: ${sale['date']} - ${sale['paymentStatus']}"),
              onTap: () => showUpdateDialog(sale),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => deleteSale(sale['id']),
              ),
            ),
          );
        },
      ),
    );
  }
}
