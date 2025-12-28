// SummaryScreen.dart
import 'package:flutter/material.dart';
import 'model/InventoryItem.dart';

class SummaryScreen extends StatelessWidget {
  final List<InventoryItem> items;

  SummaryScreen({required this.items});

  @override
  Widget build(BuildContext context) {
    final totalItems = items.length;
    final totalQuantity = items.fold(0, (sum, item) => sum + item.quantity);

    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Summary'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📊 Summary',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Total Items: $totalItems',
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Total Quantity: $totalQuantity',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}