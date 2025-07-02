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
  List<Map<String, dynamic>> filteredSales = [];
  final GlobalKey<_SellRecordScreenState> _sellRecordScreenKey = GlobalKey();
  List<String> categoryNames = [];
  String? selectedCategory;
  List<Map<String, dynamic>> menuItems = [];
  Map<String, dynamic>? selectedMenuItem;
  List<Map<String, dynamic>> selectedItems = [];
  int quantity = 1;
  final TextEditingController _discountController = TextEditingController(text: "0");
  final Map<String, bool> _expandedItems = {}; // Track expanded state for each sale
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
      // Initialize expanded state for each sale
      for (var sale in sales) {
        _expandedItems[sale['id']] = _expandedItems[sale['id']] ?? false;
      }
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
              subtotal = existingItems.fold(0, (sum, item) => sum + (item['quantity'] * item['price']));
              discount = double.tryParse(discountController.text) ?? 0.0;
              grandTotal = subtotal - discount;
              if (grandTotal < 0) grandTotal = 0;
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
                    existingItems[existingIndex]['total'] =
                        existingItems[existingIndex]['quantity'] *
                            existingItems[existingIndex]['price'];
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
              insetPadding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              child: SizedBox(
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
                child: Scaffold(
                  appBar: AppBar(
                    title:  Text("Update: ${sale['id']}"),
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
                        // Category Dropdown (unchanged)
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

                        // Menu Item Dropdown (unchanged)
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
                        // Quantity Controls (unchanged)
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
                              onPressed: addOrUpdateItem, // Updated function
                              child: const Text("Add Item"),
                            ),
                          ],
                        ),
                        const Divider(),

                        // Existing Items List (unchanged)
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
                                      Text("${item['name']}"),
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

                        // Discount Input (unchanged)
                        TextField(
                          controller: discountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Discount"),
                          onChanged: (_) => setStateDialog(() => recalculateTotals()),
                        ),
                        const SizedBox(height: 8),

                        // Payment Method Dropdown (unchanged)
                        DropdownButtonFormField<String>(
                          value: selectedMethod,
                          items: ["Cash", "bKash", "Card", "Nagad"]
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (val) => setStateDialog(() => selectedMethod = val!),
                          decoration: const InputDecoration(labelText: "Payment Method"),
                        ),

                        // Payment Status Dropdown (unchanged)
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          items: ["Unpaid", "Paid"]
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (val) => setStateDialog(() => selectedStatus = val!),
                          decoration: const InputDecoration(labelText: "Status"),
                        ),
                        const SizedBox(height: 10),

                        // Summary (unchanged)
                        Text("Subtotal: ৳${subtotal.toStringAsFixed(2)}"),
                        Text("Discount: ৳${discount.toStringAsFixed(2)}"),
                        Text(
                          "Total Payable: ৳${grandTotal.toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),

                        // Update Button (unchanged)
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
    // Calculate totals (keep your existing calculation logic)
    double totalSales = sales.fold(0, (sum, sale) => sum + (sale['total'] as double));
    double totalDiscount = sales.fold(0, (sum, sale) => sum + (sale['discount'] as double));
    double paidTotal = sales.where((s) => s['paymentStatus'] == 'Paid')
        .fold(0, (sum, sale) => sum + (sale['total'] as double));
    double unpaidTotal = sales.where((s) => s['paymentStatus'] == 'Unpaid')
        .fold(0, (sum, sale) => sum + (sale['total'] as double));

    return Scaffold(
      appBar: AppBar(title: const Text("Sell Records"),actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () async {
            // Show loading indicator
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Refreshing data..."),
                duration: Duration(seconds: 1),
              ),
            );
            await loadSales(); // Reload data
          },
        ),
      ],),

      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWideScreen = constraints.maxWidth > 600;
          int crossAxisCount = isWideScreen ? 4 : 2;

          return Column(
            children: [
              // Summary Cards Grid - Fixed layout
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                childAspectRatio: isWideScreen ? 2.5 : 1.5,
                padding: const EdgeInsets.all(8),
                children: [
                  _buildSummaryCard(
                    context: context,
                    title: "Total Sales",
                    value: totalSales,
                    color: Colors.blue[50]!,
                    icon: Icons.attach_money,
                  ),
                  _buildSummaryCard(
                    context: context,
                    title: "Total Discount",
                    value: totalDiscount,
                    color: Colors.orange[50]!,
                    icon: Icons.discount,
                  ),
                  _buildSummaryCard(
                    context: context,
                    title: "Paid Total",
                    value: paidTotal,
                    color: Colors.green[50]!,
                    icon: Icons.check_circle,
                  ),
                  _buildSummaryCard(
                    context: context,
                    title: "Unpaid Total",
                    value: unpaidTotal,
                    color: Colors.red[50]!,
                    icon: Icons.pending,
                  ),
                ],
              ),
              // Sales List with Color Coding
              Expanded(
                child: ListView.builder(
                  itemCount: sales.length,
                  itemBuilder: (context, index) {
                    final sale = sales[index];
                    final isExpanded = _currentlyExpandedId == sale['id'];
                    final isPaid = sale['paymentStatus'] == 'Paid';

                    return Dismissible(
                      key: Key(sale['id']),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
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
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text("Delete", style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) {
                        deleteSale(sale['id']);
                        if (isExpanded) {
                          setState(() => _currentlyExpandedId = null);
                        }
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        color: isPaid ? Colors.green[50] : Colors.orange[50], // Color based on status
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isPaid ? Colors.green[100]! : Colors.orange[100]!,
                            width: 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () async {
                            setState(() => _currentlyExpandedId = isExpanded ? null : sale['id']);
                            if (!isExpanded) await loadSaleItems(sale['id']);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("Date: ${sale['date']}",
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isPaid ? Colors.green[800] : Colors.orange[800],
                                                fontWeight: FontWeight.bold,
                                              )),
                                          Text("ID: ${sale['id']}",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isPaid ? Colors.green[800] : Colors.orange[800],
                                              )),
                                          Text("৳${sale['total']} (Discount: ৳${sale['discount']})",
                                              style: TextStyle(
                                                color: isPaid ? Colors.green[800] : Colors.orange[800],
                                              )),
                                          const SizedBox(height: 4),
                                          _buildPaymentStatusButton(sale),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.edit, color: isPaid ? Colors.green[800] : Colors.orange[800]),
                                      onPressed: () => showUpdateDialog(sale),
                                    ),
                                  ],
                                ),
                                if (isExpanded)
                                  Column(
                                    children: [
                                      const Divider(),
                                      if (saleItems.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Center(child: CircularProgressIndicator()),
                                        )
                                      else
                                        ...saleItems.map((item) => ListTile(
                                          title: Text(item['name']),
                                          subtitle: Text("${item['quantity']} × ৳${item['price']} = ৳${item['total']}"),
                                          dense: true,
                                          visualDensity: const VisualDensity(vertical: -4),
                                        )),
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
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required String title,
    required double value,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      color: color,
      child: SizedBox(
        width: 120,
        // Fixed width
        height: 60,  // Fixed height
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "৳${value.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentStatusButton(Map<String, dynamic> sale) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 24),
        backgroundColor: sale['paymentStatus'] == 'Paid'
            ? Colors.grey[300]
            : Colors.green[100],
      ),
      onPressed: () async {
        final newStatus = sale['paymentStatus'] == 'Paid' ? 'Unpaid' : 'Paid';
        await DBHelper.updatePaymentStatus(
          id: sale['id'],
          paymentStatus: newStatus,
        );
        loadSales();
      },
      child: Text(
        sale['paymentStatus'] == 'Paid' ? 'Mark Unpaid' : 'Mark Paid',
        style: TextStyle(
          fontSize: 12,
          color: sale['paymentStatus'] == 'Paid'
              ? Colors.black
              : Colors.green[800],
        ),
      ),
    );
  }
  Future<void> _confirmDelete(BuildContext context, String id) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this sale?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm) {
      deleteSale(id);
      if (_currentlyExpandedId == id) {
        setState(() => _currentlyExpandedId = null);
      }
    }
  }



}