import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'InventoryAPI.dart';
class AddItemDialog extends StatefulWidget {
  final bool isDarkMode;
  final Function refreshCallback;
  final String currentLanguage;

  const AddItemDialog({
    Key? key,
    required this.isDarkMode,
    required this.refreshCallback,
    required this.currentLanguage,
  }) : super(key: key);

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final ImagePicker _picker = ImagePicker();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _notesController = TextEditingController();

  // Dropdown values
  String _selectedCategory = 'Furniture';
  String _selectedLocation = 'Storage';
  String _selectedStatus = 'Good';

  // Image handling
  File? _selectedImageFile;
  bool _isUploading = false;

  // Available options
  final List<String> _categories = ['Furniture', 'Kitchen', 'Tech', 'Lighting', 'Other'];
  final List<String> _locations = ['Kitchen', 'Storage', 'Dining', 'Office', 'Counter'];
  final List<String> _statuses = ['Good', 'Needs Repair', 'Broken'];

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50, // reduce more
        maxWidth: 800,
      );
      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
        });
      }
    } catch (e) {
      print("Error picking image from camera: $e");
      _showErrorSnackBar("Failed to capture image");
    }
  }

  void _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50, // reduce more
        maxWidth: 800,
      );
      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
        });
      }
    } catch (e) {
      print("Error picking image from gallery: $e");
      _showErrorSnackBar("Failed to select image");
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImageFile = null;
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _submitForm() async {
    final name = _nameController.text.trim();
    final quantity = int.tryParse(_quantityController.text) ?? 1;

    // Validation
    if (name.isEmpty) {
      _showErrorSnackBar('Please enter item name');
      return;
    }

    if (quantity <= 0) {
      _showErrorSnackBar('Quantity must be greater than 0');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Convert image to base64 if exists
      List<Map<String, String>> images = [];

      if (_selectedImageFile != null) {
        final bytes = await _selectedImageFile!.readAsBytes();
        final base64String = base64Encode(bytes);

        // Determine MIME type
        String mimeType = 'image/jpeg';
        final filePath = _selectedImageFile!.path.toLowerCase();
        if (filePath.endsWith('.png')) {
          mimeType = 'image/png';
        } else if (filePath.endsWith('.gif')) {
          mimeType = 'image/gif';
        }

        images.add({
          'data': base64String,
          'mimeType': mimeType,
        });
      }

      // Call API
      final result = await InventoryAPI.addItemWithImage(
        name: name,
        category: _selectedCategory,
        quantity: quantity,
        images: images,
        location: _selectedLocation,
        status: _selectedStatus,
        notes: _notesController.text,
      );

      if (result['success'] == true) {
        // Refresh parent widget
        await widget.refreshCallback();

        // Show success message
        _showSuccessSnackBar('Item added successfully!');

        // Close dialog
        Navigator.of(context).pop();
      } else {
        _showErrorSnackBar('Error: ${result['error'] ?? 'Failed to add item'}');
        setState(() {
          _isUploading = false;
        });
      }
    } catch (e) {
      print('Error submitting form: $e');
      _showErrorSnackBar('Error: $e');
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              'Add New Item',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.close),
              onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: _isUploading
                    ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Icon(Icons.check),
                onPressed: _isUploading ? null : _submitForm,
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Section
                  _buildImageSection(),
                  SizedBox(height: 20),

                  // Item Name
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Item Name *',
                      hintText: 'Kneef, Payala, Monitor, etc.',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                  SizedBox(height: 12),

                  // Category
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    items: _categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value!;
                      });
                    },
                  ),
                  SizedBox(height: 12),

                  // Quantity
                  TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity *',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                  SizedBox(height: 12),

                  // Location
                  DropdownButtonFormField<String>(
                    value: _selectedLocation,
                    decoration: InputDecoration(
                      labelText: 'Location',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    items: _locations.map((loc) {
                      return DropdownMenuItem(
                        value: loc,
                        child: Text(loc),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLocation = value!;
                      });
                    },
                  ),
                  SizedBox(height: 12),

                  // Status
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    items: _statuses.map((stat) {
                      return DropdownMenuItem(
                        value: stat,
                        child: Text(stat),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value!;
                      });
                    },
                  ),
                  SizedBox(height: 12),

                  // Notes
                  TextField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Any details...',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    maxLines: 3,
                  ),

                  SizedBox(height: 20),

                  // Buttons
                  if (!_isUploading)
                    _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Item Image',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 8),

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
                'No image selected',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),

        // Camera/Gallery Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.camera_alt, size: 16),
              label: Text('Camera'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: _pickImageFromCamera,
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.photo_library, size: 16),
              label: Text('Gallery'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: _pickImageFromGallery,
            ),
          ],
        ),

        // Remove Image Button
        if (_selectedImageFile != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              icon: Icon(Icons.delete, size: 16, color: Colors.red),
              label: Text('Remove Image', style: TextStyle(color: Colors.red)),
              onPressed: _removeImage,
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            minimumSize: Size(120, 45),
          ),
          icon: Icon(Icons.cancel, color: Colors.black87),
          label: Text(
            'Cancel',
            style: TextStyle(color: Colors.black87),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            minimumSize: Size(120, 45),
          ),
          icon: Icon(Icons.add, color: Colors.white),
          label: Text(
            'Add Item',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}