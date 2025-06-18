import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'Category.dart';
import 'MenuItem.dart';

class MenuItemManagerScreen extends StatefulWidget {
  const MenuItemManagerScreen({super.key});

  @override
  State<MenuItemManagerScreen> createState() => _MenuItemManagerScreenState();
}

class _MenuItemManagerScreenState extends State<MenuItemManagerScreen> {
  final String scriptUrl = "https://script.google.com/macros/s/AKfycbw65-MArw-eo0foir6XLKUqVXt466wvMlBGCkIUvFlhCq3SdRdqX_J5sTUG-5Lbxqy5Lg/exec";
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<Category> categories = [];
  List<MenuItem> menuItems = [];
  Category? selectedCategory;
  MenuItem? editingItem;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await Future.wait([fetchCategories(), fetchMenuItems()]);
    setState(() => _loading = false);
  }

  Future<void> fetchCategories() async {
    try {
      final response = await http.get(Uri.parse("$scriptUrl?action=getCategories"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          categories = (data as List).map((e) => Category.fromJson(e)).toList();
        });
      }
    } catch (e) {
      print('Error fetching categories: $e');
    }
  }

  Future<void> fetchMenuItems() async {
    try {
      final response = await http.get(Uri.parse("$scriptUrl?action=getMenuItems"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          menuItems = (data as List).map((e) => MenuItem.fromJson(e)).toList();
        });
      }
    } catch (e) {
      print('Error fetching menu items: $e');
    }
  }

  Future<void> saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final name = _nameController.text;
      final price = double.tryParse(_priceController.text) ?? 0;
      final categoryId = selectedCategory!.id;

      final action = editingItem == null ? 'addMenuItem' : 'updateMenuItem';
      final url = "$scriptUrl?action=$action&id=${editingItem?.id ?? ''}&name=$name&price=$price&categoryId=$categoryId";

      final response = await http.post(Uri.parse(url));
      if (response.statusCode == 200 ||response.statusCode == 302) {
        _nameController.clear();
        _priceController.clear();
        setState(() {
          selectedCategory = null;
          editingItem = null;
        });
        await _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item ${editingItem == null ? 'added' : 'updated'} successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving item: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> deleteItem(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this menu item?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final response = await http.post(Uri.parse("$scriptUrl?action=deleteMenuItem&id=$id"));
      if (response.statusCode == 200 || response.statusCode == 302) {
        await _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting item: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
          );
        },
      ),

    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _buildItemList(),
          ),
        ),
        Flexible(
          flex: 1,
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildForm(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        Expanded(child: _buildItemList()),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildForm(),
          ),
        ),
      ],
    );
  }

  Widget _buildItemList() {
    if (menuItems.isEmpty && !_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No Menu Items Yet",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            const Text("Add your first menu item to get started"),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 8),
        itemCount: menuItems.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = menuItems[index];
          return Dismissible(
            key: ValueKey(item.id),
            background: Container(
              color: Theme.of(context).colorScheme.errorContainer,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              return await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Confirm Delete"),
                  content: const Text("Are you sure you want to delete this item?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text("Delete"),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (_) => deleteItem(item.id),
            child: InkWell(
              onTap: () {
                setState(() {
                  editingItem = item;
                  _nameController.text = item.name;
                  _priceController.text = item.price.toString();
                  selectedCategory = categories.firstWhere(
                        (c) => c.id == item.categoryId,
                    orElse: () => Category(id: -1, name: 'Unknown'),
                  );
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: editingItem?.id == item.id
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "৳${item.price.toStringAsFixed(0)} • ${item.categoryName}",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () {
                        setState(() {
                          editingItem = item;
                          _nameController.text = item.name;
                          _priceController.text = item.price.toString();
                          selectedCategory = categories.firstWhere(
                                (c) => c.id == item.categoryId,
                            orElse: () => Category(id: -1, name: 'Unknown'),
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            editingItem != null ? "Edit Menu Item" : "New Menu Item",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: "Item Name",
              border: const OutlineInputBorder(),
              filled: true,
              prefixIcon: const Icon(Icons.restaurant_menu),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an item name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _priceController,
            decoration: InputDecoration(
              labelText: "Price",
              border: const OutlineInputBorder(),
              filled: true,
              prefixIcon: const Icon(Icons.attach_money),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a price';
              }
              if (double.tryParse(value) == null) {
                return 'Please enter a valid number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Category>(
            value: selectedCategory,
            decoration: InputDecoration(
              labelText: "Category",
              border: const OutlineInputBorder(),
              filled: true,
              prefixIcon: const Icon(Icons.category),
            ),
            items: categories.map((cat) {
              return DropdownMenuItem(
                value: cat,
                child: Text(cat.name),
              );
            }).toList(),
            onChanged: (cat) => setState(() => selectedCategory = cat),
            validator: (value) {
              if (value == null) {
                return 'Please select a category';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: saveItem,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(editingItem != null ? "UPDATE ITEM" : "ADD ITEM"),
            ),
          ),
          if (editingItem != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  editingItem = null;
                  _nameController.clear();
                  _priceController.clear();
                  selectedCategory = null;
                });
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text("CANCEL"),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}