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
  List<String> categoryNames = [];
  String? selectedCategory;
  List<Map<String, dynamic>> menuItems = [];
  Map<String, dynamic>? selectedMenuItem;
  List<Map<String, dynamic>> selectedItems = [];
  int quantity = 1;
  final TextEditingController _discountController = TextEditingController(text: "0");


  @override
  void initState() {
    super.initState();
    loadSales();
    loadCategories();
  }


  double get subtotal => selectedItems.fold(0, (sum, item) => sum + (item['total'] as double));
  double get discount => double.tryParse(_discountController.text) ?? 0;
  double get grandTotal => subtotal - discount;

  Future<void> loadSales() async {
    final db = await DBHelper.db;
    final result = await db.query('sales', orderBy: 'date DESC');
    setState(() {
      sales = result;
      print("Sales: $sales");
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
    double total = sale['total'] ?? 0.0;
    int quantity = 1;
    await loadSaleItems(sale['id']);
    List<Map<String, dynamic>> existingItems = List.from(saleItems); // Editable

    List<Map<String, dynamic>> newItems = []; // For adding new


    String? selectedCategoryInDialog;
    Map<String, dynamic>? selectedMenuItemInDialog;
    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            void recalculateTotal() {
              total = 0.0;
              for (var item in existingItems) {
                total += item['quantity'] * item['price'];
              }
              for (var item in newItems) {
                total += item['quantity'] * item['price'];
              }
              total -= double.tryParse(discountController.text) ?? 0.0;
              if (total < 0) total = 0.0;
            }
            recalculateTotal();
            return AlertDialog(
              title: const Text("Update Sale Entry"),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    // Dropdown for Category
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

                    // Dropdown for Menu Item
                    DropdownSearch<Map<String, dynamic>>(
                      items: menuItems,
                      selectedItem: selectedMenuItemInDialog,
                      itemAsString: (item) => item['name'],
                      popupProps: PopupProps.menu(showSearchBox: true),
                      dropdownBuilder: (_, item) => Text(item?['name'] ?? "Select Menu Item"),
                      onChanged: (val) {
                        setStateDialog(() => selectedMenuItemInDialog = val);
                      },
                    ),

                    Row(
                      children: [
                        const Text("Qty: "),
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
                          onPressed: () {
                            if (selectedMenuItemInDialog != null) {
                              newItems.add({
                                'id': selectedMenuItemInDialog!['id'],
                                'name': selectedMenuItemInDialog!['name'],
                                'price': selectedMenuItemInDialog!['price'],
                                'quantity': quantity,
                                'total': selectedMenuItemInDialog!['price'] * quantity,
                              });
                              quantity = 1;
                              selectedMenuItemInDialog = null;
                              setStateDialog(recalculateTotal);
                            }
                          },
                          child: const Text("Add"),
                        ),
                      ],
                    ),

                    const Divider(),

                    const Text("Existing Items (Edit Qty):"),
                    ...existingItems.map((item) {
                      final qtyCtrl = TextEditingController(text: item['quantity'].toString());
                      return ListTile(
                        title: Text(item['name']),
                        subtitle: Text("৳${item['price']}"),
                        trailing: SizedBox(
                          width: 60,
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              item['quantity'] = int.tryParse(val) ?? 1;
                              item['total'] = item['quantity'] * item['price'];
                              setStateDialog(recalculateTotal);
                            },
                          ),
                        ),
                      );
                    }),

                    const Divider(),

                    const Text("New Added Items:"),
                    ...newItems.map((item) => ListTile(
                      title: Text("${item['name']} x${item['quantity']}"),
                      subtitle: Text("৳${item['price']} x ${item['quantity']} = ৳${item['total']}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setStateDialog(() {
                            newItems.remove(item);
                            recalculateTotal();
                          });
                        },
                      ),
                    )),

                    TextField(
                      controller: discountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Discount"),
                      onChanged: (_) => setStateDialog(recalculateTotal),
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
                    Text("Total Payable: ৳${total.toStringAsFixed(2)}",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    final finalItems = [
                      ...existingItems.map((e) => {
                        'id': e['menuItemId'] ?? e['id'],
                        'name': e['name'],
                        'price': e['price'],
                        'quantity': e['quantity'],
                        'total': e['quantity'] * e['price']
                      }),
                      ...newItems
                    ];

                    await DBHelper.updateFullSale(
                      id: sale['id'],
                      paymentMethod: selectedMethod,
                      paymentStatus: selectedStatus,
                      discount: double.tryParse(discountController.text) ?? 0.0,
                      total: total,
                      items: finalItems,
                    );
                    Navigator.pop(context);
                    loadSales();
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


  void addItemToCart() {
    if (selectedMenuItem != null && quantity > 0) {
      setState(() {
        selectedItems.add({
          'id': selectedMenuItem!['id'],
          'name': selectedMenuItem!['name'],
          'price': selectedMenuItem!['price'],
          'quantity': quantity,
          'total': selectedMenuItem!['price'] * quantity
        });
        quantity = 1;
        selectedMenuItem = null;
      });
    }
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
