import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'Staff.dart';
class StaffProfileScreen extends StatefulWidget {
  final String staffId;

  const StaffProfileScreen({
    Key? key,
    required this.staffId,
  }) : super(key: key);

  @override
  _StaffProfileViewState createState() => _StaffProfileViewState();
}

class _StaffProfileViewState extends State<StaffProfileScreen> {
  StaffProfile? _staff;
  List<Staff> staffList = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadStaffData();
  }

  Future<void> _loadStaffData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final response = await http.get(
        Uri.parse('https://script.google.com/macros/s/AKfycbzZC0sGCKNEm327PC4pYRmjGIOo5f94c6lAOb7Nj3-BEhkDh3N07aPM7SeiYPDo0Uw/exec?action=getEmployeeById&staffId=${widget.staffId}'),
      );

      print('Response status: ${response.statusCode}'); // Debug
      print('Response body: ${response.body}'); // Debug

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Parsed data: $data'); // Debug

        if (data['status'] == 'success') {
          final staffData = data['data'];
          print('Staff data: $staffData'); // Debug

          setState(() {
            _staff = StaffProfile.fromJson(staffData);
            _isLoading = false;
          });

          print('Staff object created: ${_staff?.toJson()}'); // Debug
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Failed to load staff data';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load data: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading staff data: $e'); // Debug
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Staff Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadStaffData,
          ),
          if (_staff != null)
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () => _showEditDialog(),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              _errorMessage,
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStaffData,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_staff == null) {
      return Center(
        child: Text('No staff data available'),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(),
          SizedBox(height: 24),
          _buildInfoSection(),
          SizedBox(height: 24),
          _buildDocumentsSection(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: _staff!.profileImage.isNotEmpty
                ? NetworkImage(_getDirectImageUrl(_staff!.profileImage))
                : AssetImage('assets/default_profile.png') as ImageProvider,
          ),
          SizedBox(height: 16),
          Text(
            _staff!.name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            _staff!.position,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Divider(),
            _buildInfoRow('Staff ID', _staff!.id),
            _buildInfoRow('Phone', _staff!.phone),
            _buildInfoRow('Email', _staff!.email.isNotEmpty ? _staff!.email : 'Not provided'),
            _buildInfoRow('NID', _staff!.nid.isNotEmpty ? _staff!.nid : 'Not provided'),
            _buildInfoRow(
              'Joining Date',
              _staff!.joiningDate != null
                  ? DateFormat('dd/MM/yyyy').format(_staff!.joiningDate!)
                  : 'Not provided',
            ),
            _buildInfoRow('Salary', _formatSalary(_staff!.salary)),
            SizedBox(height: 16),
            Text(
              'Address Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Divider(),
            _buildInfoRow('Present Address', _staff!.presentAddress),
            _buildInfoRow('Permanent Address', _staff!.permanentAddress),
            SizedBox(height: 16),
            Text(
              'Additional Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Divider(),
            _buildInfoRow('Guardian Info', _staff!.guardianInfo.isNotEmpty ? _staff!.guardianInfo : 'Not provided'),
            _buildInfoRow('Additional Info', _staff!.info.isNotEmpty ? _staff!.info : 'Not provided'),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsSection() {
    if (_staff!.documents.isEmpty) return SizedBox();

    final docUrls = _staff!.documents.split(',').map((url) => url.trim()).toList();

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Documents',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Divider(),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: docUrls.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _showFullScreenImage(docUrls[index]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _getDirectImageUrl(docUrls[index]),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.error_outline, color: Colors.grey),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: value == 'Not provided' ? Colors.grey : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 3.0,
              child: Image.network(
                _getDirectImageUrl(imageUrl),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // EDIT DIALOG METHODS
  void _showEditDialog() {
    if (_staff == null) return;

    final _formKey = GlobalKey<FormState>();
    final TextEditingController _nameController = TextEditingController(text: _staff!.name);
    final TextEditingController _positionController = TextEditingController(text: _staff!.position);
    final TextEditingController _phoneController = TextEditingController(text: _staff!.phone);
    final TextEditingController _salaryController = TextEditingController(text: _staff!.salary);
    final TextEditingController _nidController = TextEditingController(text: _staff!.nid);
    final TextEditingController _presentAddressController = TextEditingController(text: _staff!.presentAddress);
    final TextEditingController _permanentAddressController = TextEditingController(text: _staff!.permanentAddress);
    final TextEditingController _infoController = TextEditingController(text: _staff!.info);
    final TextEditingController _guardianInfoController = TextEditingController(text: _staff!.guardianInfo);
    final TextEditingController _emailController = TextEditingController(text: _staff!.email);
    DateTime? _selectedDate = _staff!.joiningDate;
    List<XFile> _profileImages = [];
    List<XFile> _documentImages = [];
    bool _sameAddress = _staff!.presentAddress == _staff!.permanentAddress;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text('Update Staff Details'),
            leading: IconButton(
              icon: Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => Center(child: CircularProgressIndicator()),
                    );

                    try {
                      final List<Map<String, String>> newProfileImages = [];
                      final List<Map<String, String>> newDocumentImages = [];

                      // Convert new profile images to base64
                      for (XFile image in _profileImages) {
                        newProfileImages.add({
                          'data': await _convertToBase64(image),
                          'mimeType': 'image/jpeg',
                        });
                      }

                      // Convert new document images to base64
                      for (XFile image in _documentImages) {
                        newDocumentImages.add({
                          'data': await _convertToBase64(image),
                          'mimeType': 'image/jpeg',
                        });
                      }

                      // Prepare update data
                      final updateData = {
                        'originalStaffId': _staff!.id,
                        'staff_id': _staff!.id,
                        'name': _nameController.text,
                        'position': _positionController.text,
                        'phone': _phoneController.text,
                        'salary': _salaryController.text,
                        'nid': _nidController.text,
                        'present_address': _presentAddressController.text,
                        'permanent_address': _sameAddress ? _presentAddressController.text : _permanentAddressController.text,
                        'info': _infoController.text,
                        'guardian_info': _guardianInfoController.text,
                        'email': _emailController.text,
                        'join_date': _selectedDate != null ? DateFormat('yyyy-MM-dd').format(_selectedDate!) : _staff!.joiningDate?.toIso8601String(),
                        'profileImage': newProfileImages,
                        'imagesData': newDocumentImages,
                      };

                      await _updateStaff(updateData);
                      Navigator.pop(context); // close loading
                      Navigator.pop(context); // close dialog
                      _loadStaffData(); // Refresh data
                    } catch (e) {
                      Navigator.pop(context); // close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Update failed: ${e.toString()}')),
                      );
                    }
                  }
                },
                child: Text('Update', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          body: StatefulBuilder(
            builder: (context, setStateDialog) {
              Future<void> pickProfileImage() async {
                final source = await _showImageSourceDialog();
                if (source == null) return;

                try {
                  final XFile? image = await _picker.pickImage(source: source);
                  if (image != null) {
                    setStateDialog(() {
                      _profileImages = [image];
                    });
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error selecting image: ${e.toString()}')),
                  );
                }
              }

              Future<void> _pickDocumentImages() async {
                final source = await _showImageSourceDialog();
                if (source == null) return;

                try {
                  if (source == ImageSource.camera) {
                    final XFile? image = await _picker.pickImage(source: source);
                    if (image != null) {
                      setStateDialog(() {
                        _documentImages.add(image);
                      });
                    }
                  } else {
                    final List<XFile>? images = await _picker.pickMultiImage();
                    if (images != null && images.isNotEmpty) {
                      setStateDialog(() {
                        _documentImages.addAll(images);
                      });
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error selecting images: ${e.toString()}')),
                  );
                }
              }

              return SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildEditImageSection(
                        label: "Profile Image",
                        imageList: _profileImages,
                        onPressed: pickProfileImage,
                        existingImageUrl: _staff!.profileImage,
                      ),
                      SizedBox(height: 12),
                      _buildUpdateTextField(_nameController, 'Full Name', Icons.person),
                      SizedBox(height: 12),
                      _buildUpdateTextField(_positionController, 'Position', Icons.work),
                      SizedBox(height: 12),
                      _buildUpdateTextField(_phoneController, 'Phone Number', Icons.phone, TextInputType.phone),
                      SizedBox(height: 12),
                      _buildUpdateTextField(_salaryController, 'Salary', Icons.attach_money, TextInputType.number),
                      SizedBox(height: 12),
                      _buildUpdateTextField(_nidController, 'NID Number', Icons.credit_card),
                      SizedBox(height: 12),
                      _buildUpdateTextField(_presentAddressController, 'Present Address', Icons.location_on, null, 2),
                      Row(
                        children: [
                          Checkbox(
                            value: _sameAddress,
                            onChanged: (value) {
                              setStateDialog(() {
                                _sameAddress = value!;
                                if (value) {
                                  _permanentAddressController.text = _presentAddressController.text;
                                }
                              });
                            },
                          ),
                          Text('Same as Present Address'),
                        ],
                      ),
                      if (!_sameAddress)...[
                        SizedBox(height: 12),
                        _buildUpdateTextField(_permanentAddressController, 'Permanent Address', Icons.home, null, 2),
                      ],
                      SizedBox(height: 12),
                      _buildUpdateTextField(_infoController, 'Additional Info', Icons.info, null, 3),
                      SizedBox(height: 12),
                      _buildUpdateTextField(_guardianInfoController, 'Guardian Info', Icons.family_restroom),
                      SizedBox(height: 12),
                      _buildUpdateTextField(_emailController, 'Email', Icons.email, TextInputType.emailAddress),
                      SizedBox(height: 12),
                      _buildEditImageSection(
                        label: "Document Images",
                        imageList: _documentImages,
                        onPressed: _pickDocumentImages,
                        isMulti: true,
                        existingImageUrl: _staff!.documents,
                      ),
                      SizedBox(height: 12),
                      ListTile(
                        leading: Icon(Icons.calendar_today),
                        title: Text('Joining Date'),
                        subtitle: Text(_selectedDate != null
                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                            : 'Not selected'),
                        trailing: IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setStateDialog(() => _selectedDate = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateTextField(TextEditingController controller, String label, IconData icon,
      [TextInputType? keyboardType, int maxLines = 1]) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  Widget _buildEditImageSection({
    required String label,
    required List<XFile> imageList,
    required VoidCallback onPressed,
    bool isMulti = false,
    String? existingImageUrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        if (existingImageUrl != null && existingImageUrl.isNotEmpty && imageList.isEmpty)
          Column(
            children: [
              Text('Current Image:'),
              SizedBox(height: 8),
              Image.network(
                _getDirectImageUrl(existingImageUrl),
                height: 100,
                width: 100,
                fit: BoxFit.cover,
              ),
              SizedBox(height: 8),
            ],
          ),
        if (imageList.isNotEmpty)
          Column(
            children: [
              Text('New Image(s):'),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: imageList.map((image) {
                  return Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.file(
                          File(image.path),
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (isMulti)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              // Use StatefulBuilder's setState to update the dialog state
                              (context as Element).markNeedsBuild();
                              imageList.remove(image);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  );
                }).toList(),
              ),
              SizedBox(height: 8),
            ],
          ),
        ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(Icons.add_photo_alternate),
          label: Text(isMulti ? 'Add ${label}' : 'Change ${label}'),
        ),
      ],
    );
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Select Image Source"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text("Camera"),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text("Gallery"),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _convertToBase64(XFile file) async {
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  Future<void> _updateStaff(Map<String, dynamic> updateData) async {
    final client = http.Client();
    try {
      final originalUrl = Uri.parse('https://script.google.com/macros/s/AKfycbzZC0sGCKNEm327PC4pYRmjGIOo5f94c6lAOb7Nj3-BEhkDh3N07aPM7SeiYPDo0Uw/exec?action=updateStaff');

      http.Response response = await client.post(
        originalUrl,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updateData),
      );

      print('Initial Response status: ${response.statusCode}');
      print('Initial Response headers: ${response.headers}');

      // Handle redirect
      if (response.statusCode == 302 || response.statusCode == 301) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          print('Redirecting to: $redirectUrl');
          response = await client.post(
            Uri.parse(redirectUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(updateData),
          );
          print('Redirect Response status: ${response.statusCode}');
          print('Redirect Response body: ${response.body}');
        }
      }

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Staff updated successfully!')),
          );
        } else {
          throw Exception(result['message'] ?? 'Update failed');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('Update error: $e');
      throw Exception('Update failed: $e');
    } finally {
      client.close();
    }
  }

  // UTILITY METHODS
  String _getDirectImageUrl(String driveUrl) {
    final regExp = RegExp(r'file/d/([a-zA-Z0-9_-]+)');
    final match = regExp.firstMatch(driveUrl);
    if (match != null && match.groupCount >= 1) {
      return 'https://drive.google.com/uc?export=view&id=${match.group(1)}';
    }
    return driveUrl;
  }

  String _formatSalary(String salary) {
    if (salary.isEmpty) return 'Not provided';
    try {
      final salaryNum = double.tryParse(salary);
      if (salaryNum == null) return salary;
      return '৳${NumberFormat('#,##0').format(salaryNum)}';
    } catch (e) {
      return salary;
    }
  }
}
class StaffProfile {
  final String id;
  final String name;
  final String position;
  final String phone;
  final String salary;
  final String nid;
  final String presentAddress;
  final String permanentAddress;
  final String info;
  final String guardianInfo;
  final String email;
  final String profileImage;
  final String documents;
  final DateTime? joiningDate;
  final String status;
  final String userRole;

  StaffProfile({
    required this.id,
    required this.name,
    required this.position,
    required this.phone,
    required this.salary,
    required this.nid,
    required this.presentAddress,
    required this.permanentAddress,
    required this.info,
    required this.guardianInfo,
    required this.email,
    required this.profileImage,
    required this.documents,
    this.joiningDate,
    required this.status,
    required this.userRole,
  });

  factory StaffProfile.fromJson(Map<String, dynamic> json) {
    print('Raw JSON data: $json'); // Debug print

    return StaffProfile(
      id: json['staff_id']?.toString() ?? '',
      name: json['staff_name']?.toString() ?? 'Unknown',
      position: json['staff_position']?.toString() ?? '',
      phone: json['staff_number']?.toString() ?? '',
      salary: json['staff_salary']?.toString() ?? '0',
      nid: json['staff_nid']?.toString() ?? '',
      presentAddress: json['staff_present_address']?.toString() ?? '',
      permanentAddress: json['staff_permanent_address']?.toString() ?? '',
      info: json['staff_info']?.toString() ?? '',
      guardianInfo: json['staff_guardian_info']?.toString() ?? '',
      email: json['staff_email']?.toString() ?? '',
      profileImage: json['staff_profileimage']?.toString() ?? '',
      documents: json['staff_document']?.toString() ?? '',
      joiningDate: json['joiningdate'] != null && json['joiningdate'].toString().isNotEmpty
          ? DateTime.tryParse(json['joiningdate'].toString())
          : null,
      status: json['status']?.toString() ?? 'Active',
      userRole: json['userrole']?.toString() ?? 'Staff',
    );
  }

  Map<String, dynamic> toJson() => {
    'staff_id': id,
    'staff_name': name,
    'staff_position': position,
    'staff_number': phone,
    'staff_salary': salary,
    'staff_nid': nid,
    'staff_present_address': presentAddress,
    'staff_permanent_address': permanentAddress,
    'staff_info': info,
    'staff_guardian_info': guardianInfo,
    'staff_email': email,
    'staff_profileimage': profileImage,
    'staff_document': documents,
    'joiningdate': joiningDate?.toIso8601String(),
    'status': status,
    'userrole': userRole,
  };
}