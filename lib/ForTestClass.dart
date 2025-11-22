import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_inventory/Staff/StaffPaymentDetailsScreen.dart';
import 'package:restaurant_inventory/admin/SalesDashboardScreen.dart';
import 'package:restaurant_inventory/costing/CostingRecordScreen.dart';
import 'package:restaurant_inventory/sell/CombinedSellManagementScreen.dart';
import '../DashboardScreen.dart';
import '../Food List/combinedAddFoodListManagementScreen.dart';
import '../Food List/menu_item_manager_screen.dart';
import '../Staff/StaffListScreen.dart';
import '../Staff/StaffLoginPage.dart';
import '../attendance/RecognitionScreen.dart';
import '../calCulateCash/CashCalculationScreen.dart';
import '../sharedPref/SharedPrefsHelper.dart';

class Navigation_Class extends StatefulWidget {
  @override
  _Navigation_ClassState createState() => _Navigation_ClassState();
}

class _Navigation_ClassState extends State<Navigation_Class> {
  int _selectedDrawerIndex = 0;
  final SharedPrefsHelper _sharedPrefsHelper = SharedPrefsHelper();
  String _userRole = '';
  String _staffName = '';
  String _staffPosition = '';

  final List<Widget> _pages = [
    CashCalculationScreen(),
    CombinedSellManagementScreen(),
    RecognitionScreen(),
    CostingRecordScreen(),
    StaffListScreen(),
    StaffPaymentDetailsScreen(),
    combinedAddFoodListManagementScreen(),
    SalesDashboardScreen(),
    DashboardScreen(),
    combinedAddFoodListManagementScreen(),
    MenuItemManagerScreen(),
  ];

  final List<String> _pageTitles = [
    "Dashboard",
    'Sell Management',
    'Costing Management',
    'Profile View',
    "Payment Record View",
    'Add Attendance',
    'Attendance View',
    'Staff List',
    'Food List Management',
    'Sales Dashboard'

  ];

  final List<Color> _appBarColors = [
    Color(0x341771).withOpacity(1.0),
    Color(0x341771).withOpacity(1.0),
    Color(0x341771).withOpacity(1.0),
    Color(0x341771).withOpacity(1.0),
    Color(0x341771).withOpacity(1.0),
    Color(0x341771).withOpacity(1.0),
    Color(0x341771).withOpacity(1.0),
    Color(0x341771).withOpacity(1.0),
    Color(0x341771).withOpacity(1.0),
    Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final staffData = await _sharedPrefsHelper.getStaffLoginData();
    setState(() {
      _userRole = staffData['userrole'] ?? '';
      _staffName = staffData['staff_name'] ?? '';
      _staffPosition = staffData['staff_position'] ?? '';
    });
  }

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
                  backgroundImage: AssetImage('assets/freshbite_icon.png'),
                ),
                SizedBox(height: 10),
                Text(
                  'Fresh Bite',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                Text(
                  _staffName.isNotEmpty ? _staffName : 'User',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  _staffPosition.isNotEmpty ? _staffPosition : _userRole,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                SizedBox(height: 5),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRoleColor(_userRole),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _userRole.toUpperCase(),
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.green;
      case 'staff':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // Method to check if user has access to a specific feature
  bool _hasAccess(String requiredRole) {
    if (_userRole.isEmpty) return false;

    // Admin has access to everything
    if (_userRole.toLowerCase() == 'admin') return true;

    // Staff only has access to specific features
    if (_userRole.toLowerCase() == 'staff') {
      // Define what staff can access
      final staffAccessibleFeatures = [
        'dashboard',
        'sell management',
        'costing management',
        // Add other features that staff should have access to
      ];
      return staffAccessibleFeatures.contains(requiredRole.toLowerCase());
    }

    return false;
  }

  // Get drawer items based on user role
  List<Widget> _getDrawerItems() {
    final drawerItems = <Widget>[
      _buildDrawerHeader(context),

      // Dashboard - Accessible to all
      ListTile(
        leading: Icon(Icons.home),
        title: Text('Dashboard'),
        onTap: () => _onSelectItem(0),
      ),

      // Sell Management - Accessible to all
      ListTile(
        leading: Icon(Icons.category),
        title: Text('Sell Management'),
        onTap: () => _onSelectItem(1),
      ),

      // Costing Management - Accessible to all
      ListTile(
        leading: Icon(Icons.person),
        title: Text('Costing Management'),
        onTap: () => _onSelectItem(2),
      ),
    ];

    // Staff Management - Only for Admin
    if (_hasAccess('staff management')) {
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.restaurant_menu),
          title: Text('Staff Management'),
          onTap: () => _onSelectItem(3),
        ),
      );
    }

    // Salary Records - Only for Admin
    if (_hasAccess('salary record')) {
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.calculate_outlined),
          title: Text('Salary Records'),
          onTap: () => _onSelectItem(4),
        ),
      );
    }

    // Food List Management - Only for Admin
    if (_hasAccess('food list management')) {
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.person_add),
          title: Text('Add Food List'),
          onTap: () => _onSelectItem(5),
        ),
      );
    }

    // Staff Payment - Only for Admin
    if (_hasAccess('staff payment')) {
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.payment),
          title: Text('Staff Payment'),
          onTap: () => _onSelectItem(6),
        ),
      );
    }

    // Sales Dashboard - Only for Admin
    if (_hasAccess('sales dashboard')) {
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.dashboard),
          title: Text('Sales Dashboard'),
          onTap: () => _onSelectItem(7),
        ),
      );
    }

    // Add logout button at the end
    drawerItems.addAll([
      Divider(),
      ListTile(
        leading: Icon(Icons.logout, color: Colors.red),
        title: Text('Logout', style: TextStyle(color: Colors.red)),
        onTap: _logout,
      ),
    ]);

    return drawerItems;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _selectedDrawerIndex < _appBarColors.length
            ? _appBarColors[_selectedDrawerIndex]
            : Colors.grey,
        elevation: 0,
        title: Text(
          _pageTitles[_selectedDrawerIndex],
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        leading: _selectedDrawerIndex != 0
            ? IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            setState(() {
              _selectedDrawerIndex = 0;
            });
          },
        )
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        actions: [
          // Show user role in app bar
          if (_userRole.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  _userRole.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      drawer: _selectedDrawerIndex == 0
          ? Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: _getDrawerItems(),
        ),
      )
          : null,
      body: _pages[_selectedDrawerIndex],
    );
  }

  Future<void> _logout() async {
    await _sharedPrefsHelper.removeStaffLoginData();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => StaffLoginPage()),
    );
  }
}