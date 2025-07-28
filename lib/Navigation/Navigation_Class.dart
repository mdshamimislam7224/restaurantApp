import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_inventory/Food%20List/CategoryManagerScreen.dart';
import 'package:restaurant_inventory/Staff/SalaryRecordScreen.dart';
import 'package:restaurant_inventory/Staff/StaffScreen.dart';
import 'package:restaurant_inventory/costing/CostingRecordScreen.dart';
import 'package:restaurant_inventory/sell/CombinedSellManagementScreen.dart';
import 'package:restaurant_inventory/sell/SellRecordScreen.dart';
import 'package:restaurant_inventory/sell/SellScreen.dart';

import '../DashboardScreen.dart';
import '../Food List/combinedAddFoodListManagementScreen.dart';
import '../Food List/menu_item_manager_screen.dart';
import '../Staff/StaffListScreen.dart';


class Navigation_Class extends StatefulWidget {
  @override
  _Navigation_ClassState createState() => _Navigation_ClassState();
}

class _Navigation_ClassState extends State<Navigation_Class> {
  int _selectedDrawerIndex = 0;

  final List<Widget> _pages = [
    DashboardScreen(),
    CombinedSellManagementScreen(),
    CostingRecordScreen(),
    StaffListScreen(),
    SalaryRecordScreen(),
    combinedAddFoodListManagementScreen(),
    MenuItemManagerScreen(),
    SellRecordScreen(),
  ];
  final List<String> _pageTitles = [
    "Dashboard",
    'Sell Management',
    'Costing Management',
    "Staff Management",
    "Salary Record",
    'Food List Management',
    'Add Employee',
    'Staff Payment',
    "Show All Costing",
    "Cash Calculate",
    'Load Data From Online Database',

  ];

  final List<Color> _appBarColors = [
    Colors.blue,
    Color(0xFFFFFFFF),
    Color(0xFF1C1C2B),
    Colors.teal,


  ];

  void _onSelectItem(int index) {
    setState(() {
      _selectedDrawerIndex = index;
    });

    Navigator.pop(context);
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return DrawerHeader(
      decoration: BoxDecoration(color: Colors.blue),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                //Navigator.push(context, MaterialPageRoute(builder: (context) => DashBoard_DetailsBoticeBoard(notices: notices),),);
              },
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: AssetImage('assets/images/appicon.png'),
                ),
                SizedBox(height: 10),
                Text(
                  'Fresh Bite',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                Text(
                  'teamfreshbite@gmail.com',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _selectedDrawerIndex < _appBarColors.length
            ? _appBarColors[_selectedDrawerIndex]
            : Colors.grey, // Fallback color
        elevation: 0,
        title: Text(
          _pageTitles[_selectedDrawerIndex],
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,color:Colors.black),
        ),
        centerTitle: true,
        leading: _selectedDrawerIndex != 0
            ? IconButton(
          icon: Icon(Icons.arrow_back,color: Colors.black,),
          onPressed: () {
            setState(() {
              _selectedDrawerIndex = 0;
            });
          },
        )
            : null,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(
            color: Colors.grey.shade300,
            thickness: 1.0,
          ),
        ),
      ),
      drawer: _selectedDrawerIndex == 0
          ? Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildDrawerHeader(context),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Dashboard'),
              onTap: () => _onSelectItem(0),
            ),

            ListTile(
              leading: Icon(Icons.category),
              title: Text('Sell Management'),
              onTap: () => _onSelectItem(1),
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Costing Management',),
              onTap: () => _onSelectItem(2),
            ),
            ListTile(
              leading: Icon(Icons.restaurant_menu),
              title: Text('Staff Management'),
              onTap: () => _onSelectItem(3),
            ),
            ListTile(
              leading: Icon(Icons.calculate_outlined),
              title: Text('Salary Records'),
              onTap: () => _onSelectItem(4),
            ),
            ListTile(
              leading: Icon(Icons.person_add),
              title: Text('Add Food List'),
              onTap: () => _onSelectItem(5),
            ),

          ],
        ),
      )
          : null,
      body: _pages[_selectedDrawerIndex],
    );
  }





}
