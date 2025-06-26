import 'package:dropdown_search/dropdown_search.dart';
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
  List<Map<String, dynamic>> filteredSales = [];
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
    return Scaffold(
      appBar: AppBar(title: const Text("Sell Records")),
      body: ListView.builder(
        itemCount: sales.length,
        itemBuilder: (context, index) {
          final sale = sales[index];
          final isExpanded = _currentlyExpandedId == sale['id'];

          return Dismissible(
            key: Key(sale['id']),
            background: Container(color: Colors.red),
            direction: DismissDirection.endToStart,
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
                _currentlyExpandedId = null;
              }
            },
            child: Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text("ID: ${sale['id']}"),
                    subtitle: Text("Total: ৳${sale['total']} - ${sale['paymentStatus']}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => showUpdateDialog(sale),
                    ),
                    onTap: () async {
                      setState(() {
                        if (isExpanded) {
                          _currentlyExpandedId = null; // Collapse if already expanded
                        } else {
                          _currentlyExpandedId = sale['id']; // Expand this item
                        }
                      });
                      if (_currentlyExpandedId == sale['id']) {
                        await loadSaleItems(sale['id']);
                      }
                    },
                  ),
                  if (isExpanded)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        children: [
                          const Divider(),
                          if (saleItems.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            )
                          else
                            ...saleItems.map((item) => ListTile(
                              title: Text(item['name']),
                              subtitle: Text("${item['quantity']} × ৳${item['price']} = ৳${item['total']}"),
                              dense: true,
                              visualDensity: const VisualDensity(vertical: -4),
                            )),
                          const SizedBox(height: 8),
                          Text(
                            "Date: ${sale['date']}",

                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}