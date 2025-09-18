import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_inventory/Staff/SalaryRecordScreen.dart';
import 'package:restaurant_inventory/admin/SalesDashboardScreen.dart';
import 'package:restaurant_inventory/costing/CostingRecordScreen.dart';
import 'package:restaurant_inventory/sell/CombinedSellManagementScreen.dart';
import '../DashboardScreen.dart';
import '../Food List/combinedAddFoodListManagementScreen.dart';
import '../Food List/menu_item_manager_screen.dart';
import '../Staff/StaffListScreen.dart';
import '../calCulateCash/CashCalculationScreen.dart';

class Navigation_Class extends StatefulWidget {
  @override
  _Navigation_ClassState createState() => _Navigation_ClassState();
}

class _Navigation_ClassState extends State<Navigation_Class> {
  int _selectedDrawerIndex = 0;

  final List<Widget> _pages = [
    CashCalculationScreen(),
    CombinedSellManagementScreen(),
    CostingRecordScreen(),
    StaffListScreen(),
    SalaryRecordScreen(),
    DashboardScreen(),
    combinedAddFoodListManagementScreen(),
    MenuItemManagerScreen(),
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
                  backgroundImage: AssetImage('assets/freshbite_icon.png'),
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
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,color:Colors.white),
        ),
        centerTitle: true,
        leading: _selectedDrawerIndex != 0
            ? IconButton(
          icon: Icon(Icons.arrow_back,color: Colors.white,),
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
            ListTile(
              leading: Icon(Icons.person_add),
              title: Text('Admin Login'),
              onTap: () async {
                final usernameController = TextEditingController();
                final passwordController = TextEditingController();
                // Use a variable to hold the message and its color
                String statusMessage = '';
                Color statusColor = Colors.transparent;
                final loggedUser = await showDialog<bool>(
                  context: context,
                  builder: (ctx) {
                    // StatefulBuilder lets you rebuild a part of the UI by calling setState
                    return StatefulBuilder(
                      builder: (context, setState) {
                        return AlertDialog(
                          title: const Text('Login'),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextFormField(
                                  controller: usernameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Username',
                                  ),
                                ),
                                TextFormField(
                                  controller: passwordController,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Password',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // This Text widget's content and color will be updated
                                Text(
                                  statusMessage,
                                  style: TextStyle(color: statusColor),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              child: const Text('Cancel'),
                              onPressed: () => Navigator.pop(ctx, false),
                            ),
                            TextButton(
                              child: const Text('Login'),
                              onPressed: () {
                                final username = usernameController.text;
                                final password = passwordController.text;

                                // Call setState to rebuild the UI with the new message
                                if (username.isNotEmpty && password.isNotEmpty) {
                                  String usernames ='freshbite';
                                  String passwords = 'adminshamim';
                                  if (username == usernames && password == passwords) {
                                    setState(() {
                                      statusMessage = 'You are logged in with username: $username and password: $password';
                                      statusColor = Colors.green;
                                      // You can add a small delay before popping the dialog

                                      Future.delayed(const Duration(seconds: 2), () {
                                        Navigator.pop(ctx, true);
                                      });
                                    });
                                  }
                                  else {
                                    setState(() {
                                      statusMessage = 'Invalid username or password';
                                      statusColor = Colors.red;
                                    });
                                  }


                                } else {
                                  setState(() {
                                    statusMessage = 'Please enter both username and password';
                                    statusColor = Colors.red;
                                  });
                                }
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                );

                if (loggedUser == true) {
                  print('Login successful!');
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => SalesDashboardScreen()) );
                } else {
                  print('Login failed or canceled.');
                  print('Login failed or canceled.');
                }
              },
            ),

          ],
        ),
      )
          : null,
      body: _pages[_selectedDrawerIndex],
    );
  }



}
