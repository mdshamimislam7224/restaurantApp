import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_inventory/attendance/ui/AttendanceScreen.dart';
import '../Food List/combinedAddFoodListManagementScreen.dart';
import '../Staff/StaffListScreen.dart';
import '../Staff/StaffLoginPage.dart';
import '../Staff/StaffPaymentDetailsScreen.dart';
import '../Staff/StaffProfileScreen.dart';
import '../Staff/StaffSinglePaymentDetailsScreen.dart';
import '../admin/SalesDashboardScreen.dart';
import '../attendance/RecognitionScreen.dart';
import '../attendance/ui/AttendanceHierarchyScreen.dart';
import '../attendance/ui/HomeScreen.dart';
import '../calCulateCash/CashCalculationScreen.dart';
import '../costing/CostingRecordScreen.dart';
import '../financial_Management/financial_HomeScreen.dart';
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

  // Track navigation history for back button
  List<int> _navigationHistory = [0];

  // Define all pages with their access roles
  final List<PageConfig> _pageConfigs = [
    PageConfig(
      title: "Dashboard",
      pageBuilder: (context, staffId, staffName) => CashCalculationScreen(),
      allowedRoles: {'admin', 'staff'},
      icon: Icons.dashboard,
    ),
    PageConfig(
      title: 'Sell Management',
      pageBuilder: (context, staffId, staffName) => CombinedSellManagementScreen(),
      allowedRoles: {'admin', 'staff'},
      icon: Icons.shopping_cart,
    ),
    PageConfig(
      title: 'Costing Management',
      pageBuilder: (context, staffId, staffName) => CostingRecordScreen(),
      allowedRoles: {'admin', 'staff'},
      icon: Icons.calculate,
    ),
    PageConfig(
      title: 'Profile View',
      pageBuilder: (context, staffId, staffName) => StaffProfileScreen(staffId: staffId),
      allowedRoles: {'staff'}, // Staff only
      icon: Icons.person,
    ),
    PageConfig(
      title: "Payment View",
      pageBuilder: (context, staffId, staffName) => StaffSinglePaymentDetailsScreen(
        staffId: staffId,
        staffJoiningDate: '', // Will be set later
      ),
      allowedRoles: {'staff'}, // Staff only
      icon: Icons.payment,
    ),
    PageConfig(
      title: 'Attendance',
      pageBuilder: (context, staffId, staffName) => RecognitionScreen(),
      allowedRoles: {'staff'}, // Staff only
      icon: Icons.access_time,
    ),
    PageConfig(
      title: 'Attendance Log',
      pageBuilder: (context, staffId, staffName) => AttendanceScreen(
        staffId: staffId,
        staffName: staffName,
      ),
      allowedRoles: {'staff'}, // Staff only
      icon: Icons.list_alt,
    ),
    PageConfig(
      title: 'Staff Attendance Log',
      pageBuilder: (context, staffId, staffName) => AttendanceHierarchyScreen(),
      allowedRoles: {'admin'}, // Admin only
      icon: Icons.history,
    ),
    PageConfig(
      title: 'Staff Payment View',
      pageBuilder: (context, staffId, staffName) => StaffPaymentDetailsScreen(),
      allowedRoles: {'admin'}, // Admin only
      icon: Icons.payment,
    ),
    PageConfig(
      title: 'Staff List',
      pageBuilder: (context, staffId, staffName) => StaffListScreen(),
      allowedRoles: {'admin'}, // Admin only
      icon: Icons.people,
    ),
    PageConfig(
      title: 'Food List Management',
      pageBuilder: (context, staffId, staffName) => combinedAddFoodListManagementScreen(),
      allowedRoles: {'admin'}, // Admin only
      icon: Icons.restaurant_menu,
    ),
    PageConfig(
      title: 'Sales Dashboard',
      pageBuilder: (context, staffId, staffName) => SalesDashboardScreen(),
      allowedRoles: {'admin'}, // Admin only
      icon: Icons.analytics,
    ),
    PageConfig(
      title: 'Attendance Management',
      pageBuilder: (context, staffId, staffName) => HomeScreen(
        staffId: staffId,
        staffName: staffName,
      ),
      allowedRoles: {'admin'}, // Admin only
      icon: Icons.access_time,
    ),
    PageConfig(
      title: 'Financial Management',
      pageBuilder: (context, staffId, staffName) => financial_HomeScreen(),
      allowedRoles: {'admin'}, // Admin only
      icon: Icons.functions_outlined,
    ),
  ];

  Future<void> _loadUserData() async {
    final staffData = await _sharedPrefsHelper.getStaffLoginData();
    setState(() {
      _userRole = staffData['userrole']?.toLowerCase() ?? '';
      _staffName = staffData['staff_name'] ?? '';
      _staffPosition = staffData['staff_position'] ?? '';
      staffId = staffData['staff_id'] ?? '';
      _staffStatus = staffData['status'] ?? '';
      _staffJoningDate = staffData['joiningdate'] ?? '';
      _isLoading = false;
    });

    // Initialize pages
    final accessiblePages = <Widget>[];

    for (var config in _pageConfigs) {
      if (_hasAccessToPage(config)) {
        accessiblePages.add(config.pageBuilder(context, staffId, _staffName));
      }
    }

    setState(() {
      _pages = accessiblePages;
    });
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return Container(
      height: 200, // Fixed height to prevent overflow
      decoration: BoxDecoration(color: Colors.blue),
      child: Stack(
        children: [

          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.white, size: 24),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Image.asset(
                    'assets/freshbite_icon.png',
                    width: 50,
                    height: 50,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.restaurant, size: 30, color: Colors.blue);
                    },
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Fresh Bite',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _staffName.isNotEmpty ? _staffName : 'User',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                  ),
                ),
                SizedBox(height: 2),
                if (_staffPosition.isNotEmpty)
                  Text(
                    _staffPosition,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                  ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRoleColor(_userRole),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _userRole.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
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

  bool _hasAccessToPage(PageConfig config) {
    if (_userRole.isEmpty) return false;
    return config.allowedRoles.contains(_userRole.toLowerCase());
  }

  List<Widget> _getDrawerItems() {
    final drawerItems = <Widget>[
      _buildDrawerHeader(context),
    ];

    // Create a list of accessible pages with their indices
    final accessiblePageConfigs = <Map<String, dynamic>>[];
    int pageIndex = 0;

    for (int i = 0; i < _pageConfigs.length; i++) {
      if (_hasAccessToPage(_pageConfigs[i])) {
        accessiblePageConfigs.add({
          'config': _pageConfigs[i],
          'originalIndex': i,
          'currentIndex': pageIndex,
        });
        pageIndex++;
      }
    }

    // Add accessible pages to drawer
    for (var pageInfo in accessiblePageConfigs) {
      final config = pageInfo['config'] as PageConfig;
      final index = pageInfo['currentIndex'] as int;

      drawerItems.add(
        ListTile(
          leading: Icon(config.icon),
          title: Text(config.title),
          onTap: () {
            _navigateToPage(index);
          },
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

    return drawerItems;
  }

  void _navigateToPage(int index) {
    if (index != _selectedDrawerIndex) {
      // Add current page to history if it's different
      if (!_navigationHistory.contains(_selectedDrawerIndex)) {
        _navigationHistory.add(_selectedDrawerIndex);
      }

      setState(() {
        _selectedDrawerIndex = index;
      });
    }
    Navigator.pop(context); // Close drawer
  }

  void _goBack() {
    if (_navigationHistory.isNotEmpty && _navigationHistory.length > 1) {
      // Remove current page
      _navigationHistory.removeLast();
      // Go to previous page
      int previousIndex = _navigationHistory.last;

      setState(() {
        _selectedDrawerIndex = previousIndex;
      });
    } else if (_selectedDrawerIndex != 0) {
      // If no history but not on dashboard, go to dashboard
      setState(() {
        _selectedDrawerIndex = 0;
        _navigationHistory = [0];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _pages == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_pages!.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 20),
              Text(
                'No Access',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'You do not have access to any features.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _logout,
                child: Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Clamp selected index to valid range
    final safeIndex = _selectedDrawerIndex.clamp(0, _pages!.length - 1);

    // Find the corresponding page title
    String pageTitle = "Dashboard";
    int accessiblePageCount = 0;

    for (int i = 0; i < _pageConfigs.length; i++) {
      if (_hasAccessToPage(_pageConfigs[i])) {
        if (accessiblePageCount == safeIndex) {
          pageTitle = _pageConfigs[i].title;
          break;
        }
        accessiblePageCount++;
      }
    }

    return WillPopScope(
      onWillPop: () async {
        if (_selectedDrawerIndex != 0) {
          _goBack();
          return false; // Don't exit app
        }
        return true; // Exit app
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          elevation: 0,
          title: Text(
            pageTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          leading: _selectedDrawerIndex != 0
              ? IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _goBack,
          )
              : Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          actions: [
            if (_selectedDrawerIndex != 0)
              IconButton(
                icon: Icon(Icons.home, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _selectedDrawerIndex = 0;
                    _navigationHistory = [0];
                  });
                },
                tooltip: 'Go to Dashboard',
              ),
          ],
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
        body: _pages![safeIndex],
      ),
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

// Helper class to define page configurations
class PageConfig {
  final String title;
  final Widget Function(BuildContext context, String staffId, String staffName)
  pageBuilder;
  final Set<String> allowedRoles;
  final IconData icon;

  PageConfig({
    required this.title,
    required this.pageBuilder,
    required this.allowedRoles,
    required this.icon,
  });
}