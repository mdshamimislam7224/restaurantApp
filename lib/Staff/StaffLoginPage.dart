import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:restaurant_inventory/Navigation/Navigation_Class.dart';
import 'package:restaurant_inventory/Staff/StaffProfileView.dart';
// import your StaffProfileScreen
class StaffLoginPage extends StatefulWidget {
  const StaffLoginPage({Key? key}) : super(key: key);

  @override
  State<StaffLoginPage> createState() => _StaffLoginPageState();
}

class _StaffLoginPageState extends State<StaffLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController staffIdCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  bool isLoading = false;

  // --- Replace with your deployed Apps Script URL ---
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

      // Handle redirect (Google sometimes returns 302)
      print("Response Status: ${response.statusCode}");

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

        // ✅ Navigate to Profile Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => Navigation_Class(),
          ),
        );
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

                  // --- Staff ID ---
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

                  // --- Password ---
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

                  // --- Login Button ---
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
                        style:
                        TextStyle(fontSize: 18, color: Colors.white),
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
}
