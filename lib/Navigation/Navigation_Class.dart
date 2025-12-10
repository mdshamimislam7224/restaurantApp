import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../Food List/combinedAddFoodListManagementScreen.dart';
import '../Staff/StaffListScreen.dart';
import '../Staff/StaffLoginPage.dart';
import '../Staff/StaffPaymentDetailsScreen.dart';
import '../Staff/StaffProfileScreen.dart';
import '../Staff/StaffSinglePaymentDetailsScreen.dart';
import '../admin/SalesDashboardScreen.dart';
import '../attendance/RecognitionScreen.dart';
import '../attendance/ui/HomeScreen.dart';
import '../calCulateCash/CashCalculationScreen.dart';
import '../costing/CostingRecordScreen.dart';
import '../localDB/DatabaseHelper.dart';
import '../sell/CombinedSellManagementScreen.dart';
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
  String _staffStatus = '';
  String _staffPosition = '';
  String staffId = '';
  String _staffJoningDate = '';
  List<Widget>? _pages;
  bool _isLoading = true;

  Future<void> _loadUserData() async {
    final staffData = await _sharedPrefsHelper.getStaffLoginData();
    setState(() {
      _userRole = staffData['userrole'] ?? '';
      _staffName = staffData['staff_name'] ?? '';
      _staffPosition = staffData['staff_position'] ?? '';
      staffId = staffData['staff_id'] ?? '';
      _staffStatus = staffData['status'] ?? '';
      _staffJoningDate = staffData['joiningdate'] ?? '';
      _isLoading = false;
    });

    setState(() {
      _pages = [
        CashCalculationScreen(),
        CombinedSellManagementScreen(),
        CostingRecordScreen(),
        StaffProfileScreen(staffId: staffId),
        StaffSinglePaymentDetailsScreen(
          staffId: staffId,
          staffJoiningDate: _staffJoningDate,
        ),
        RecognitionScreen(),
        StaffPaymentDetailsScreen(),
        StaffListScreen(),
        combinedAddFoodListManagementScreen(),
        SalesDashboardScreen(),
        HomeScreen(
          staffId: staffId, // Replace with actual staff ID
          staffName: _staffName, // Replace with actual name
        )
      ];
    });
  }

  // UPDATE: Add 11 titles to match 11 pages
  final List<String> _pageTitles = [
    "Dashboard",
    'Sell Management',
    'Costing Management',
    'Profile View',
    "Payment View",
    'Attendance',
    'Staff Payment View',
    'Staff List',
    'Food List Management',
    'Sales Dashboard',
    "Attendance Management", // Added this 11th title
  ];

  // UPDATE: Add 11 colors to match 11 pages
  final List<Color> _appBarColors = [
    Colors.blue,
    Colors.blue,
    Colors.blue,
    Colors.blue,
    Colors.blue,
    Colors.blue,
    Colors.blue,
    Colors.blue,
    Colors.blue,
    Colors.blue,
    Colors.blue, // Added this 11th color
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
              onPressed: () => Navigator.pop(context),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _staffName.isNotEmpty ? _staffName : 'User',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _staffPosition.isNotEmpty ? "($_staffStatus)" : _staffStatus,
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
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

  bool _hasAccess(String requiredRole) {
    if (_userRole.isEmpty) return false;

    // Convert both to lowercase for consistent comparison
    String userRoleLower = _userRole.toLowerCase();
    String requiredRoleLower = requiredRole.toLowerCase();

    // Admin has access to most features but NOT to Profile View and Payment View
    if (userRoleLower == 'admin') {
      final adminHiddenFeatures = [
        'payment view',
      ];
      return !adminHiddenFeatures.contains(requiredRoleLower);
    }

    // Staff only has access to specific features
    if (userRoleLower == 'staff') {
      final staffAccessibleFeatures = [
        "dashboard",
        'sell management',
        'costing management',
        'profile view',
        "payment view",
        'attendance',
      ];
      return staffAccessibleFeatures.contains(requiredRoleLower);
    }

    return false;
  }

  List<Widget> _getDrawerItems() {
    final drawerItems = <Widget>[
      _buildDrawerHeader(context),
    ];

    print('Building drawer for user: $_userRole');

    // Check each menu item
    if (_hasAccess('Dashboard')) {
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.dashboard),
          title: Text('Dashboard'),
          onTap: () => _onSelectItem(0),
        ),
      );
    }

    if (_hasAccess('Sell Management')) {
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.shopping_cart),
          title: Text('Sell Management'),
          onTap: () => _onSelectItem(1),
        ),
      );
    }

    if (_hasAccess('Costing Management')) {
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.calculate),
          title: Text('Costing Management'),
          onTap: () => _onSelectItem(2),
        ),
      );
    }

    if (_hasAccess('Profile View')) {
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.person),
          title: Text('Profile View'),
          onTap: () => _onSelectItem(3),
        ),
      );
    }

    if (_hasAccess('Payment View')) {
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.payment),
          title: Text('Payment View'),
          onTap: () => _onSelectItem(4),
        ),
      );
    }

    if (_hasAccess('Attendance')) {
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.access_time),
          title: Text('Attendance'),
          onTap: () => _onSelectItem(5),
        ),
      );
    }

    // Admin-only features
    if (_hasAccess('Staff Payment View')) {
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.payment),
          title: Text('Staff Payment View'),
          onTap: () => _onSelectItem(6),
        ),
      );
    }

    if (_hasAccess('Staff List')) {
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.people),
          title: Text('Staff List'),
          onTap: () => _onSelectItem(7),
        ),
      );
    }

    if (_hasAccess('Food List Management')) {
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.restaurant_menu),
          title: Text('Food List Management'),
          onTap: () => _onSelectItem(8),
        ),
      );
    }

    if (_hasAccess('Sales Dashboard')) {
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.analytics),
          title: Text('Sales Dashboard'),
          onTap: () => _onSelectItem(9),
        ),
      );
    }

    if (_hasAccess('Attendance Management')) {
      drawerItems.add(
        ListTile(
          leading: Icon(Icons.access_time),
          title: Text('Attendance Management'),
          onTap: () => _onSelectItem(10),
        ),
      );
    }

    // Add logout button
    drawerItems.addAll([
      Divider(),
      ListTile(
        leading: Icon(Icons.logout, color: Colors.red),
        title: Text('Logout', style: TextStyle(color: Colors.red)),
        onTap: _logout,
      ),
    ]);

    print('Total drawer items: ${drawerItems.length}');
    return drawerItems;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _pages == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ADD SAFETY CHECK before accessing arrays
    final safeIndex = _selectedDrawerIndex.clamp(0, _pages!.length - 1);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _selectedDrawerIndex < _appBarColors.length
            ? _appBarColors[_selectedDrawerIndex]
            : Colors.grey,
        elevation: 0,
        title: Text(
          _selectedDrawerIndex < _pageTitles.length
              ? _pageTitles[_selectedDrawerIndex]
              : 'Unknown',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        leading: _selectedDrawerIndex != 0
            ? IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => setState(() { _selectedDrawerIndex = 0; }),
        )
            : Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: _getDrawerItems(),
        ),
      ),
      body: _pages![safeIndex], // Use safeIndex instead of _selectedDrawerIndex
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _logout() async {
    final staffData = await _sharedPrefsHelper.getStaffLoginData();
    await _sharedPrefsHelper.removeStaffLoginData();
    await _sharedPrefsHelper.clearAll();
    DatabaseHelper databaseHelper = DatabaseHelper();
    await databaseHelper.init();
    final allRows = await databaseHelper.queryAllRows();
    if (allRows.isNotEmpty) {
      await databaseHelper.deleteUser(staffData['staff_id']?.toString() ?? '');
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => StaffLoginPage()),
    );
  }
}