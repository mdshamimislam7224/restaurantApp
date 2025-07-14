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
          toast.showToast("Staff Added Successfully", Colors.green, Colors.white);
          Navigator.of(context).pop(); // Close the form dialog
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Server error: ${response.statusCode}")),
        );
      }
    } on TimeoutException catch (e) {
      dialog.dismiss(); // Dismiss loading on timeout
      print('Request timed out: $e');
      dialog.showError("Network Timeout",
          'The request took too long to complete. Please try again.');
      print("Request timed out: $e");
    }
    catch (e) {
      print('Error: $e');
    }finally{
      client.close();
    }


  }

  Future<void> updateSalary(Map<String, dynamic> salary) async {
    final client = http.Client();
    print(salary);
    try {
      var response = await client.post(
        Uri.parse('${apiClass.baseUrlStaff}?action=updateSalaryRecord'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(salary),
      ).timeout(const Duration(seconds: 50));

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

      // Check HTTP status code first (200 = success)
      print('Response Status Code: ${response.statusCode}');
      print('Raw Response Body: ${response.body}');
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message'])),
          );
          await fetchSalaryData(); // Refresh data
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed: ${responseData['message']}")),
          );
        }
      }
      // Handle non-200 status codes (e.g., 404, 500)
      else {
        print('Request failed with status: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Server error: ${response.statusCode}")),
        );
      }
    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Request timed out")),
      );
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      client.close();
    }
  }

  Future<void> deleteSalary(String employeeId, String date) async {
    final client = http.Client();
    try {
      final response = await client.post(
        Uri.parse('${apiClass.baseUrlStaff}?action=deleteSalaryRecord'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'employeeId': employeeId,
          'date': date,
        }),
      ).timeout(const Duration(seconds: 10));

      final responseData = json.decode(response.body);
      if (responseData['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'])),
        );
        await fetchSalaryData(); // Refresh data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'])),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      client.close();
    }
  }

  void showAddEditDialog({Salary? record}) {
    final isUpdate = record != null;
    print('isUpdate: $isUpdate');
    TextEditingController name = TextEditingController(text: record?.name);
    final TextEditingController id = TextEditingController(text: record?.employeeId);
    final TextEditingController date = TextEditingController(text: record?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()));
    TextEditingController salary = TextEditingController(text: record?.basicSalary.toString());
    final TextEditingController advance = TextEditingController(text: record?.advance.toString() ?? '0');
    final TextEditingController paidNow = TextEditingController(text: record?.paidNow.toString() ?? '0');
    final TextEditingController notes = TextEditingController(text: record?.notes);
    print('record: $record');
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                DropdownButtonFormField<String>(
                  value: selectedStaffId,
                  decoration: InputDecoration(
                    labelText: 'Select Staff ID',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: staffBasicList.map((staff) {
                    return DropdownMenuItem<String>(
                      value: staff['staff_id'],
                      child: Text(staff['staff_id']),
                    );
                  }).toList(),
                  onChanged: (value) {
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
                TextField(
                  controller: date,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: "Date",
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );

                    if (picked != null) {
                      // Convert to local time and format
                      DateTime localPicked = picked.toLocal();
                      date.text = DateFormat('yyyy-MM-dd').format(localPicked);
                    }
                  },
                ),
                const SizedBox(height: 12),
              TextField(controller: name, readOnly: true, decoration: InputDecoration(labelText: "Name", border: OutlineInputBorder(),),),
                SizedBox(height: 12,),
                TextField(controller: salary, readOnly: true, decoration: InputDecoration(labelText: "Basic Salary", border: OutlineInputBorder(),),),
                const SizedBox(height: 12),
                _numberInputField(label: 'Advance Salary', controller: advance),
                const SizedBox(height: 12),
                _numberInputField(label: 'Paid Salary', controller: paidNow),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  decoration: InputDecoration(
                    labelText: "Notes",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel", style: TextStyle(color: Colors.grey[700])),
                    ),
                    ElevatedButton.icon(
                      icon: Icon(isUpdate ? Icons.update : Icons.add),
                      label: Text(isUpdate ? "Update" : "Add"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
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
                        Navigator.pop(context);
                      },
                    )
                  ],
                )
              ],
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

  // void showAddEditDialog({Salary? record}) {
  //   final isUpdate = record != null;
  //   TextEditingController name = TextEditingController(text: record?.name);
  //   final TextEditingController id = TextEditingController(text: record?.employeeId);
  //   final TextEditingController date = TextEditingController(text: record?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()));
  //   TextEditingController salary = TextEditingController(text: record?.basicSalary.toString());
  //   final TextEditingController advance = TextEditingController(text: record?.advance.toString() ?? '0');
  //   final TextEditingController paidNow = TextEditingController(text: record?.paidNow.toString() ?? '0');
  //   final TextEditingController notes = TextEditingController(text: record?.notes);
  //
  //   showDialog(
  //     barrierDismissible: false,
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       title: Text(isUpdate ? "Update Salary" : "Add Salary"),
  //       content: SingleChildScrollView(
  //         child: Column(
  //           children: [
  //             TextField(controller: id, decoration: InputDecoration(labelText: "Employee ID"), readOnly: isUpdate),
  //             DropdownButtonFormField<String>(
  //               value: selectedStaffId,
  //               decoration: InputDecoration(labelText: 'Select Staff ID'),
  //               items: staffBasicList.map((staff) {
  //                 return DropdownMenuItem<String>(
  //                   value: staff['staff_id'],
  //                   child: Text(staff['staff_id']),
  //                 );
  //               }).toList(),
  //               onChanged: (value) {
  //                 setState(() {
  //                   selectedStaffId = value;
  //                   final selected = staffBasicList.firstWhere(
  //                         (s) => s['staff_id'] == value,
  //                     orElse: () => {},
  //                   );
  //                   name.text = selected['name'] ?? '';
  //                   salary.text = selected['salary']?.toString() ?? '';
  //                 });
  //               },
  //
  //             ),
  //             TextField(controller: name, decoration: InputDecoration(labelText: "Name"), readOnly: true),
  //             TextField(controller: date, decoration: InputDecoration(labelText: "Date"), readOnly: true,
  //               onTap: () async {
  //                 DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
  //                 if (picked != null) date.text = DateFormat('yyyy-MM-dd').format(picked);
  //               },
  //             ),
  //             TextField(controller: salary, decoration: InputDecoration(labelText: "Basic Salary"), keyboardType: TextInputType.number,readOnly: true),
  //             TextField(controller: advance, decoration: InputDecoration(labelText: "Advance"), keyboardType: TextInputType.number),
  //             TextField(controller: paidNow, decoration: InputDecoration(labelText: "Paid Now"), keyboardType: TextInputType.number),
  //             TextField(controller: notes, decoration: InputDecoration(labelText: "Notes")),
  //           ],
  //         ),
  //       ),
  //       actions: [
  //         TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
  //         ElevatedButton(
  //           onPressed: () {
  //             final int basic = int.tryParse(salary.text) ?? 0;
  //             final int adv = int.tryParse(advance.text) ?? 0;
  //             final int paid = int.tryParse(paidNow.text) ?? 0;
  //             final int total = adv + paid;
  //             final int remain = basic - total;
  //             Map<String, dynamic> data = {
  //               "date": date.text,
  //               "employeeId": id.text,
  //               "employeeName": name.text,
  //               "basicSalary": salary.text,
  //               "advancePaid": advance.text,
  //               "paidNow": paidNow.text,
  //               "totalPaid": total.toString(),
  //               "remaining": remain.toString(),
  //               "note": notes.text,
  //             };
  //
  //
  //             final newSalary = Salary(
  //               date: date.text,
  //               employeeId: id.text,
  //               name: name.text,
  //               month: "month.text",
  //               basicSalary: basic,
  //               advance: adv,
  //               paidNow: paid,
  //               totalPaid: total,
  //               remaining: remain,
  //               notes: notes.text,
  //             );
  //             isUpdate ? updateSalary(newSalary) : addSalary(data);
  //           },
  //           child: Text(isUpdate ? "Update" : "Add"),
  //         )
  //       ],
  //     ),
  //   );
  // }

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
                } else {
                  await deleteSalary(s.employeeId, s.date);
                  return true;
                }
              },
              child: ListTile(
                title: Text(s.name),
                subtitle: Text("Month: ${s.month} | Paid: ${s.totalPaid} | Remain: ${s.remaining}"),
                trailing: Text(s.date),
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
}
