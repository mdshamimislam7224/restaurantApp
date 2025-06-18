import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_inventory/Food%20List/CategoryManagerScreen.dart';

import '../Food List/CombinedManagementScreen.dart';
import '../Food List/menu_item_manager_screen.dart';


class Navigation_Class extends StatefulWidget {
  @override
  _Navigation_ClassState createState() => _Navigation_ClassState();
}

class _Navigation_ClassState extends State<Navigation_Class> {
  int _selectedDrawerIndex = 0;

  final List<Widget> _pages = [
    MenuItemManagerScreen(),
    CombinedManagementScreen(),
    CategoryManagerScreen(),
  ];
  final List<String> _pageTitles = [
    'Dashboard',
    'Food Management List',
    "Add Food Menu Item",
    'Add Costing',
    'Add Employee',
    'Staff Payment',
    "Show All Costing",
    "Cash Calculate",
    'Calculate Owner Account'

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
              title: Text('Add New Item'),
              onTap: () => _onSelectItem(1),
            ),
            ListTile(
              leading: Icon(Icons.restaurant_menu),
              title: Text('Add Food Menu Item',),
              onTap: () => _onSelectItem(2),
            ),
            ListTile(
              leading: Icon(Icons.money),
              title: Text('Add Costing Record'),
              onTap: () => _onSelectItem(3),
            ),
            ListTile(
              leading: Icon(Icons.calculate_outlined),
              title: Text('View All Costing'),
              onTap: () => _onSelectItem(6),
            ),
            ListTile(
              leading: Icon(Icons.person_add),
              title: Text('Add Employee'),
              onTap: () => _onSelectItem(4),
            ),
            ListTile(
              leading: Icon(Icons.payments),
              title: Text('Staff Payment'),
              onTap: () => _onSelectItem(5),
            ),

            ListTile(
              leading: Icon(Icons.dataset),
              title: Text('Calculate Cash'),
              onTap: () => _onSelectItem(7),
            ),
            ListTile(
              leading: Icon(Icons.calculate_outlined),
              title: Text('Calculate Onwer Cash'),
              onTap: () => _onSelectItem(8),
            ),
          ],
        ),
      )
          : null,
      body: _pages[_selectedDrawerIndex],
    );
  }





}
