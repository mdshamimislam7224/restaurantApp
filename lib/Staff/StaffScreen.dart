import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../localDB/DBHelper.dart';
import '../showToast/Toast_Message.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  List<Map<String, dynamic>> staffList = [];
  Toast_Message toast_message = Toast_Message();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    loadStaff();
  }

  Future<void> loadStaff() async {
    final result = await DBHelper.getAllStaff();
    setState(() {
      staffList = result;
    });
  }

  void showAddStaffDialog(BuildContext context) {
    // Controllers for all fields
    final TextEditingController staffJoinDateController = TextEditingController();
    final TextEditingController staffIdController = TextEditingController();
    final TextEditingController staffNameController = TextEditingController();
    final TextEditingController staffNIDController = TextEditingController();
    final TextEditingController staffPhoneController = TextEditingController();
    final TextEditingController staffSalaryController = TextEditingController();
    final TextEditingController staffInfoController = TextEditingController();
    final TextEditingController staffGuardianInfoController = TextEditingController();
    final TextEditingController staffPositionController = TextEditingController();
    final TextEditingController staffPresentAddressController = TextEditingController();
    final TextEditingController staffPermanentAddress = TextEditingController();
    final TextEditingController staffEmailController = TextEditingController();

    // State variables
    bool sameAddress = false;
    List<XFile> imagesFileList = [];
    List<XFile> profileImageList = [];

    // Error states
    bool nameError = false;
    bool nidError = false;
    bool phoneError = false;
    bool positionError = false;
    bool presentAddressError = false;
    bool permanentAddressError = false;
    bool salaryError = false;
    bool idError = false;
    bool joinDateError = false;
    bool profileImageError = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Validate all required fields
            bool validateForm() {
              setStateDialog(() {
                nameError = staffNameController.text.isEmpty;
                nidError = staffNIDController.text.isEmpty;
                phoneError = staffPhoneController.text.isEmpty;
                positionError = staffPositionController.text.isEmpty;
                presentAddressError = staffPresentAddressController.text.isEmpty;
                permanentAddressError = staffPermanentAddress.text.isEmpty && !sameAddress;
                salaryError = staffSalaryController.text.isEmpty;
                idError = staffIdController.text.isEmpty;
                joinDateError = staffJoinDateController.text.isEmpty;
                profileImageError = profileImageList.isEmpty;
              });
              return !(nameError || nidError || phoneError || positionError ||
                  presentAddressError || permanentAddressError || salaryError ||
                  idError || joinDateError || profileImageError);
            }

            // Submit form data
            Future<void> submitData() async {
              if (!validateForm()) {
                return;
              }

              try {
                // Prepare staff data
                final List<Map<String, String>> formattedProfileImages = [];
                final List<Map<String, String>> formattedImages = [];

                for (XFile image in profileImageList) {
                  String base64Image = await _convertToBase64(image);
                  formattedProfileImages.add({
                    'data': base64Image,
                    'mimeType': 'image/jpeg', // Adjust based on your image type
                  });
                }
                for (XFile image in imagesFileList) {
                  String base64Image = await _convertToBase64(image);
                  formattedImages.add({'data': base64Image,
                    'mimeType': 'image/jpeg', // Adjust based on your image type
                  });
                }

                final String url = 'https://script.google.com/macros/s/AKfycbwmJ_8fmDccVHONgyrIAwty_CBNXwszTTxgOQnybiJCdqaE6T0VejvT9lIhwFZmX_M/exec?action=StaffAdd';  // Replace with your Google Apps Script URL

                Map<String, dynamic> staffData = {
                  'name': staffNameController.text,
                  'nid': staffNIDController.text,
                  'phone': staffPhoneController.text,
                  'position': staffPositionController.text,
                  'present_address': staffPresentAddressController.text,
                  'permanent_address': sameAddress
                      ? staffPresentAddressController.text
                      : staffPermanentAddress.text,
                  'salary': staffSalaryController.text,
                  'staff_id': staffIdController.text,
                  'join_date': staffJoinDateController.text,
                  'email': staffEmailController.text,
                  'guardian_info': staffGuardianInfoController.text,
                  'info': staffInfoController.text,
                  'profileImage':formattedProfileImages,
                  'imagesData': formattedImages,
                };
                print('Staff Data: $staffData');
                // TODO: Implement your actual data saving logic
                // await DBHelper.insertStaff(staffData);

                try {
                  final response = await http.post(
                    Uri.parse(url),
                    headers: {
                      'Content-Type': 'application/json',
                    },
                    body: json.encode(staffData),
                  ).timeout(Duration(seconds: 30));

                  // Handle redirect manually if needed
                  if (response.statusCode == 302) {
                    final redirectUrl = response.headers['location'];
                    if (redirectUrl != null) {
                      final redirectedResponse = await http.post(
                        Uri.parse(redirectUrl),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode(staffData),
                      );
                      print("Redirected statusCode: ${redirectedResponse.statusCode}");
                      print("Redirected body: ${redirectedResponse.body}");
                      // Process the redirected response here
                      return;
                    }
                  }

                  print("statusCode: ${response.statusCode}");
                  print("body: ${response.body}");

                  if (response.statusCode == 200) {
                    final responseData = json.decode(response.body);
                    if (responseData['status'] == 'success') {
                      print('Data submitted successfully');
                        Navigator.pop(context); // Close loading
                        Navigator.pop(context); // Close dialog
                    } else {
                      print('Server error: ${responseData['message']}');
                    }
                  } else {
                    print('Failed with status: ${response.statusCode}');
                    print('Response body: ${response.body}');
                    Navigator.pop(context); // Close loading
                  }
                }on TimeoutException catch (e) {
                  print('Request timed out: $e');
                  Navigator.pop(context); // Close loading
                }
                catch (error) {
                  print('Error: $error');
                  Navigator.pop(context); // Close loading
                }

                // final success = await DBHelper.insertStaff(staffData);
                // if (success) {
                //   loadStaff();
                //   Navigator.pop(context); // Close loading
                //   Navigator.pop(context); // Close dialog
                //   ScaffoldMessenger.of(context).showSnackBar(
                //     const SnackBar(content: Text('Staff added successfully')),
                //   );
                // } else {
                //   ScaffoldMessenger.of(context).showSnackBar(
                //     const SnackBar(content: Text('Failed to add staff')),
                //   );
                //   Navigator.pop(context); // Close loading
                // }
                // loadStaff(); // Refresh staff list if needed
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')));
              }
            }

            // Modified image picker methods with camera option
            Future<ImageSource?> showImageSourceDialog() async {
              return await showDialog<ImageSource>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Select Image Source"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.camera_alt),
                        title: const Text("Camera"),
                        onTap: () => Navigator.pop(context, ImageSource.camera),
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_library),
                        title: const Text("Gallery"),
                        onTap: () => Navigator.pop(context, ImageSource.gallery),
                      ),
                    ],
                  ),
                ),
              );
            }

            Future<void> _pickProfileImage() async {
              final source = await showImageSourceDialog();
              if (source == null) return;

              try {
                final XFile? image = await _picker.pickImage(source: source);
                if (image != null) {
                  setStateDialog(() {
                    profileImageList = [image];
                    profileImageError = false;
                  });
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error selecting image: ${e.toString()}')));
              }
            }
            Future<void> _pickDocumentImages() async {
              final source = await showImageSourceDialog();
              if (source == null) return;

              try {
                if (source == ImageSource.camera) {
                  final XFile? image = await _picker.pickImage(source: source);
                  if (image != null) {
                    setStateDialog(() {
                      imagesFileList.add(image);
                    });
                  }
                } else {
                  final List<XFile>? images = await _picker.pickMultiImage();
                  if (images != null && images.isNotEmpty) {
                    setStateDialog(() {
                      imagesFileList.addAll(images);
                    });
                  }
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error selecting images: ${e.toString()}')));
              }
            }

            return Dialog(
              insetPadding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              child: Scaffold(
                appBar: AppBar(
                  title: const Text("Add New Staff"),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Staff Name
                      _buildTextField(
                        label: "Staff full name *",
                        controller: staffNameController,
                        error: nameError,
                        hint: "as name in passport or nid",
                        onChanged: (v) => setStateDialog(() => nameError = v.isEmpty),
                      ),

                      // NID/Passport
                      _buildTextField(
                        label: "Staff NID or passport *",
                        controller: staffNIDController,
                        error: nidError,
                        hint: "NID or passport Number",
                        onChanged: (v) => setStateDialog(() => nidError = v.isEmpty),
                      ),

                      // Phone Number
                      _buildTextField(
                        label: "Staff Mobile Number *",
                        controller: staffPhoneController,
                        error: phoneError,
                        hint: "Enter Phone Number",
                        keyboardType: TextInputType.phone,
                        onChanged: (v) => setStateDialog(() => phoneError = v.isEmpty),
                      ),

                      // Position
                      _buildTextField(
                        label: "Staff Position *",
                        controller: staffPositionController,
                        error: positionError,
                        hint: "Enter Position",
                        onChanged: (v) => setStateDialog(() => positionError = v.isEmpty),
                      ),

                      // Present Address
                      _buildTextField(
                        label: "Present Address *",
                        controller: staffPresentAddressController,
                        error: presentAddressError,
                        hint: "Enter Present Address",
                        onChanged: (v) => setStateDialog(() => presentAddressError = v.isEmpty),
                      ),

                      // Same as Present Address Checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: sameAddress,
                            onChanged: (value) {
                              setStateDialog(() {
                                sameAddress = value!;
                                if (value) {
                                  staffPermanentAddress.text = staffPresentAddressController.text;
                                  permanentAddressError = false;
                                }
                              });
                            },
                          ),
                          const Text("Same as Present Address"),
                        ],
                      ),

                      // Permanent Address
                      _buildTextField(
                        label: "Permanent Address *",
                        controller: staffPermanentAddress,
                        error: permanentAddressError,
                        hint: "Enter Permanent Address",
                        enabled: !sameAddress,
                        onChanged: (v) => setStateDialog(() => permanentAddressError = v.isEmpty),
                      ),

                      // Email (optional)
                      _buildTextField(
                        label: "Staff Email",
                        controller: staffEmailController,
                        hint: "Enter Email",
                        keyboardType: TextInputType.emailAddress,
                      ),

                      // Guardian Info (optional)
                      _buildTextField(
                        label: "Staff Guardian Info",
                        controller: staffGuardianInfoController,
                        hint: "Enter Guardian Info",
                      ),

                      // Staff Info (optional)
                      _buildTextField(
                        label: "Staff Info",
                        controller: staffInfoController,
                        hint: "Enter Info Shortly",
                      ),

                      // Salary
                      _buildTextField(
                        label: "Staff Salary *",
                        controller: staffSalaryController,
                        error: salaryError,
                        hint: "Enter Basic Salary",
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setStateDialog(() => salaryError = v.isEmpty),
                      ),

                      // Staff ID
                      _buildTextField(
                        label: "Staff ID *",
                        controller: staffIdController,
                        error: idError,
                        hint: "Enter Staff ID",
                        onChanged: (v) => setStateDialog(() => idError = v.isEmpty),
                      ),

                      // Join Date
                      _buildTextField(
                        label: "Staff Joining Date *",
                        controller: staffJoinDateController,
                        error: joinDateError,
                        hint: "Enter Join Date",
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setStateDialog(() {
                              staffJoinDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                              joinDateError = false;
                            });
                          }
                        },
                        onChanged: (v) => setStateDialog(() => joinDateError = v.isEmpty),
                      ),

                      // Profile Image
                      _buildImageSection(
                        label: "Profile Image *",
                        error: profileImageError,
                        imageList: profileImageList,
                        onPressed: _pickProfileImage,
                      ),

                      // Document Images (optional)
                      _buildImageSection(
                        label: "Document Images (Optional)",
                        imageList: imagesFileList,
                        onPressed: _pickDocumentImages,
                        isMulti: true,
                      ),

                      // Add Staff Button
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: submitData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            "ADD STAFF",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper widget for text fields
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool error = false,
    bool enabled = true,
    TextInputType? keyboardType,
    VoidCallback? onTap,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: error ? Colors.red : null,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: error ? Colors.red : Colors.grey,
                width: error ? 2.0 : 1.0,
              ),
            ),
            enabled: enabled,
            errorText: error ? "This field is required" : null,
          ),
          keyboardType: keyboardType,
          onTap: onTap,
          onChanged: onChanged,
        ),
      ],
    );
  }

  // Helper widget for image sections
  Widget _buildImageSection({
    required String label,
    required List<XFile> imageList,
    required VoidCallback onPressed,
    bool error = false,
    bool isMulti = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: error ? Colors.red : null,
          ),
        ),
        const SizedBox(height: 8),
        if (imageList.isEmpty)
          Text(
            "No ${isMulti ? 'document' : 'profile'} image selected",
            style: TextStyle(color: error ? Colors.red : Colors.grey),
          )
        else if (!isMulti)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(imageList.first.path),
              height: 100,
              width: 100,
              fit: BoxFit.cover,
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: imageList.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  Image.file(
                    File(imageList[index].path),
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        // Remove image from list
                        // Note: You'll need to wrap this in setStateDialog if using
                      },
                    ),
                  )
                ],
              );
            },
          ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: onPressed,
          child: Text(isMulti ? "Select Documents" : "Select Profile Image"),
        ),
      ],
    );
  }
  void deleteStaff(int id) async {
    await DBHelper.deleteStaff(id);
    loadStaff();
  }
  // Convert the picked image to base64
  Future<String> _convertToBase64(XFile image) async {
    final bytes = await image.readAsBytes();
    return base64Encode(bytes);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Staff List")),
      body: ListView.builder(
        itemCount: staffList.length,
        itemBuilder: (context, index) {
          final staff = staffList[index];

          // Decode the base64 image if it exists
          Widget profileImage = const CircleAvatar(
            child: Icon(Icons.person, size: 30),
          );

          if (staff['profileImage'] != null && staff['profileImage'].isNotEmpty) {
            try {
              profileImage = CircleAvatar(
                backgroundImage: MemoryImage(base64Decode(staff['profileImage'])),
                radius: 25,
              );
            } catch (e) {
              print('Error loading image: $e');
            }
          }

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  // Profile Image
                  Hero(
                    tag: 'staff-image-${staff['id']}',
                    child: profileImage,
                  ),
                  const SizedBox(width: 16),

                  // Staff Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff['name'] ?? 'No Name',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Position: ${staff['position'] ?? 'Not specified'}",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          "Phone: ${staff['phone'] ?? 'Not specified'}",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => deleteStaff(staff['id']),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => print(staff['id']),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddStaffDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}