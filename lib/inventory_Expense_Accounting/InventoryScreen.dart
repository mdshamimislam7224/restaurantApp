import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
        onPressed: () => _showAddDialog(),
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

  void _showAddDialog() {
    final categories = ['Furniture', 'Kitchen', 'Tech', 'Lighting', 'Other'];
    final locations = ['Kitchen', 'Storage', 'Dining', 'Office', 'Counter'];
    final statuses = ['Good', 'Needs Repair', 'Broken'];

    TextEditingController nameController = TextEditingController();
    String selectedCategory = categories[0];
    TextEditingController qtyController = TextEditingController(text: '1');
    String selectedLocation = locations[0];
    String selectedStatus = statuses[0];
    TextEditingController notesController = TextEditingController();
    File? _selectedImageFile;
    bool _isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Add New Item'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image Preview
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _selectedImageFile != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _selectedImageFile!,
                        fit: BoxFit.cover,
                      ),
                    )
                        : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          size: 50,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Select an image',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),

                  // Camera/Gallery Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(Icons.camera_alt, size: 16),
                        label: Text('Camera'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onPressed: () async {
                          final XFile? image = await _picker.pickImage(
                            source: ImageSource.camera,
                            imageQuality: 70,
                          );
                          if (image != null) {
                            setState(() {
                              _selectedImageFile = File(image.path);
                            });
                          }
                        },
                      ),
                      ElevatedButton.icon(
                        icon: Icon(Icons.photo_library, size: 16),
                        label: Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onPressed: () async {
                          final XFile? image = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 70,
                          );
                          if (image != null) {
                            setState(() {
                              _selectedImageFile = File(image.path);
                            });
                          }
                        },
                      ),
                    ],
                  ),

                  // Remove Image Button
                  if (_selectedImageFile != null)
                    TextButton.icon(
                      icon: Icon(Icons.delete, size: 16, color: Colors.red),
                      label: Text('Remove Image', style: TextStyle(color: Colors.red)),
                      onPressed: () {
                        setState(() {
                          _selectedImageFile = null;
                        });
                      },
                    ),

                  SizedBox(height: 16),

                  // Item Name
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Item Name',
                      hintText: 'Kneef, Payala, Monitor, etc.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 12),

                  // Category
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCategory = value!;
                      });
                    },
                  ),
                  SizedBox(height: 12),

                  // Quantity
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 12),

                  // Location
                  DropdownButtonFormField<String>(
                    value: selectedLocation,
                    decoration: InputDecoration(
                      labelText: 'Location',
                      border: OutlineInputBorder(),
                    ),
                    items: locations.map((loc) {
                      return DropdownMenuItem(
                        value: loc,
                        child: Text(loc),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedLocation = value!;
                      });
                    },
                  ),
                  SizedBox(height: 12),

                  // Status
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: statuses.map((stat) {
                      return DropdownMenuItem(
                        value: stat,
                        child: Text(stat),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedStatus = value!;
                      });
                    },
                  ),
                  SizedBox(height: 12),

                  // Notes
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Any details...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),

                  // Uploading Indicator
                  if (_isUploading)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('Uploading image and saving item...'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isUploading ? null : () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isUploading ? null : () async {
                  final name = nameController.text.trim();
                  final qty = int.tryParse(qtyController.text) ?? 1;

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter item name')),
                    );
                    return;
                  }

                  setState(() {
                    _isUploading = true;
                  });

                  try {
                    // Convert image to base64 if selected
                    String imageBase64 = '';
                    if (_selectedImageFile != null) {
                      // Read file as bytes and convert to base64
                      final bytes = await _selectedImageFile!.readAsBytes();
                      imageBase64 = base64Encode(bytes);
                      // Add MIME type prefix (IMPORTANT!)
                      imageBase64 = 'data:image/jpeg;base64,$imageBase64';
                    }

                    final result = await InventoryAPI.addItemWithImage(
                      name: name,
                      category: selectedCategory,
                      quantity: qty,
                      imageBase64: imageBase64,
                      location: selectedLocation,
                      status: selectedStatus,
                      notes: notesController.text,
                    );

                    print('API Response: $result');

                    if (result['success'] == true) {
                      Navigator.pop(context);
                      _loadItems();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Item added successfully')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${result['error']}')),
                      );
                      setState(() {
                        _isUploading = false;
                      });
                    }
                  } catch (e) {
                    print('Error: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                    setState(() {
                      _isUploading = false;
                    });
                  }
                },
                child: _isUploading
                    ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }
// Helper method to build placeholder icon
  Widget _buildPlaceholderIcon() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.camera_alt,
          size: 50,
          color: Colors.grey.shade400,
        ),
        SizedBox(height: 8),
        Text(
          'Select an image',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
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
