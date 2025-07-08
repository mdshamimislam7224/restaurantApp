import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../localDB/DBHelper.dart';
import 'package:intl/intl.dart'; // ✅ This is needed for DateFormat


class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  List<String> categoryNames = [];
  String? selectedCategory;
  DateTime selectedDate = DateTime.now();
  TextEditingController _dateController = TextEditingController();
  String? _idDate;
  List<Map<String, dynamic>> menuItems = [];
  Map<String, dynamic>? selectedMenuItem;

  int quantity = 1;
  List<Map<String, dynamic>> selectedItems = [];

  final TextEditingController _discountController = TextEditingController(text: "0");
  String paymentMethod = "Cash";
  String paymentStatus = "Unpaid";

  @override
  void initState() {
    super.initState();
    loadCategories();
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

  double get subtotal => selectedItems.fold(0, (sum, item) => sum + (item['total'] as double));
  double get discount => double.tryParse(_discountController.text) ?? 0;
  double get grandTotal => subtotal - discount;

  void submitOrder() async {
    String Id = generateSaleIdFromDate(_idDate!);
    await DBHelper.saveSale(
      sale_ID: Id,
      date: _dateController.text,
      total: grandTotal,
      discount: discount,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      items: selectedItems,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Sale saved successfully!")),
    );

    print('Sale ID: $Id');
    setState(() {
      selectedItems.clear();
      _discountController.text = "0";
      paymentMethod = "Cash";
      paymentStatus = "Unpaid";
      _dateController.text = "";
    });
  }

  String generateSaleIdFromDate(String baseDate) {
    final now = DateTime.now();
    final timePart = "${now.hour}${now.minute}${now.second}";
    return "${baseDate}_$timePart"; // e.g. 25Jun2025_163105
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _dateController,
                style: const TextStyle(color: Colors.black),
                readOnly: true,
                decoration: InputDecoration(
                  hintText: "Please Choose the Date",
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),),
                  contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
                  suffixIcon: const Icon(Icons.calendar_month_outlined, color: Colors.black),
                ),
                onTap: () async {
                  DateTime? selectedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (selectedDate != null) {
                    setState(() {
                      _dateController.text = DateFormat('MM/dd/yyyy').format(selectedDate); // e.g. 06/25/2025
                      _idDate = DateFormat('ddMMMyyyy').format(selectedDate); // e.g. 25Jun2025
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
              // Dropdown: Category
              DropdownSearch<String>(
                items: categoryNames,
                selectedItem: selectedCategory,
                popupProps: const PopupProps.menu(showSearchBox: true),
                dropdownBuilder: (context, item) => Text(item ?? "Select Category"),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedCategory = value);
                    loadMenuItemsByCategory(value);
                  }
                },
              ),
              const SizedBox(height: 12),

              // Dropdown: Menu Item
              DropdownSearch<Map<String, dynamic>>(
                items: menuItems,
                selectedItem: selectedMenuItem,
                itemAsString: (item) => item['name'],
                popupProps: PopupProps.menu(
                  showSearchBox: true,
                  itemBuilder: (context, item, _) =>
                      ListTile(title: Text(item['name']), subtitle: Text("৳${item['price']}")),
                ),
                dropdownBuilder: (context, item) =>
                    Text(item?['name'] ?? "Select Menu Item"),
                onChanged: (value) {
                  setState(() => selectedMenuItem = value);
                },
              ),
              const SizedBox(height: 12),

              // Quantity
              Row(
                children: [
                  const Text("Qty:"),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      if (quantity > 1) setState(() => quantity--);
                    },
                  ),
                  Text(quantity.toString()),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setState(() => quantity++);
                    },
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: addItemToCart,
                    child: const Text("Add Item"),
                  ),
                ],
              ),

              const Divider(),

              // List of added items
              if (selectedItems.isNotEmpty)
                Column(
                  children: selectedItems.map((item) {
                    return ListTile(
                      title: Text("${item['name']} x${item['quantity']}"),
                      subtitle: Text("৳${item['price']} x ${item['quantity']} = ৳${item['total']}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() => selectedItems.remove(item));
                        },
                      ),
                    );
                  }).toList(),
                ),

              const Divider(),

              // Discount and Payment
              TextField(
                controller: _discountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Discount (৳)"),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: paymentMethod,
                items: ["Cash", "bKash", "Card", "Nagad"]
                    .map((method) => DropdownMenuItem(value: method, child: Text(method)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => paymentMethod = value);
                },
                decoration: const InputDecoration(labelText: "Payment Method"),
              ),

              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: paymentStatus,
                items: ["Unpaid", "Paid"]
                    .map((method) => DropdownMenuItem(value: method, child: Text(method)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => paymentStatus = value);
                },
                decoration: const InputDecoration(labelText: "Payment Status"),
              ),

              const SizedBox(height: 16),

              // Totals
              Text("Subtotal: ৳$subtotal"),
              Text("Discount: ৳$discount"),
              Text("Total Payable: ৳$grandTotal", style: const TextStyle(fontWeight: FontWeight.bold)),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: selectedItems.isNotEmpty ? submitOrder : null,
                child: const Text("Submit Order"),
              ),
            ],
          ),
        ),
      ),
    );
  }


}
