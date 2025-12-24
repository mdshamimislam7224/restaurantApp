import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'AddItemDialog.dart';
import 'InventoryAPI.dart';
import 'SummaryScreen.dart';
import 'model/InventoryItem.dart';

class InventoryScreen extends StatefulWidget {
  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<InventoryItem> _items = [];
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final items = await InventoryAPI.getAllItems();
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Restaurant Equipment'),
        actions: [
          IconButton(
            icon: Icon(Icons.analytics),
            tooltip: 'View Summary',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SummaryScreen(items: _items),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadItems,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(child: Text('No items found'))
          : ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          return _buildItemCard(_items[index]);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemDialog(),
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildItemCard(InventoryItem item) {
    Color statusColor = _getStatusColor(item.status);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: _buildItemImage(item), // Updated to show image
        title: Text(
          item.name,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Qty: ${item.quantity}'),
            Text('Location: ${item.location}'),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Last: ${item.lastChecked}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.add, color: Colors.green),
              onPressed: () => _updateQuantity(item, item.quantity + 1),
            ),
            IconButton(
              icon: Icon(Icons.remove, color: Colors.red),
              onPressed: () => _updateQuantity(item, item.quantity - 1),
            ),
          ],
        ),
        onTap: () {
          _showItemDetails(item);
        },
      ),
    );
  }

  Widget _buildItemImage(InventoryItem item) {
    if (item.imageUrl.isNotEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        radius: 25,
        backgroundImage: NetworkImage(item.imageUrl),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      );
    } else {
      Color statusColor = _getStatusColor(item.status);
      return CircleAvatar(
        backgroundColor: statusColor.withOpacity(0.2),
        radius: 25,
        child: Icon(
          _getCategoryIcon(item.category),
          color: statusColor,
          size: 24,
        ),
      );
    }
  }

  void _showItemDetails(InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.imageUrl.isNotEmpty)
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: DecorationImage(
                      image: NetworkImage(item.imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  height: 150,
                  width: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(75),
                  ),
                  child: Icon(
                    _getCategoryIcon(item.category),
                    size: 60,
                    color: Colors.grey.shade400,
                  ),
                ),
              SizedBox(height: 20),
              _buildDetailRow('Category', item.category),
              _buildDetailRow('Quantity', item.quantity.toString()),
              _buildDetailRow('Location', item.location),
              _buildDetailRow('Status', item.status),
              _buildDetailRow('Last Checked', item.lastChecked),
              if (item.notes.isNotEmpty)
                _buildDetailRow('Notes', item.notes),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) => AddItemDialog(
        isDarkMode: false, // Pass your theme value
        refreshCallback: _loadItems, // Your refresh function
        currentLanguage: 'en', // Pass language if needed
      ),
    );
  }
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'good':
        return Colors.green;
      case 'needs repair':
        return Colors.orange;
      case 'broken':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'furniture':
        return Icons.chair;
      case 'kitchen':
        return Icons.kitchen;
      case 'tech':
        return Icons.computer;
      case 'lighting':
        return Icons.lightbulb;
      default:
        return Icons.inventory;
    }
  }

  Future<void> _updateQuantity(InventoryItem item, int newQty) async {
    if (newQty < 0) return;

    final result = await InventoryAPI.updateQuantity(
      itemId: item.id,
      newQuantity: newQty,
    );

    if (result['success'] == true) {
      _loadItems();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated ${item.name} quantity to $newQty')),
      );
    }
  }
}
