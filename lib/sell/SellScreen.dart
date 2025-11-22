import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../alertDialog/customDialog.dart';
import '../localDB/DBHelper.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

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

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final String scriptUrl = "https://script.google.com/macros/s/AKfycbwF-ApiZXB8j9N_mnTPKHITcXqseEbptEoF4Kob_ejquN2Uesu1_O7HkL4xUMVI5T5NZQ/exec"; // Replace this

  @override
  void initState() {
    super.initState();
    loadCategories();
    // Initialize with current date
    final now = DateTime.now();
    _dateController.text = DateFormat('MM/dd/yyyy').format(now);
    _idDate = DateFormat('ddMMMyyyy').format(now);
    selectedDate = now; // Update selectedDate if you're using it elsewhere
  }

  Future<void> fetchAndSaveMenuItems() async {
    final dialog = customDialog(context);
  dialog.showLoading("Loading Food Items...", subtitle: "Please wait");
    final res = await http.get(Uri.parse('$scriptUrl?action=getMenuAllItems'));
    print('Status Code: ${res.statusCode}');
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final List items = json['data']['items']; // ✅ Get the nested list
      print('Items: $items');
      await DBHelper.clearMenuItems();
      await DBHelper.insertMenuItems(List<Map<String, dynamic>>.from(items));
      loadCategories();
      dialog.dismiss();
      print('✅ Items inserted into SQLite');
    } else {
      dialog.dismiss();
      debugPrint('❌ Failed to fetch: ${res.statusCode}');
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

  void addItemToCart() {
    if (_formKey.currentState!.validate()) {
      if (selectedMenuItem != null && quantity > 0) {
        // Check if item already exists in cart
        bool itemExists = selectedItems.any((item) => item['id'] == selectedMenuItem!['id']);

        if (itemExists) {
          // Show message that item already exists
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${selectedMenuItem!['name']} is already in your order"),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          // Add new item to cart
          setState(() {
            selectedItems.add({
              'id': selectedMenuItem!['id'],
              'name': selectedMenuItem!['name'],
              'price': selectedMenuItem!['price'],
              'quantity': quantity,
              'total': selectedMenuItem!['price'] * quantity,
              'key': DateTime.now().millisecondsSinceEpoch.toString(), // Unique key for Dismissible
            });
            quantity = 1;

          });
        }
      }
    }
  }

  double get subtotal => selectedItems.fold(0, (sum, item) => sum + (item['total'] as double));
  double get discount => double.tryParse(_discountController.text) ?? 0;
  double get grandTotal => subtotal - discount;

  void submitOrder() async {
    if (_formKey.currentState!.validate()) {
      if (selectedItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please add at least one item")),
        );
        return;
      }

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

      setState(() {
        selectedItems.clear();
        _discountController.text = "0";
        paymentMethod = "Cash";
        paymentStatus = "Unpaid";
        selectedCategory = null;
        selectedMenuItem = null;
        selectedMenuItem = null;
        menuItems.clear();
      });
    }
  }

  String generateSaleIdFromDate(String baseDate) {
    final now = DateTime.now();
    final timePart = "${now.hour}${now.minute}${now.second}";
    return "${baseDate}_$timePart";
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16 : 32,
            vertical: 16,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Date Picker Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Add Sale Information",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "Sale Date",
                          prefixIcon: Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a date';
                          }
                          return null;
                        },
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate, // Use the already selected date or current date
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              selectedDate = pickedDate;
                              _dateController.text = DateFormat('MM/dd/yyyy').format(pickedDate);
                              _idDate = DateFormat('ddMMMyyyy').format(pickedDate);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Item Selection Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Add Items",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Category Dropdown
                      DropdownSearch<String>(
                        items: categoryNames,
                        selectedItem: selectedCategory,
                        popupProps: PopupProps.menu(
                          showSearchBox: true,
                          menuProps: const MenuProps(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          searchFieldProps: TextFieldProps(
                            decoration: InputDecoration(
                              hintText: "Search category...",
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        dropdownDecoratorProps: DropDownDecoratorProps(
                          dropdownSearchDecoration: InputDecoration(
                            labelText: "Category",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.category),
                          ),
                        ),
                        validator: (value) => value == null ? 'Please select a category' : null,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedCategory = value);
                            loadMenuItemsByCategory(value);
                          }
                        },
                      ),

                      const SizedBox(height: 12),

                      // Menu Item Dropdown
                      DropdownSearch<Map<String, dynamic>>(
                        items: menuItems,
                        selectedItem: selectedMenuItem,
                        itemAsString: (item) => item['name'],
                        popupProps: PopupProps.menu(
                          showSearchBox: true,
                          menuProps: const MenuProps(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          searchFieldProps: TextFieldProps(
                            decoration: InputDecoration(
                              hintText: "Search menu item...",
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          itemBuilder: (context, item, isSelected) => ListTile(
                            title: Text(item['name']),
                            subtitle: Text("৳${item['price']}"),
                          ),
                        ),
                        dropdownDecoratorProps: DropDownDecoratorProps(
                          dropdownSearchDecoration: InputDecoration(
                            labelText: "Menu Item",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.restaurant_menu),
                          ),
                        ),
                        validator: (value) => value == null ? 'Please select a menu item' : null,
                        onChanged: (value) {
                          setState(() => selectedMenuItem = value);
                        },
                      ),

                      const SizedBox(height: 12),

                      // Quantity Selector
                      Row(
                        children: [
                          const Text("Quantity:", style: TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.remove, color: theme.colorScheme.primary),
                            onPressed: () {
                              if (quantity > 1) setState(() => quantity--);
                            },
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              quantity.toString(),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add, color: theme.colorScheme.primary),
                            onPressed: () {
                              setState(() => quantity++);
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Add Item Button
                      FilledButton(
                        onPressed: addItemToCart,
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text("Add to Order"),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Selected Items List
                if (selectedItems.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Order Items",
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                "${selectedItems.length} items",
                                style: TextStyle(color: theme.colorScheme.primary),
                              ),
                            ),
                          ],

                        ),
                        const SizedBox(height: 12),
                        ...selectedItems.map((item) {
                          return Dismissible(
                            key: Key(item['key']), // Fixed: Using unique key
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.delete,
                                color: theme.colorScheme.error,
                              ),
                            ),
                            onDismissed: (direction) {
                              setState(() => selectedItems.remove(item));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("${item['name']} removed"),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      "x${item['quantity']}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['name'], style: theme.textTheme.bodyMedium),
                                        Text("৳${item['price']} each",
                                            style: theme.textTheme.bodySmall),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    "৳${item['total']}",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Payment Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Payment Details",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Discount Input
                      TextFormField(
                        controller: _discountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Discount (৳)",
                          prefixIcon: const Icon(Icons.discount),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter discount amount (0 if none)';
                          }
                          final discountValue = double.tryParse(value);
                          if (discountValue == null) {
                            return 'Please enter a valid number';
                          }
                          if (discountValue < 0) {
                            return 'Discount cannot be negative';
                          }
                          if (discountValue > subtotal) {
                            return 'Discount cannot be greater than subtotal';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),

                      const SizedBox(height: 16),

                      // Payment Method
                      DropdownButtonFormField<String>(
                        value: paymentMethod,
                        items: ["Cash", "bKash", "Card", "Nagad", "Rocket", "Bank Transfer","Other"]
                            .map((method) => DropdownMenuItem(
                          value: method,
                          child: Text(method),
                        ))
                            .toList(),
                        decoration: InputDecoration(
                          labelText: "Payment Method",
                          prefixIcon: const Icon(Icons.payment),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (value) => value == null ? 'Please select payment method' : null,
                        onChanged: (value) {
                          if (value != null) setState(() => paymentMethod = value);
                        },
                      ),

                      const SizedBox(height: 16),

                      // Payment Status
                      DropdownButtonFormField<String>(
                        value: paymentStatus,
                        items: ["Unpaid", "Paid"]
                            .map((method) => DropdownMenuItem(
                          value: method,
                          child: Text(method),
                        ))
                            .toList(),
                        decoration: InputDecoration(
                          labelText: "Payment Status",
                          prefixIcon: const Icon(Icons.credit_score),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (value) => value == null ? 'Please select payment status' : null,
                        onChanged: (value) {
                          if (value != null) setState(() => paymentStatus = value);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Summary Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Order Summary",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Subtotal:", style: theme.textTheme.bodyMedium),
                          Text("৳$subtotal", style: theme.textTheme.bodyMedium),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Discount:", style: theme.textTheme.bodyMedium),
                          Text("-৳$discount", style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          )),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Total Payable:", style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          )),
                          Text(
                            "৳$grandTotal",
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Submit Button
                FilledButton(
                  onPressed: () {
                    if (selectedItems.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please add at least one item")),
                      );
                    } else {
                      submitOrder();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    "Submit Order",
                    style: TextStyle(fontSize: 16),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() {
          fetchAndSaveMenuItems();
        }),
        label: Text("Reload Food List",
          style: TextStyle(color: Colors.white,),),
        icon: Icon(Icons.refresh, color: Colors.white,),
        backgroundColor: Colors.deepPurple,
      ),
    );

  }


}