import 'package:flutter/material.dart';
import 'CategoryManagerScreen.dart';
import 'menu_item_manager_screen.dart';

class CombinedManagementScreen extends StatefulWidget {
  const CombinedManagementScreen({super.key});

  @override
  State<CombinedManagementScreen> createState() => _CombinedManagementScreenState();
}

class _CombinedManagementScreenState extends State<CombinedManagementScreen> {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  final List<Widget> _screens = [
    const CategoryManagerScreen(),
    const MenuItemManagerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header with tabs and search
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Segmented Button - Full Width
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      style: ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      segments: const [
                        ButtonSegment(
                          value: 0,
                          label: Text('Categories'),
                          icon: Icon(Icons.category),
                        ),
                        ButtonSegment(
                          value: 1,
                          label: Text('Menu Items'),
                          icon: Icon(Icons.restaurant),
                        ),
                      ],
                      selected: {_selectedIndex},
                      onSelectionChanged: (newSelection) {
                        setState(() {
                          _selectedIndex = newSelection.first;
                        });
                      },
                    ),
                  ),
                ),

                // Search Bar
                // Padding(
                //   padding: const EdgeInsets.symmetric(horizontal: 16),
                //   child: TextField(
                //     controller: _searchController,
                //     decoration: InputDecoration(
                //       hintText: 'Search...',
                //       prefixIcon: const Icon(Icons.search),
                //       border: OutlineInputBorder(
                //         borderRadius: BorderRadius.circular(10),
                //       ),
                //       filled: true,
                //       contentPadding: const EdgeInsets.symmetric(vertical: 0),
                //     ),
                //     onChanged: (value) {
                //       setState(() {});
                //     },
                //   ),
                // ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Screen Content
          SliverFillRemaining(
            hasScrollBody: true,
            child: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}