import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../localDB/DBHelper.dart';
import '../showToast/Toast_Message.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  List<Map<String, dynamic>> staffList = [];
  Toast_Message toast_message=Toast_Message();
  final List<XFile> imagesFileList = []; // To store selected images
  final List<XFile> profileImageList = []; // To store selected images
  final ImagePicker _picker = ImagePicker();
  List<String> base64Images = [];

  @override
  void initState() {
    super.initState();
    loadStaff();
  }

  Future<void> loadStaff() async {
    // final result = await DBHelper.getStaffList();
    // setState(() {
    //   staffList = result;
    // });
  }

  void showAddStaffDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController positionController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text("Add Staff"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: "Name")),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: "Phone")),
                TextField(controller: positionController, decoration: const InputDecoration(labelText: "Position")),
                SizedBox(height: 16.0),
                SizedBox(height: 16,),
                Center(
                  child: profileImageList.isEmpty
                      ? Text(
                    "No Profile Images.",
                    style: TextStyle(color: Colors.white54),
                  )
                      : GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 1, // Number of images per row
                      // Space between images
                    ),
                    itemCount: profileImageList.length,
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12), // Set the corner radius for rounded corners
                        child: Image.file(
                          File(profileImageList[index].path),
                          fit: BoxFit.contain, // Ensures the image fills the available space
                          height: 50, // Optional: Set the height for images
                          width: 50,  // Optional: Set the width for images
                        ),
                      );
                    },
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (profileImageList.isEmpty) {
                      _showProfileImageSourceDialog();
                    }
                    else{
                      print("Profile Image Exits");
                      toast_message.showToast("Profile Image Exits",Colors.grey,Colors.white);
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 18.0, horizontal: 12.0),
                    decoration: BoxDecoration(
                      color: Color(0xFF758794).withOpacity(0.9), // Same background color
                      borderRadius: BorderRadius.circular(20), // Rounded corners
                    ),
                    child: Center(
                      child: Text(
                        profileImageList.isEmpty
                            ? "Select Profile Image"
                            : "Profile Image Selected",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.0, // Adjust font size as needed
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                //if (nameController.text.trim().isNotEmpty) {
                //   await DBHelper.insertStaff(
                //     name: nameController.text.trim(),
                //     phone: phoneController.text.trim(),
                //     position: positionController.text.trim(),
                //   );
                //   Navigator.pop(context);
                //   loadStaff();
                // }
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );


  }
  void _showProfileImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Choose Image Source"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text("From Camera"),
                onTap: () async {

                  Navigator.of(context).pop(); // Close the dialog
                  try {
                    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
                    if (image != null) {
                      setState(() {
                        profileImageList.add(image);
                      });
                    }
                  } catch (e) {
                    print("Error picking image from camera: $e");
                  }

                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text("From Gallery"),
                onTap: () async {
                  Navigator.of(context).pop(); // Close the dialog
                  try {
                    final List<XFile>? selectedImages = await _picker.pickMultiImage();
                    if (selectedImages != null && selectedImages.isNotEmpty) {
                      setState(() {
                        profileImageList.addAll(selectedImages);
                      });
                    }
                  } catch (e) {
                    print("Error picking images from gallery: $e");
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void deleteStaff(int id) async {
    //await DBHelper.deleteStaff(id);
    //loadStaff();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Staff List")),
      body: ListView.builder(
        itemCount: staffList.length,
        itemBuilder: (context, index) {
          final staff = staffList[index];
          return ListTile(
            title: Text(staff['name']),
            subtitle: Text("Phone: ${staff['phone'] ?? ''} | Position: ${staff['position'] ?? ''}"),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => deleteStaff(staff['id']),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddStaffDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
