// salary_record_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../alertDialog/customDialog.dart';
import '../api/apiClass.dart';
import '../localDB/DBHelper.dart';
import '../showToast/Toast_Message.dart';
import 'Salary.dart';
class SalaryRecordScreen extends StatefulWidget {
  const SalaryRecordScreen({Key? key}) : super(key: key);

  @override
  State<SalaryRecordScreen> createState() => _SalaryRecordScreenState();
}

class _SalaryRecordScreenState extends State<SalaryRecordScreen> {
  List<Salary> salaryList = [];
  List<Map<String, dynamic>> staffBasicList = [];
  bool isLoading = true;
  Toast_Message toast = Toast_Message();
  String? selectedStaffId;

  @override
  void initState() {
    super.initState();
    loadStaff();
    fetchBasicSalary();
    fetchSalaryData();
  }

  Future<void> fetchBasicSalary() async {
    setState(() => isLoading = true);
    final res = await http.get(Uri.parse("${apiClass.baseUrlStaff}?action=getStaffListBasic"));
    print('Status Code: ${res.statusCode}');
    print('Response Basic Salary: ${res.body}');
    if (res.statusCode == 200) {
      final List<dynamic> staffList = jsonDecode(res.body);
      final dbClient = await DBHelper.db;
      // Clear existing data
      if (staffBasicList.isEmpty) {
        await dbClient.delete('staff_basic_cache');
        final batch = dbClient.batch();
        for (var staff in staffList) {
          batch.insert(
            'staff_basic_cache',
            {
              'staff_id': staff['staff_id'],
              'name': staff['name'],
              'salary': staff['salary'].toString(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }

      setState(() => isLoading = false);
      print("✅ Staff synced to local cache.");
    } else {
      print("❌ API Error: ${res.statusCode}");
    }
    }
  Future<void> loadStaff() async {
    final staff = await DBHelper.getAllCachedStaff();
    setState(() {
      staffBasicList = staff;
      print("✅ synced to local cache. $staffBasicList");
    });
  }
  Future<void> fetchSalaryData() async {
    setState(() => isLoading = true);
    final res = await http.get(Uri.parse("${apiClass.baseUrlStaff}?action=getSalaryRecord"));
    print('Status Code: ${res.statusCode}');
    print('Response Body: ${res.body}');
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      setState(() {
        salaryList = data.map((e) => Salary.fromJson(e)).toList();
      });
    }
    setState(() => isLoading = false);
  }

  Future<void> addSalary(Map<String, dynamic> salary) async {
    final dialog = customDialog(context);
    dialog.showLoading("Adding Salary...", subtitle: "Please wait");
    final client = http.Client();
    try{
      http.Response response = await client.post(
        Uri.parse('${apiClass.baseUrlStaff}?action=addSalaryRecord'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(salary),
      ).timeout(const Duration(seconds: 300));
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

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          dialog.dismiss(); // Dismiss loading dialog
          Navigator.pop(context);
          toast.showToast("Staff Added Successfully", Colors.green, Colors.white);
          await fetchSalaryData(); // This will show its own loading dialog
        } else {
          print('Error: ${responseData['message']}');
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
        customDialog(context).showError("Error", "Failed to add staff. Please try again.");
      }
    } on TimeoutException catch (e) {
      dialog.dismiss(); // Dismiss loading on timeout
      print('Request timed out: $e');
      customDialog(context).showError("Network Timeout",
          'The request took too long to complete. Please try again.');
      print("Request timed out: $e");
    }
    catch (e) {
      print('Error: $e');
    }finally{
      client.close();
    }
  }

  Future<void> updateSalary(Map<String, dynamic> salaryData) async {
    final dialog = customDialog(context);
    dialog.showLoading("Updating Salary...", subtitle: "Please wait");
    final client = http.Client();
    try {
      // Ensure consistent data format
      final payload = {
        'date': DateFormat('yyyy-MM-dd').format(DateTime.parse(salaryData['date'])),
        'employeeId': salaryData['employeeId'].toString().trim(),
        'employeeName': salaryData['employeeName'].toString(),
        'basicSalary': salaryData['basicSalary'],
        'advancePaid': salaryData['advancePaid'],
        'paidNow': salaryData['paidNow'],
        'totalPaid': salaryData['totalPaid'],
        'remaining': salaryData['remaining'],
        'note': salaryData['note'] ?? '',
      };

      print('Sending payload: $payload');

      var response = await client.post(
        Uri.parse('${apiClass.baseUrlStaff}?action=updateSalaryRecord'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 30));

      // Handle redirect if needed
      if (response.statusCode == 302 || response.statusCode == 303) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          response = await client.get(
            Uri.parse(redirectUrl),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      final responseData = json.decode(response.body);
      print('Server response: $responseData');

      if (response.statusCode == 200) {
        if (responseData['status'] == 'success') {
          dialog.dismiss();
          Navigator.pop(context);
          toast.showToast("Salary Updated Successfully", Colors.green, Colors.white);
          await fetchSalaryData();
        } else {
          dialog.dismiss();
          customDialog(context).showError("Error", responseData['message']);
        }
      } else {
        dialog.dismiss();
        customDialog(context).showError("Error", "Failed to update salary. ${response.statusCode}.");
      }
    } on TimeoutException {
      dialog.dismiss();
      customDialog(context).showError("Network Timeout", 'The request took too long to complete. Please try again.');
    } catch (e) {
      print('Update error: $e');
      dialog.dismiss();
      customDialog(context).showError("Error", "Failed to update salary. Please try again.");
    } finally {
      client.close();
    }
  }

  Future<void> deleteSalary(String date, String employeeId) async {
    final dialog = customDialog(context);
    final client = http.Client();
    dialog.showLoading("Deleting...", subtitle: "Please wait");
    try {
      final payload = {
        'date': date, // Should be in 'yyyy-MM-dd' format
        'employeeId': employeeId,
      };

      var response = await client.post(
        Uri.parse('${apiClass.baseUrlStaff}?action=deleteSalaryRecord'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 30));

      // Handle redirect if needed
      if (response.statusCode == 302 || response.statusCode == 303) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          response = await client.get(
            Uri.parse(redirectUrl),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      final responseData = json.decode(response.body);
      print('Delete Response Status: ${response.statusCode}');
      print('Delete Response: $responseData');
      if (response.statusCode == 200) {
        if (responseData['status'] == 'success') {
          dialog.dismiss(); // Dismiss loading dialog
          toast.showToast(responseData['message'], Colors.green, Colors.white);
          await fetchSalaryData(); // Refresh the data
        } else {
          dialog.dismiss();
          customDialog(context).showError("Error", responseData['message']);
        }
      } else {
        print('Delete Response Status: ${response.statusCode}');
        dialog.dismiss();
        customDialog(context).showError("Server error", "${response.statusCode}");
      }
    } on TimeoutException {
      print("Request timed out");
      dialog.dismiss();
      customDialog(context).showError("Network Timeout", "The request took too long to complete. Please try again.");
    } catch (e) {
      print('Delete error: $e');
    dialog.dismiss();
      customDialog(context).showError("Error", e.toString());
    } finally {
      client.close();
    }
  }

  void showAddEditDialog({Salary? record}) {
    final isUpdate = record != null;
    final formKey = GlobalKey<FormState>(); // Add form key for validation

    // Initialize controllers
    TextEditingController name = TextEditingController();
    final TextEditingController id = TextEditingController();
    final TextEditingController date = TextEditingController(
        text: record?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()));
    TextEditingController salary = TextEditingController();
    final TextEditingController advance = TextEditingController(
        text: record?.advance.toString() ?? '0');
    final TextEditingController paidNow = TextEditingController(
        text: record?.paidNow.toString() ?? '0');
    final TextEditingController notes = TextEditingController(
        text: record?.notes);
    // Set initial values if updating
    if (isUpdate) {
      name.text = record.name;
      id.text = record.employeeId;
      salary.text = record.basicSalary.toString();
      selectedStaffId = record.employeeId;
    } else {
      selectedStaffId = null;
    }
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Form(
          key: formKey, // Add Form widget
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUpdate ? "Update Salary Record" : "Add Salary Record",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Staff ID Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedStaffId,
                    decoration: InputDecoration(
                      labelText: 'Staff ID *',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    validator: (value) => value == null ? 'Please select Staff ID' : null,
                    items: isUpdate
                        ? [
                      DropdownMenuItem<String>(
                        value: record.employeeId,
                        child: Text(record.employeeId),
                      )
                    ]
                        : staffBasicList.map((staff) {
                      return DropdownMenuItem<String>(
                        value: staff['staff_id'],
                        child: Text(staff['staff_id']),
                      );
                    }).toList(),
                    onChanged: isUpdate
                        ? null
                        : (value) {
                      setState(() {
                        selectedStaffId = value;
                        final selected = staffBasicList.firstWhere(
                              (s) => s['staff_id'] == value,
                          orElse: () => {},
                        );
                        id.text = selected['staff_id'] ?? '';
                        name.text = selected['name'] ?? '';
                        salary.text = selected['salary']?.toString() ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Date Picker
                  TextFormField(
                    controller: date,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "Date *",
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Please select date' : null,
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        date.text = DateFormat('yyyy-MM-dd').format(picked.toLocal());
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Name Field
                  TextFormField(
                    controller: name,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "Name *",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Name is required' : null,
                  ),
                  SizedBox(height: 12),

                  // Basic Salary Field
                  TextFormField(
                    controller: salary,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "Basic Salary *",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Basic salary is required';
                      if (int.tryParse(value!) == null) return 'Enter valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Advance Salary Field
                  TextFormField(
                    controller: advance,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Advance Salary *",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Advance is required';
                      if (int.tryParse(value!) == null) return 'Enter valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Paid Now Field
                  TextFormField(
                    controller: paidNow,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Paid Now *",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Paid amount is required';
                      if (int.tryParse(value!) == null) return 'Enter valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Notes Field
                  TextFormField(
                    controller: notes,
                    decoration: InputDecoration(
                      labelText: "Notes",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Cancel",
                            style: TextStyle(color: Colors.grey[700])),
                      ),
                      ElevatedButton.icon(
                        icon: Icon(isUpdate ? Icons.update : Icons.add),
                        label: Text(isUpdate ? "Update" : "Add"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            final int basic = int.tryParse(salary.text) ?? 0;
                            final int adv = int.tryParse(advance.text) ?? 0;
                            final int paid = int.tryParse(paidNow.text) ?? 0;
                            final int total = adv + paid;
                            final int remain = basic - total;

                            Map<String, dynamic> data = {
                              "date": date.text,
                              "employeeId": id.text,
                              "employeeName": name.text,
                              "basicSalary": salary.text,
                              "advancePaid": advance.text,
                              "paidNow": paidNow.text,
                              "totalPaid": total.toString(),
                              "remaining": remain.toString(),
                              "note": notes.text,
                            };

                            isUpdate ? updateSalary(data) : addSalary(data);
                          }
                        },
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _numberInputField({required String label, required TextEditingController controller}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Salary Records")),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: fetchSalaryData,
        child: ListView.builder(
          itemCount: salaryList.length,
          itemBuilder: (_, i) {
            final s = salaryList[i];
            return Dismissible(
              key: ValueKey("${s.employeeId}-${s.date}"),
              background: Container(color: Colors.red, alignment: Alignment.centerLeft, padding: EdgeInsets.only(left: 20), child: Icon(Icons.delete, color: Colors.white)),
              secondaryBackground: Container(color: Colors.blue, alignment: Alignment.centerRight, padding: EdgeInsets.only(right: 20), child: Icon(Icons.edit, color: Colors.white)),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.endToStart) {
                  showAddEditDialog(record: s);
                  return false;
                }
                else {
                  bool confirmed = await showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text("Confirm Delete"),
                      content: Text("Are you sure you want to delete this record?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: Text("Delete"),
                        ),
                      ],
                    ),
                  );
                  if (confirmed) {
                    await deleteSalary(s.date, s.employeeId);
                    return true;
                  }
                  return false;
                }
              },
              child: Card(
                margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.all(16),
                  title: Text(s.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 4),
                      Text("Month: ${_formatMonthYear(s.date)}"),
                      Text("Paid: ${s.totalPaid} | Remain: ${s.remaining}"),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.black),
                      SizedBox(height: 4),
                      Text(s.date, style: TextStyle(fontSize: 12, color: Colors.black)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddEditDialog(),
        child: Icon(Icons.add),
      ),
    );
  }
  String _formatMonthYear(String rawDate) {
    try {
      final date = DateTime.parse(rawDate);
      return DateFormat('MMMM yyyy').format(date); // Example: July 2025
    } catch (e) {
      return rawDate; // fallback if parsing fails
    }
  }

}
