import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'localDB/DBHelper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String scriptUrl = "https://script.google.com/macros/s/AKfycbwF-ApiZXB8j9N_mnTPKHITcXqseEbptEoF4Kob_ejquN2Uesu1_O7HkL4xUMVI5T5NZQ/exec"; // Replace this
  List<Map<String, dynamic>> menuItems = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    syncAndLoadMenuItems();
  }

  Future<void> syncAndLoadMenuItems() async {
    setState(() => isLoading = true);
    try {
      await fetchAndSaveMenuItems();
    } catch (_) {}
    await loadMenuItemsFromLocal();
    setState(() => isLoading = false);
  }
  Future<void> fetchAndSaveMenuItems() async {
    final res = await http.get(Uri.parse('$scriptUrl?action=getMenuAllItems'));
    print('Status Code: ${res.statusCode}');
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      final List items = json['data']['items']; // ✅ Get the nested list
      print('Items: $items');
      await DBHelper.clearMenuItems();
      await DBHelper.insertMenuItems(List<Map<String, dynamic>>.from(items));
      print('✅ Items inserted into SQLite');
    } else {
      debugPrint('❌ Failed to fetch: ${res.statusCode}');
    }
  }
  Future<void> loadMenuItemsFromLocal() async {
    final localData = await DBHelper.getMenuItems();
    setState(() {
      menuItems = localData;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: syncAndLoadMenuItems,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : menuItems.isEmpty
          ? const Center(child: Text("No menu items available"))
          : ListView.builder(
        itemCount: menuItems.length,
        itemBuilder: (context, index) {
          final item = menuItems[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(item['name']),
              subtitle: Text("Category: ${item['categoryName']}"),
              trailing: Text("৳${item['price'].toString()}"),
            ),
          );
        },
      ),
    );
  }
}
