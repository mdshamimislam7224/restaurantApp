import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'package:restaurant_inventory/Navigation/Navigation_Class.dart';
import '../attendance/Recognizer.dart';
import '../attendance/faceRegistration.dart';
import '../localDB/DatabaseHelper.dart';
import '../sharedPref/SharedPrefsHelper.dart';

class StaffLoginPage extends StatefulWidget {
  const StaffLoginPage({Key? key}) : super(key: key);

  @override
  State<StaffLoginPage> createState() => _StaffLoginPageState();
}

class _StaffLoginPageState extends State<StaffLoginPage> {
  final SharedPrefsHelper _sharedPrefsHelper = SharedPrefsHelper();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController staffIdCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();
  late faceRegistration faceReg;
  late FaceDetector detector;
  late DatabaseHelper dbHelper;

  bool isLoading = false;

  final String apiUrl = "https://script.google.com/macros/s/AKfycbxLSYMHjEtVLPEDLRhBUFy9wUIgHOd9wYBOZXsHIuegQJBSvSkhWLC4OcsP96t8zikR/exec?action=login";

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "staffId": staffIdCtrl.text.trim(),
          "password": passwordCtrl.text.trim(),
        }),
      );

      if ([301, 302, 307, 308].contains(response.statusCode)) {
        final newUrl = response.headers['location'];
        if (newUrl != null) {
          final redirected = await http.get(Uri.parse(newUrl));
          await _handleLoginResponse(redirected.body);
          return;
        }
      }

      await _handleLoginResponse(response.body);
    } catch (e) {
      _showMessage("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _handleLoginResponse(String body) async {
    try {
      final data = jsonDecode(body);
      print(data);
      if (data["status"] == "success") {
        _showMessage("Login Successful ✅");
        final staffInfo = data["data"];
        final sharedPrefsHelper = SharedPrefsHelper();
        final isLoggedIn = await sharedPrefsHelper.isStaffLoggedIn();
        print("Is logged in: $isLoggedIn");
        final profileImageUrl = staffInfo["staff_profileimage"]?.toString() ?? '';
        final staffId = staffInfo["staff_id"]?.toString() ?? '';
        final staffName = staffInfo["staff_name"]?.toString() ?? '';
        if(isLoggedIn){
          await sharedPrefsHelper.clearAll();
          await dbHelper.deleteUser(staffId);
          // Save staff login data and register face
          await sharedPrefsHelper.saveStaffLoginData(staffInfo);
          await registerFace(profileImageUrl, staffId, staffName);

        } else {
          final result = await dbHelper.queryAllRows();
          if(result.isNotEmpty){
            await dbHelper.deleteUser(staffId);
          }
          await sharedPrefsHelper.saveStaffLoginData(staffInfo);
          await registerFace(profileImageUrl, staffId, staffName);
        }


      } else {
        _showMessage(data["message"] ?? "Invalid credentials");
      }
    } catch (e) {
      debugPrint("Response parse error: $e");
      _showMessage("Unexpected server response");
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await initialDB();

    final recognizer = Recognizer();
    detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableContours: true,
        enableClassification: true,
      ),
    );

    faceReg = faceRegistration(
      recognizer: recognizer,
      dbHelper: dbHelper,
      detector: detector,
    );

    _checkAutoLogin();
  }

  Future<void> initialDB() async {
    dbHelper = DatabaseHelper();
    await dbHelper.init();
    print('Database initialized successfully');
  }

  Future<void> _checkAutoLogin() async {
    try {
      final isLoggedIn = await _sharedPrefsHelper.isStaffLoggedIn();
      print('isLoggedIn: $isLoggedIn');
      if (isLoggedIn) {
        final staffData = await _sharedPrefsHelper.getStaffLoginData();
        print('Auto-login with: $staffData');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => Navigation_Class()),
        );
      } else {
        print('No auto-login data found');
      }
    } catch (e) {
      print('Error in auto-login check: $e');
    }
  }

  Future<void> registerFace(String imagePath, String staffId, String staffName) async {
    try {
      final success = await faceReg.loadImageFromUrl(imagePath, staffId, staffName);

      if (success) {
        print('Face registration successful!');
      } else {
        print('Face registration failed - no face detected or other issue');
      }

      // Navigate regardless of face registration success
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => Navigation_Class()),
      );

    } catch (e) {
      print('Error in registerFace: $e');
      // Still navigate even if there's an error
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => Navigation_Class()),
      );
    } finally {
      // Don't dispose here - let the Navigation_Class handle it or dispose in the faceRegistration class itself
      // await faceReg.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Staff Login",
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal),
                  ),
                  const SizedBox(height: 30),

                  TextFormField(
                    controller: staffIdCtrl,
                    decoration: const InputDecoration(
                      labelText: "Staff ID",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) =>
                    v == null || v.isEmpty ? "Enter your Staff ID" : null,
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Password (Staff Number)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (v) =>
                    v == null || v.isEmpty ? "Enter your password" : null,
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: isLoading ? null : login,
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                        "Login",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Dispose resources when the widget is disposed
    try {
       detector.close();
      faceReg.dispose();
      detector.close();
    } catch (e) {
      print('Error disposing face detector: $e');
    }
    super.dispose();
  }
}