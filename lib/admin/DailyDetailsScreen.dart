import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:restaurant_inventory/api/apiClass.dart';

class DailyDetailsScreen extends StatefulWidget {
  final String date;

  const DailyDetailsScreen({super.key, required this.date});

  @override
  State<DailyDetailsScreen> createState() => _DailyDetailsScreenState();
}
class _DailyDetailsScreenState extends State<DailyDetailsScreen> {
  List<dynamic> _salesItems = [];
  List<dynamic> _costingRecords = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _selectedView = 'Sales Items';

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final Uri uri = Uri.parse(apiClass.baseUrlSell).replace(queryParameters: {
        'action': 'getDailyDetails',
        'date': widget.date,
      });

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _salesItems = data['salesItems'];
            _costingRecords = data['costingRecords'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = data['message'];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load data. Status: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          DateFormat('MMM d, yyyy').format(DateTime.parse(widget.date)),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage))
          : Column(
        children: [
          // Modern segmented control for view selection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildToggleButton('Sales Items'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildToggleButton('Costing Records'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Expanded widget to ensure the list takes remaining space and is scrollable
          Expanded(
            child: _selectedView == 'Sales Items'
                ? _buildSalesItemsList()
                : _buildCostingRecordsList(),
          ),
        ],
      ),
    );
  }
  Widget _buildToggleButton(String title) {
    final isSelected = _selectedView == title;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedView = title;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSalesItemsList() {
    if (_salesItems.isEmpty) {
      return const Center(
        child: Text('No sales items for this date.'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: _salesItems.length,
      itemBuilder: (context, index) {
        final item = _salesItems[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            title: Text(
              item['Item Name'].toString(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('Quantity: ${item['quantity']}'),
            trailing: Text(
              '\$${item['total']}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green,
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _buildCostingRecordsList() {
    if (_costingRecords.isEmpty) {
      return const Center(
        child: Text('No costing records for this date.'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: _costingRecords.length,
      itemBuilder: (context, index) {
        final record = _costingRecords[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            title: Text(
              record['description'].toString(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('Type: ${record['type']}'),
            trailing: Text(
              '\$${record['amount']}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.red,
              ),
            ),
          ),
        );
      },
    );
  }
}