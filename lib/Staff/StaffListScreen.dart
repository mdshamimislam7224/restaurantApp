import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_inventory/Staff/StaffProfileScreen.dart';
import 'package:restaurant_inventory/api/apiClass.dart';
import 'package:restaurant_inventory/showToast/Toast_Message.dart';

import '../alertDialog/customDialog.dart';
import 'Staff.dart';
import 'StaffProfileView.dart';

class StaffListScreen extends StatefulWidget {
  @override
  _StaffListScreenState createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  List<Staff> staffList = [];
  bool isLoading = true;
  final ImagePicker _picker = ImagePicker();
  bool isRefreshing = false;
  Toast_Message toast = Toast_Message();
  @override
  void initState() {
    super.initState();
    _loadStaffData();
  }
  Future<void> _loadStaffData() async {
    if (!mounted) return;

    final dialog = customDialog(context);
    dialog.showLoading("Loading...", subtitle: "Please wait");
    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('${apiClass.baseUrlStaff}?action=getStaff'),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          setState(() {
            staffList = data.map((item) => Staff.fromJson(item)).toList();
            isLoading = false;
            isRefreshing = false;
          });
          dialog.dismiss();
          toast.showToast("Staff data loaded successfully", Colors.green, Colors.white);
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        isRefreshing = false;
      });
      dialog.dismiss();
      customDialog(context).showError(
        "Error Loading Staff",
        error.toString().replaceFirst("Exception: ", ""),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
      dialog.dismiss();
    }
  }

  Future<void> _deleteStaff(String staffId) async {
    // DO NOT instantiate customDialog here. Use the global dialogService.
     final dialog = customDialog(Navigator.of(context, rootNavigator: true).context);
       dialog.showLoading("Deleting Staff...", subtitle: "Please wait"); // Use the global service
    print('Deleting Staff ID: $staffId');

    final client = http.Client(); // Create a new HTTP client for this request
    try {
      http.Response response = await client.post(
        Uri.parse('${apiClass.baseUrlStaff}?action=deleteStaff'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'staffId': staffId.trim()}),
      ).timeout(const Duration(seconds: 30));

      print("Initial deleteStaff Response Status: ${response.statusCode}");
      print('Initial deleteStaff Response Body: ${response.body}');

      // --- Handle 302 Redirect explicitly, just like in submitData ---
      if (response.statusCode == HttpStatus.found ||
          response.statusCode == HttpStatus.movedPermanently ||
          response.statusCode == HttpStatus.seeOther ||
          response.statusCode == HttpStatus.temporaryRedirect) {
        final String? newLocation = response.headers['location'];
        if (newLocation != null) {
          print('Redirecting to: $newLocation');
          // This is crucial: the redirect from Apps Script is usually a GET
          // to the actual content after initial authorization.
          response = await client.get(
            Uri.parse(newLocation),
            headers: {
              'Content-Type': 'application/json',
            },
          ).timeout(const Duration(seconds: 300));
          print('Redirected Response Status Code: ${response.statusCode}');
          print('Redirected Raw Response Body: ${response.body}');
        }
      }
      // --- END Redirect Handling ---

      // Now, process the FINAL response (after any redirects)
      if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          if (responseData['status'] == 'success') {
            dialog.dismiss(); // Dismiss the loading dialog
            setState(() {
              staffList.removeWhere((staff) => staff.id == staffId);
            });
            toast.showToast("Staff $staffId deleted successfully", Colors.green, Colors.white);
            // Reload data, which will show its own loading/dismiss dialogs
            await _loadStaffData();
          }
          else {
            dialog.dismiss();
            dialog.showError("Delete Failed", responseData['message'] ?? 'Unknown error from server');
          }
      }
      else {
        // Handle non-200 status codes (e.g., 404, 500, or a final 302 that wasn't handled)
        dialog.dismiss();
       dialog.showError("Delete Failed", "Server returned status: ${response.statusCode}\nBody: ${response.body}");
      }
    } on TimeoutException catch (e) {
      print("deleteStaff Error (Timeout): $e");
      dialog.dismiss();
      dialog.showError("Network Timeout", "The delete request timed out. Please check your connection.");
    } catch (error) {
      print("deleteStaff Error: $error");
      dialog.dismiss();
      // Use the global customDialogInstance (which uses dialogService internally)
      dialog.showError("Delete Failed", error.toString().replaceFirst("Exception: ", ""),);
    } finally {
      client.close(); // Always close the HTTP client
    }
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
    String staffStatus = "Deactivate"; // Default status
    String staffuserRole = "Staff"; // Default status


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
            Widget _buildStatusDropdown() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    "Staff Status *",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: staffStatus,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: "Active",
                          child: Text("Active"),
                        ),
                        DropdownMenuItem(
                          value: "Deactivate",
                          child: Text("Deactivate"),
                        ),
                      ],
                      onChanged: (String? newValue) {
                        setStateDialog(() {
                          staffStatus = newValue!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              );
            }

            Widget _buildUserRoleDropdown() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    "Staff Role *",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: staffuserRole,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: "Admin",
                          child: Text("Admin"),
                        ),
                        DropdownMenuItem(
                          value: "Staff",
                          child: Text("Staff"),
                        ),
                      ],
                      onChanged: (String? newValue) {
                        setStateDialog(() {
                          staffuserRole = newValue!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              );
            }

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
                // If form is not valid, stop execution immediately.
                return;
              }
              final dialog = customDialog(context);
              // --- Start: Prepare Data ---
              final List<Map<String, String>> formattedProfileImages = [];
              final List<Map<String, String>> formattedImages = [];

              for (XFile image in profileImageList) {
                String base64Image = await _convertToBase64(image);
                formattedProfileImages.add({
                  'data': base64Image,
                  'mimeType': 'image/jpeg',
                });
              }
              for (XFile image in imagesFileList) {
                String base64Image = await _convertToBase64(image);
                formattedImages.add({
                  'data': base64Image,
                  'mimeType': 'image/jpeg',
                });
              }

              Map<String, dynamic> staffData = {
                'name': staffNameController.text,
                'nid': staffNIDController.text,
                'phone': staffPhoneController.text,
                'position': staffPositionController.text,
                'present_address': staffPresentAddressController.text,
                'permanent_address':
                sameAddress
                    ? staffPresentAddressController.text
                    : staffPermanentAddress.text,
                'salary': staffSalaryController.text,
                'staff_id': staffIdController.text,
                'join_date': staffJoinDateController.text,
                'email': staffEmailController.text,
                'guardian_info': staffGuardianInfoController.text,
                'info': staffInfoController.text,
                'status': staffStatus, // Add status to the data
                'userRole': staffuserRole,
                'profileImage': formattedProfileImages,
                'imagesData': formattedImages,
              };
              print('Staff Data: $staffData');
              // --- End: Prepare Data ---
              // --- Start: Network Request & Dialog Management ---
              dialog.showLoading("Staff Adding...", subtitle: "Please wait"); // Show initial loading dialog

              final client = http.Client(); // Create an HTTP client for the request
              // ... inside submitData() function ...
              try {
                http.Response response = await client.post(
                  Uri.parse('${apiClass.baseUrlStaff}?action=StaffAdd'),
                  headers: {
                    'Content-Type': 'application/json',
                  },
                  body: json.encode(staffData),
                ).timeout(const Duration(seconds: 300));

                // --- START OF MODIFIED SECTION ---

                // Manually follow redirect if needed
                if (response.statusCode == HttpStatus.found ||
                    response.statusCode == HttpStatus.movedPermanently ||
                    response.statusCode == HttpStatus.seeOther ||
                    response.statusCode == HttpStatus.temporaryRedirect) {
                  final String? newLocation = response.headers['location'];
                  if (newLocation != null) {
                    print('Redirecting to: $newLocation');
                    // This is crucial: the redirect from Apps Script is usually a GET
                    // to the actual content after initial authorization.
                    response = await client.get(
                      Uri.parse(newLocation),
                      headers: {
                        'Content-Type': 'application/json',
                      },
                    ).timeout(const Duration(seconds: 300));
                    print('Redirected Response Status Code: ${response.statusCode}');
                    print('Redirected Raw Response Body: ${response.body}');
                  }
                }

                print('Final Response Status Code: ${response.statusCode}');
                print('Final Raw Response Body: ${response.body}');

                // Process the final response (THIS IS THE UNIFIED BLOCK)
                if (response.statusCode == 200) {
                  final responseData = json.decode(response.body);
                  if (responseData['status'] == 'success') {
                    dialog.dismiss(); // Dismiss loading dialog
                    toast.showToast("Staff Added Successfully", Colors.green, Colors.white);
                    Navigator.of(context).pop(); // Close the form dialog
                    await _loadStaffData(); // This will show its own loading dialog
                  } else {
                    dialog.dismiss();
                    if (responseData['status'] == 'already exists') {
                      customDialog(context).showError("Alert !", responseData['message']);

                    }
                    else{
                      customDialog(context).showError("Error", responseData['message']);
                    }
                  }
                } else {
                  dialog.dismiss();
                  customDialog(context).showError("Error", "Failed with status: ${response.statusCode}");
                }

                // --- END OF MODIFIED SECTION ---

              } on TimeoutException catch (e) {
                dialog.dismiss(); // Dismiss loading on timeout
                print('Request timed out: $e');
                dialog.showError("Network Timeout",
                    'The request took too long to complete. Please try again.');
              } catch (e) {
                dialog.dismiss(); // Dismiss loading on any other error
                print('General Error: $e');
                customDialog(Navigator.of(context, rootNavigator: true).context).showError("Error", e.toString());
              } finally {
                client.close(); // Always close the HTTP client to free up resources
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

                      // Staff Status Dropdown
                      _buildStatusDropdown(),

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
                      _buildUserRoleDropdown(),

                      // Profile Image
                      _buildImageSection(
                        label: "Profile Image *",
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Staff List'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() => isRefreshing = true);
              _loadStaffData();
            },
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddStaffDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (staffList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('No staff members found'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadStaffData,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => isRefreshing = true);
        await _loadStaffData();
      },
      child: ListView.builder(
        itemCount: staffList.length,
        itemBuilder: (context, index) => _buildStaffItem(staffList[index]),
      ),
    );
  }

  Widget _buildStaffItem(Staff staff) {
    return GestureDetector(
          onTap: () {
           // Navigate to StaffProfileView when the item is tapped
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StaffProfileScreen(staffId: staff.id),
              ),
            );
            // Navigator.push(
            //   context,
            //   MaterialPageRoute(
            //     builder: (context) => StaffProfileView(
            //       staff: staff,
            //       onEditPressed: () => _showEditDialog(staff),
            //     ),
            //   ),
            // );
          },
          child: Dismissible(
      key: ValueKey(staff.id),
      direction: DismissDirection.horizontal,
      background: _buildSwipeAction(Colors.red, Icons.delete, Alignment.centerLeft),
      secondaryBackground: _buildSwipeAction(Colors.blue, Icons.edit, Alignment.centerRight),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          _showEditDialog(staff);
          return false;
        }
        return await _showDeleteConfirmation(staff.name);
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          _deleteStaff(staff.id);
        }
      },
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        elevation: 2,
        child: ListTile(
          leading: _buildStaffAvatar(staff.profileImage),
          title: Text(staff.id, style: TextStyle(fontWeight: FontWeight.bold),),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${staff.position}'),
              Text('Phone: ${staff.phone}'),
            ],
          ),
          trailing: Text(
            '\$${staff.salary}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    )
    );
  }

  Widget _buildStaffAvatar(String imageUrl) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey[200],
      child: ClipOval(
        child: imageUrl.isNotEmpty
            ? CachedNetworkImage(imageUrl: _getDirectImageUrl(imageUrl),
          placeholder: (context, url) => CircularProgressIndicator(strokeWidth: 2),
          errorWidget: (context, url, error) => Icon(Icons.person, size: 24),
          fit: BoxFit.cover,
          width: 48,
          height: 48,
        )
            : Icon(Icons.person, size: 24),
      ),
    );
  }

  String _getDirectImageUrl(String driveUrl) {
    // Convert Google Drive share URL to direct download URL
    final regExp = RegExp(r'file/d/([a-zA-Z0-9_-]+)');
    final match = regExp.firstMatch(driveUrl);
    if (match != null && match.groupCount >= 1) {
      return 'https://drive.google.com/uc?export=view&id=${match.group(1)}';
    }
    return driveUrl;
  }

  Widget _buildSwipeAction(Color color, IconData icon, Alignment alignment) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      color: color,
      alignment: alignment,
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }

  Future<bool> _showDeleteConfirmation(String name) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete'),
        content: Text('Delete $name from staff list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showEditDialog(Staff staff) {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController _nameController = TextEditingController(text: staff.name);
    final TextEditingController _positionController = TextEditingController(text: staff.position);
    final TextEditingController _phoneController = TextEditingController(text: staff.phone);
    final TextEditingController _salaryController = TextEditingController(text: staff.salary);
    final TextEditingController _nidController = TextEditingController(text: staff.nid);
    final TextEditingController _presentAddressController = TextEditingController(text: staff.presentAddress);
    final TextEditingController _permanentAddressController = TextEditingController(text: staff.permanentAddress);
    final TextEditingController _infoController = TextEditingController(text: staff.info);
    final TextEditingController _guardianInfoController = TextEditingController(text: staff.guardianInfo);
    final TextEditingController _emailController = TextEditingController(text: staff.email);
    DateTime? _selectedDate = staff.joiningDate;
    List<XFile> _profileImages = [];
    List<XFile> _documentImages = [];
    bool _sameAddress = staff.presentAddress == staff.permanentAddress;
    final ImagePicker _picker = ImagePicker();
    // Initialize images if they exist
    if (staff.profileImage.isNotEmpty) {
      // You might need to handle existing images differently
    }
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

                      for (XFile image in _profileImages) {
                        newProfileImages.add({
                          'data': await _convertToBase64(image),
                          'mimeType': 'image/jpeg',
                        });
                      }

                      for (XFile image in _documentImages) {
                        newDocumentImages.add({
                          'data': await _convertToBase64(image),
                          'mimeType': 'image/jpeg',
                        });
                      }

                      final updatedStaff = Staff(
                        id: staff.id,
                        name: _nameController.text,
                        position: _positionController.text,
                        phone: _phoneController.text,
                        salary: _salaryController.text,
                        nid: _nidController.text,
                        presentAddress: _presentAddressController.text,
                        permanentAddress: _permanentAddressController.text,
                        info: _infoController.text,
                        guardianInfo: _guardianInfoController.text,
                        email: _emailController.text,
                        profileImage: newProfileImages.isNotEmpty
                            ? newProfileImages.first['data'] ?? staff.profileImage
                            : staff.profileImage,
                        documents: newDocumentImages.isNotEmpty
                            ? newDocumentImages.map((img) => img['data']).join(',')
                            : staff.documents,
                        joiningDate: _selectedDate,
                      );

                      await _updateStaff(updatedStaff, staff.id, _profileImages, _documentImages,);
                      Navigator.pop(context); // close loading
                      Navigator.pop(context); // close dialog
                    } catch (e) {
                      Navigator.pop(context);
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
                final source = await showImageSourceDialog();
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
                final source = await showImageSourceDialog();
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
                      _buildImageSection(
                        label: "Profile Image",
                        imageList: _profileImages,
                        onPressed: pickProfileImage,
                        existingImageUrl: staff.profileImage,
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
                      _buildImageSection(label: "Document Images", imageList: _documentImages,
                        onPressed: _pickDocumentImages,
                        isMulti: true,
                        existingImageUrl: staff.documents,
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


// Helper method to show image source dialog
  Future<ImageSource?> showImageSourceDialog() async {
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

// Updated image section widget
  Widget _buildImageSection({
    required String label,
    required List<XFile> imageList,
    required VoidCallback onPressed,
    String? existingImageUrl,
    bool isMulti = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),

        if (imageList.isEmpty && existingImageUrl?.isNotEmpty == true)
        // Show existing image
          isMulti
              ? Wrap(
            children: existingImageUrl!.split(',').map((url) {
              return Padding(
                padding: EdgeInsets.all(4),
                child: Image.network(
                  _getDirectImageUrl(url),
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              );
            }).toList(),
          )
              : ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _getDirectImageUrl(existingImageUrl!),
              height: 100,
              width: 100,
              fit: BoxFit.cover,
            ),
          )
        else if (imageList.isNotEmpty)
        // Show new selected images
          isMulti
              ? Wrap(
            children: imageList.map((file) {
              return Padding(
                padding: EdgeInsets.all(4),
                child: Stack(
                  children: [
                    Image.file(
                      File(file.path),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: Icon(Icons.close, size: 20, color: Colors.red),
                        onPressed: () {
                          // Remove image from list
                          // Note: You'll need to wrap this in setState if using
                        },
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          )
              : ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(imageList.first.path),
              height: 100,
              width: 100,
              fit: BoxFit.cover,
            ),
          )
        else
          Text(
            "No ${isMulti ? 'documents' : 'image'} selected",
            style: TextStyle(color: Colors.grey),
          ),

        SizedBox(height: 8),
        ElevatedButton(
          onPressed: onPressed,
          child: Text(isMulti ? "Select Documents" : "Select Image"),
        ),
      ],
    );
  }

  // Update the function declaration to include maxLines parameter
  Widget _buildUpdateTextField(
      TextEditingController controller,
      String label,
      IconData icon, [
        TextInputType? inputType,
        int maxLines = 1,  // Add maxLines parameter with default value
      ]) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0),),

      ),
      keyboardType: inputType,
      maxLines: maxLines,  // Use the parameter here
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        if (label.contains('Email') && !value.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }
  Future<void> _updateStaff(Staff updatedStaff, String originalStaffId, List<XFile> profileImages, List<XFile> documentImages,) async {
    try {
      // Convert images to base64
      final List<Map<String, String>> profileImageData = [];
      if (profileImages.isNotEmpty) {
        for (XFile image in profileImages) {
          profileImageData.add({
            'data': await _convertToBase64(image),
            'mimeType': 'image/jpeg',
          });
        }
      }

      final List<Map<String, String>> documentImageData = [];
      if (documentImages.isNotEmpty) {
        for (XFile image in documentImages) {
          documentImageData.add({
            'data': await _convertToBase64(image),
            'mimeType': 'image/jpeg',
          });
        }
      }

      final payload = {
        "staff_id": updatedStaff.id,
        "name": updatedStaff.name,
        "position": updatedStaff.position,
        "phone": updatedStaff.phone,
        "salary": updatedStaff.salary,
        "nid": updatedStaff.nid,
        "present_address": updatedStaff.presentAddress,
        "permanent_address": updatedStaff.permanentAddress,
        "info": updatedStaff.info,
        "guardian_info": updatedStaff.guardianInfo,
        "email": updatedStaff.email,
        "join_date": updatedStaff.joiningDate?.toIso8601String(),
        "profileImage": profileImageData, // Use converted data
        "imagesData": documentImageData,  // Use converted data
        "originalStaffId": originalStaffId,
      };

      debugPrint('Sending payload: ${json.encode(payload)}');
      final client = http.Client();
      http.Response response = await client.post(
        Uri.parse('${apiClass.baseUrlStaff}?action=updateStaff'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 300));


      if (response.statusCode == HttpStatus.found ||
          response.statusCode == HttpStatus.movedPermanently ||
          response.statusCode == HttpStatus.seeOther ||
          response.statusCode == HttpStatus.temporaryRedirect) {
        final String? newLocation = response.headers['location'];
        if (newLocation != null) {
          print('Redirecting to: $newLocation');
          // This is crucial: the redirect from Apps Script is usually a GET
          // to the actual content after initial authorization.
          response = await client.get(
            Uri.parse(newLocation),
            headers: {
              'Content-Type': 'application/json',
            },
          ).timeout(const Duration(seconds: 300));
          print('Redirected Response Status Code: ${response.statusCode}');
          print('Redirected Raw Response Body: ${response.body}');
        }
      }

      if (response.statusCode == 200 ||response.statusCode == 302) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          setState(() {
            staffList.removeWhere((s) => s.id == originalStaffId);
            _loadStaffData();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Update successful!')),
          );
        } else {
          throw Exception(responseData['message'] ?? 'Update failed');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Error in _updateStaff: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: ${e.toString()}')),
      );
    }
  }
  Future<String> _convertToBase64(XFile file) async {
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }



}

