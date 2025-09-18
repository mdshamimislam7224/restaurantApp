import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
class SalesDashboardScreen extends StatefulWidget {
  const SalesDashboardScreen({super.key});

  @override
  State<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends State<SalesDashboardScreen> {
  // Your Google Apps Script web app URL with a placeholder for pagination
  final String scriptUrl = 'https://script.google.com/macros/s/AKfycbyRcqiBgHjaryFtYb9Q9ZOH1SuWXAKeB5XUq3k05H5EJKJW7G2ZfBORjZ8SP3edJE0Oqg/exec';

  // State variables for data
  List<dynamic> _dailyData = [];
  bool _isLoading = true;
  bool _isFetchingMore = false;
  String _errorMessage = '';

  // Pagination variables
  int _page = 1;
  final int _limit = 14;
  final ScrollController _scrollController = ScrollController();
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
    // Add a listener to the scroll controller to detect when to load more data
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        if (!_isLoading && !_isFetchingMore && _hasMore) {
          _fetchMoreData();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Async function to fetch data from the Google Apps Script
  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _page = 1; // Reset page number on initial fetch or refresh
      _dailyData.clear();
      _hasMore = true;
    });

    await _fetchDataFromApi();
  }

  // Async function to fetch more data (for pagination)
  Future<void> _fetchMoreData() async {
    if (_hasMore && !_isFetchingMore) {
      setState(() {
        _isFetchingMore = true;
      });
      _page++;
      await _fetchDataFromApi();
    }
  }

  Future<void> _fetchDataFromApi() async {
    try {
      final Uri uri = Uri.parse(scriptUrl).replace(queryParameters: {
        'action': 'getDailySellData',
        'page': _page.toString(),
        'limit': _limit.toString(),
        'startDate': '2025-08-01', // Example dates
        'endDate': '2025-09-19',   // Example dates
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final List<dynamic> newData = data['data'];

          // Convert string values to doubles
          final parsedData = newData.map((item) {
            return {
              'id': item['id'],
              'date': item['Date'],
              'salesAmount': double.tryParse(item['Sales Amount'].toString()) ?? 0.0,
              'costingAmount': double.tryParse(item['Costing Amount'].toString()) ?? 0.0,
              'netAmount': double.tryParse(item['Net Amount'].toString()) ?? 0.0,
              'lossAmount': double.tryParse(item['Loss Amount'].toString()) ?? 0.0,
            };
          }).toList();

          setState(() {
            _dailyData.addAll(parsedData);
            _isLoading = false;
            _isFetchingMore = false;
            if (newData.length < _limit) {
              _hasMore = false;
            }
          });
        } else {
          setState(() {
            _errorMessage = data['message'];
            _isLoading = false;
            _isFetchingMore = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load data. Status: ${response.statusCode}';
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isLoading = false;
        _isFetchingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Sales Dashboard'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _dailyData.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage))
          : RefreshIndicator(
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSummaryGrid(),
                const SizedBox(height: 24),
                _buildChartSection(),
                const SizedBox(height: 24),
                _buildDailyRecordsList(),
                if (_isFetchingMore)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (!_hasMore)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text('No more data to load.'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build the summary grid
  Widget _buildSummaryGrid() {
    double totalSales = _dailyData.fold(0.0, (sum, item) => sum + item['salesAmount']);
    double totalCosting = _dailyData.fold(0.0, (sum, item) => sum + item['costingAmount']);
    double totalNet = _dailyData.fold(0.0, (sum, item) => sum + item['netAmount']);
    double totalLoss = _dailyData.fold(0.0, (sum, item) => sum + item['lossAmount']);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Create a responsive grid based on screen width
        int crossAxisCount = constraints.maxWidth < 600 ? 2 : 4;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildSummaryCard('Total Sales', totalSales, Colors.blue),
            _buildSummaryCard('Total Costing', totalCosting, Colors.blue),
            _buildSummaryCard('Total Net', totalNet, Colors.green),
            _buildSummaryCard('Total Loss', totalLoss, Colors.red),
          ],
        );
      },
    );
  }

  // Helper method to build an individual summary card
  Widget _buildSummaryCard(String title, double amount, MaterialColor color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '\$${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build the chart section
  Widget _buildChartSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales & Costing Trends',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            // Placeholder for a chart.
            // You would use a charting package here, like `fl_chart`.
            // Example:
            // SizedBox(
            //   height: 250,
            //   child: LineChart(
            //     LineChartData(
            //       // Chart data and styling goes here...
            //     ),
            //   ),
            // ),
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Chart placeholder',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build the daily records list
  Widget _buildDailyRecordsList() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Records',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _dailyData.length,
              itemBuilder: (context, index) {
                final item = _dailyData[index];
                final isNetPositive = item['netAmount'] >= 0;
                final netColor = isNetPositive ? Colors.green : Colors.red;
                final netSign = isNetPositive ? '+' : '';

                return Card(
                  elevation: 0,
                  color: Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['date'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sales: \$${item['salesAmount'].toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                'Costing: \$${item['costingAmount'].toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Chip(
                          backgroundColor: netColor.withOpacity(0.1),
                          label: Text(
                            '$netSign\$${item['netAmount'].toStringAsFixed(2)}',
                            style: TextStyle(
                              color: netColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
