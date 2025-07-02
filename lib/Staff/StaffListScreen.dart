import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'Staff.dart';

class StaffListScreen extends StatefulWidget {
  @override
  _StaffListScreenState createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  List<Staff> staffList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchStaffData();
  }

  Future<void> fetchStaffData() async {
    try {
      final response = await http.get(
        Uri.parse('https://script.google.com/macros/s/AKfycbwHykTRYYb1cZnw1JUiUAlooa8bmn_d13pOywCjhA2UUk9eDMzwa4ilbNPzidLcuYQ3/exec?action=getStaff'),
      );
      print('Status Code: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          staffList = (data as List).map((item) => Staff.fromJson(item)).toList();
          isLoading = false;
        });
      }
    } catch (error) {
      print('Error fetching data: $error');
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: $error')),
      );
    }
  }

  Future<void> deleteStaff(String staffId) async {
    try {
      final response = await http.post(
        Uri.parse('https://script.google.com/macros/s/AKfycbwHykTRYYb1cZnw1JUiUAlooa8bmn_d13pOywCjhA2UUk9eDMzwa4ilbNPzidLcuYQ3/exec?action=deleteStaff'),
        body: json.encode({'staffId': staffId}),
      );

      if (response.statusCode == 200) {
        setState(() {
          staffList.removeWhere((staff) => staff.id == staffId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Staff deleted successfully')),
        );
      }
    } catch (error) {
      print('Error deleting staff: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting staff: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Staff List'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : staffList.isEmpty
          ? Center(child: Text('No staff members found'))
          : RefreshIndicator(
        onRefresh: fetchStaffData,
        child: ListView.builder(
          itemCount: staffList.length,
          itemBuilder: (context, index) {
            final staff = staffList[index];
            return _buildStaffItem(staff);
          },
        ),
      ),
    );
  }

  Widget _buildStaffItem(Staff staff) {
    return Dismissible(
      key: Key(staff.id),
      background: _buildSwipeBackground(Colors.red, Icons.delete, Alignment.centerLeft),
      secondaryBackground: _buildSwipeBackground(Colors.blue, Icons.edit, Alignment.centerRight),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Swipe right to left (edit)
          _showEditDialog(staff);
          return false; // Don't dismiss for edit
        } else {
          // Swipe left to right (delete)
          return await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Delete Staff'),
              content: Text('Are you sure you want to delete ${staff.name}?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          deleteStaff(staff.id);
        }
      },
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundImage: staff.profileImage.isNotEmpty
                ? NetworkImage(staff.profileImage)
                : AssetImage('assets/default_profile.png') as ImageProvider,
          ),
          title: Text(staff.name),
          subtitle: Text('${staff.position} - ${staff.phone}'),
          trailing: Text('\$${staff.salary}'),
        ),
      ),
    );
  }

  Widget _buildSwipeBackground(Color color, IconData icon, Alignment alignment) {
    return Container(
      color: color,
      alignment: alignment,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Icon(icon, color: Colors.white),
    );
  }

  void _showEditDialog(Staff staff) {
    // Implement your edit dialog here
    // You can reuse your existing form with pre-filled values
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Staff'),
        content: SingleChildScrollView(
          child: Column(
            children: [
            TextFormField(
            initialValue: staff.name,
            decoration: InputDecoration(labelText: 'Name'),
            // Add other fields similarly
            )
            ]),
          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Implement update logic
              Navigator.of(context).pop();
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }
}