import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import '../localDB/DBHelper.dart';

class SellRecordScreen extends StatefulWidget {
  final VoidCallback? onRefresh;

  const SellRecordScreen({super.key, this.onRefresh});

  @override
  State<SellRecordScreen> createState() => _SellRecordScreenState();
}

class _SellRecordScreenState extends State<SellRecordScreen> {
  List<Map<String, dynamic>> sales = [];
  List<Map<String, dynamic>> saleItems = [];
  List<String> categoryNames = [];
  String? selectedCategory;
  List<Map<String, dynamic>> menuItems = [];
  Map<String, dynamic>? selectedMenuItem;
  int quantity = 1;
  final TextEditingController _discountController = TextEditingController(text: "0");
  String? _currentlyExpandedId;

  @override
  void initState() {
    super.initState();
    loadSales();
    loadCategories();
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
    final discountController = TextEditingController(text: sale['discount'].toString());
    String selectedMethod = sale['paymentMethod'] ?? 'Cash';
    String selectedStatus = sale['paymentStatus'] ?? 'Unpaid';
    int quantity = 1;
    await loadSaleItems(sale['id']);
    List<Map<String, dynamic>> existingItems = saleItems.map((e) => Map<String, dynamic>.from(e)).toList();
    String? selectedCategoryInDialog;
    Map<String, dynamic>? selectedMenuItemInDialog;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double subtotal = 0;
            double discount = 0;
            double grandTotal = 0;

            void recalculateTotals() {
              subtotal = existingItems.fold(0.0, (sum, item) => sum + (item['quantity'] * item['price']));
              discount = double.tryParse(discountController.text) ?? 0.0;
              grandTotal = subtotal - discount;
              if (grandTotal < 0) grandTotal = 0.0;
            }
            recalculateTotals();

            void addOrUpdateItem() {
              if (selectedMenuItemInDialog != null) {
                final existingIndex = existingItems.indexWhere(
                        (item) => item['menuItemId'] == selectedMenuItemInDialog!['id']
                );

                if (existingIndex != -1) {
                  setStateDialog(() {
                    existingItems[existingIndex]['quantity'] += quantity;
                    existingItems[existingIndex]['total'] = existingItems[existingIndex]['quantity'] * existingItems[existingIndex]['price'];
                    recalculateTotals();
                  });
                } else {
                  setStateDialog(() {
                    existingItems.add({
                      'menuItemId': selectedMenuItemInDialog!['id'],
                      'name': selectedMenuItemInDialog!['name'],
                      'price': selectedMenuItemInDialog!['price'],
                      'quantity': quantity,
                      'total': selectedMenuItemInDialog!['price'] * quantity,
                    });
                    recalculateTotals();
                  });
                }
                quantity = 1;
                selectedMenuItemInDialog = null;
              }
            }
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              backgroundColor: Colors.white,
              child: Scaffold(
                appBar: AppBar(
                  title: Text("Update: ${sale['id']}"),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      DropdownSearch<String>(
                        items: categoryNames,
                        selectedItem: selectedCategoryInDialog,
                        popupProps: const PopupProps.menu(showSearchBox: true),
                        dropdownBuilder: (_, item) => Text(item ?? "Select Category"),
                        onChanged: (val) async {
                          selectedCategoryInDialog = val;
                          await loadMenuItemsByCategory(val!);
                          setStateDialog(() {});
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownSearch<Map<String, dynamic>>(
                        items: menuItems,
                        selectedItem: selectedMenuItemInDialog,
                        itemAsString: (item) => item['name'],
                        popupProps: const PopupProps.menu(showSearchBox: true),
                        dropdownBuilder: (_, item) => Text(item?['name'] ?? "Select Menu Item"),
                        onChanged: (val) {
                          setStateDialog(() => selectedMenuItemInDialog = val);
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Text("Quantity: "),
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              if (quantity > 1) setStateDialog(() => quantity--);
                            },
                          ),
                          Text(quantity.toString()),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              setStateDialog(() => quantity++);
                            },
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: addOrUpdateItem,
                            child: const Text("Add Item"),
                          ),
                        ],
                      ),
                      const Divider(),
                      const Text("Existing Items (Edit/Delete):"),
                      ...existingItems.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // FIX: Wrapped text in an Expanded widget
                                    Text("${item['name']} x ${item['quantity']}", overflow: TextOverflow.visible, maxLines: null),
                                    Text("৳${item['price']} x ${item['quantity']} = ৳${item['total']}"),
                                  ],
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove),
                                        onPressed: () {
                                          if (item['quantity'] > 1) {
                                            setStateDialog(() {
                                              item['quantity'] -= 1;
                                              item['total'] = item['quantity'] * item['price'];
                                              recalculateTotals();
                                            });
                                          }
                                        },
                                      ),
                                      Text(item['quantity'].toString()),
                                      IconButton(
                                        icon: const Icon(Icons.add),
                                        onPressed: () {
                                          setStateDialog(() {
                                            item['quantity'] += 1;
                                            item['total'] = item['quantity'] * item['price'];
                                            recalculateTotals();
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      setStateDialog(() {
                                        existingItems.remove(item);
                                        recalculateTotals();
                                      });
                                    },
                                  ),
                                ],
                              )
                            ],
                          ),
                        );
                      }),
                      const Divider(),
                      TextField(
                        controller: discountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Discount"),
                        onChanged: (_) => setStateDialog(() => recalculateTotals()),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedMethod,
                        items: ["Cash", "bKash", "Card", "Nagad"]
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) => setStateDialog(() => selectedMethod = val!),
                        decoration: const InputDecoration(labelText: "Payment Method"),
                      ),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        items: ["Unpaid", "Paid"]
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) => setStateDialog(() => selectedStatus = val!),
                        decoration: const InputDecoration(labelText: "Status"),
                      ),
                      const SizedBox(height: 10),
                      Text("Subtotal: ৳${subtotal.toStringAsFixed(2)}"),
                      Text("Discount: ৳${discount.toStringAsFixed(2)}"),
                      Text(
                        "Total Payable: ৳${grandTotal.toStringAsFixed(2)}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          final finalItems = existingItems.map((e) => {
                            'id': e['menuItemId'] ?? e['id'],
                            'name': e['name'],
                            'price': e['price'],
                            'quantity': e['quantity'],
                            'total': e['total']
                          }).toList();

                          await DBHelper.updateFullSale(
                            id: sale['id'],
                            paymentMethod: selectedMethod,
                            paymentStatus: selectedStatus,
                            discount: discount,
                            total: grandTotal,
                            items: finalItems,
                          );

                          Navigator.pop(context);
                          loadSales();
                        },
                        child: const Text("Update Sale"),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> loadCategories() async {
    final allItems = await DBHelper.getMenuItems();
    final uniqueCategories = allItems.map((e) => e['categoryName'].toString()).toSet().toList();
    setState(() {
      categoryNames = uniqueCategories;
    });
  }

  Future<void> loadMenuItemsByCategory(String categoryName) async {
    final allItems = await DBHelper.getMenuItems();
    final filteredItems = allItems.where((item) => item['categoryName'] == categoryName).toList();
    setState(() {
      menuItems = filteredItems;
      selectedMenuItem = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Correctly calculate totals from sales data
    double totalSales = sales.fold(0, (sum, sale) => sum + (sale['total'] as double));
    double totalDiscount = sales.fold(0, (sum, sale) => sum + (sale['discount'] as double));
    double paidTotal = sales.where((s) => s['paymentStatus'] == 'Paid').fold(0, (sum, sale) => sum + (sale['total'] as double));
    double unpaidTotal = sales.where((s) => s['paymentStatus'] == 'Unpaid').fold(0, (sum, sale) => sum + (sale['total'] as double));
    double grossTotal = sales.fold(0, (sum, sale) => sum + (sale['total'] as double) + (sale['discount'] as double));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sell Records"),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Refreshing data..."),
                  duration: Duration(seconds: 1),
                ),
              );
              await loadSales();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummaryGrid(
              context: context,
              totalSales: totalSales,
              totalDiscount: totalDiscount,
              paidTotal: paidTotal,
              unpaidTotal: unpaidTotal,
              grossTotal: grossTotal,
            ),
            const SizedBox(height: 16),
            sales.isEmpty
                ? const Center(child: Text("No records found."))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sales.length,
              itemBuilder: (context, index) {
                final sale = sales[index];
                final isExpanded = _currentlyExpandedId == sale['id'];
                final isPaid = sale['paymentStatus'] == 'Paid';
                final cardColor = isPaid ? Colors.green.shade50 : Colors.orange.shade50;
                final textColor = isPaid ? Colors.green.shade800 : Colors.orange.shade800;

                return Dismissible(
                  key: Key(sale['id']),
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
                      showUpdateDialog(sale);
                      return false;
                    }
                    return await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Confirm Delete"),
                        content: const Text("Are you sure you want to delete this sale?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text("Delete"),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) {
                    if (direction == DismissDirection.startToEnd) {
                      deleteSale(sale['id']);
                      if (isExpanded) {
                        setState(() => _currentlyExpandedId = null);
                      }
                    }
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: cardColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () async {
                        setState(() => _currentlyExpandedId = isExpanded ? null : sale['id']);
                        if (!isExpanded) await loadSaleItems(sale['id']);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  child: Text(
                                    sale['paymentMethod'].toString().substring(0, 2),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "ID: ${sale['id']}",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        "Discount: ৳${sale['discount']}",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "৳${sale['total']}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _buildPaymentStatusButton(sale),
                            ),
                            if (isExpanded)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(),
                                  if (saleItems.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(child: CircularProgressIndicator()),
                                    )
                                  else
                                    ...saleItems.map((item) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded( // FIX: Wrapped this text in Expanded
                                            child: Text(
                                              "${item['name']} x ${item['quantity']}",
                                              style: const TextStyle(fontSize: 14),
                                              overflow: TextOverflow.visible,
                                              maxLines: null,
                                            ),
                                          ),
                                          Text(
                                            "৳${item['total']}",
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    )),
                                  Text(
                                    "Date: ${sale['date']}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textColor,
                                    ),
                                    textAlign: TextAlign.center,
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
            ),
          ],
        ),
      ),
    );
  }

  // **MODIFIED METHOD**
  Widget _buildSummaryGrid({
    required BuildContext context,
    required double totalSales,
    required double totalDiscount,
    required double paidTotal,
    required double unpaidTotal,
    required double grossTotal,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.2,
        children: [
          _buildSummaryCard("Total Sales", totalSales, Theme.of(context).primaryColor, Colors.white),
          _buildSummaryCard("Total Discount", totalDiscount, Colors.red, Colors.red.shade50),
          _buildSummaryCard("Paid Total", paidTotal, Colors.green, Colors.green.shade50),
          _buildSummaryCard("Unpaid Total", unpaidTotal, Colors.orange, Colors.orange.shade50),
          _buildSummaryCard("Gross Total", grossTotal, Colors.blue, Colors.blue.shade50),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color, Color bgColor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text("৳${amount.toStringAsFixed(2)}",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStatusButton(Map<String, dynamic> sale) {
    final isPaid = sale['paymentStatus'] == 'Paid';
    final buttonText = isPaid ? 'Mark Unpaid' : 'Mark Paid';
    final buttonColor = isPaid ? Colors.grey[300] : Colors.green[100];
    final textColor = isPaid ? Colors.black : Colors.green[800];

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: buttonColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: () async {
        final newStatus = isPaid ? 'Unpaid' : 'Paid';
        await DBHelper.updatePaymentStatus(
          id: sale['id'],
          paymentStatus: newStatus,
        );
        loadSales();
      },
      child: Text(
        buttonText,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
