import 'package:flutter/material.dart';
import 'CategoryManagerScreen.dart';
import 'menu_item_manager_screen.dart';

class combinedAddFoodListManagementScreen extends StatefulWidget {
  const combinedAddFoodListManagementScreen({super.key});

  @override
  State<combinedAddFoodListManagementScreen> createState() => _combinedAddFoodListManagementScreenState();
}

class _combinedAddFoodListManagementScreenState extends State<combinedAddFoodListManagementScreen> {
  int _selectedIndex = 0;
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical:8),
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
                // Padding(
                //   padding:
                //       const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                //   child: Row(
                //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //     children: [
                //       Text('Data Reload',
                //           style: Theme.of(context).textTheme.headlineSmall),
                //       IconButton(
                //         icon: const Icon(Icons.refresh),
                //         onPressed: () {
                //
                //
                //         },
                //       ),
                //     ],
                //   ),
                // ),

                const SizedBox(height: 10),
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

}