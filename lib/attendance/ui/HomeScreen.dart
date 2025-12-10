import 'package:flutter/material.dart';

import 'AllStaffAttendanceScreen.dart';
import 'AttendanceScreen.dart';
import 'HistoryScreen.dart';
import 'ProfileScreen.dart';

class HomeScreen extends StatefulWidget {
  final String staffId;
  final String staffName;

  const HomeScreen({
    super.key,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    print('Staff ID: ${widget.staffId}');
    _pages = [
      AttendanceScreen(
        staffId: widget.staffId,
        staffName: widget.staffName,
      ),
      AllStaffAttendanceScreen(),
      // HistoryScreen(
      //   staffId: widget.staffId,
      //   staffName: widget.staffName,
      // ),
      ProfileScreen(
        staffId: widget.staffId,
        staffName: widget.staffName,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF4361EE),
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home, size: 24),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history, size: 24),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person, size: 24),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}