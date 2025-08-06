import 'package:flutter/material.dart';

import 'package:restaurant_inventory/sell/SellRecordScreen.dart';

import 'SellScreen.dart';

class CombinedSellManagementScreen extends StatefulWidget {
  const CombinedSellManagementScreen({super.key});

  @override
  State<CombinedSellManagementScreen> createState() =>
      _CombinedManagementScreenState();
}

class _CombinedManagementScreenState
    extends State<CombinedSellManagementScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [const SellScreen(), const SellRecordScreen()];

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      style: ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Order'), icon: Icon(Icons.category),),
                        ButtonSegment(value: 1, label: Text('View Order'), icon: Icon(Icons.restaurant),),],
                      selected: {_selectedIndex},
                      onSelectionChanged: (newSelection) {
                        setState(() {
                          _selectedIndex = newSelection.first;
                        });
                      },
                    ),
                  ),
                ),
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
