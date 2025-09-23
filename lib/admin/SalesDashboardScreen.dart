import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../api/apiClass.dart';
import 'DailyDetailsScreen.dart';

class SalesDashboardScreen extends StatefulWidget {
  const SalesDashboardScreen({super.key});

  @override
  State<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends State<SalesDashboardScreen> {
  List<dynamic> _dailyData = [];
  bool _isLoading = true;
  bool _isFetchingMore = false;
  String _errorMessage = '';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  int _page = 1;
  final int _limit = 5;
  final ScrollController _scrollController = ScrollController();
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
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

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _page = 1;
      _dailyData.clear();
      _hasMore = true;
    });
    await _fetchDataFromApi();
  }

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
      final Uri uri = Uri.parse(apiClass.baseUrlSell).replace(queryParameters: {
        'action': 'getDailySellData',
        'page': _page.toString(),
        'limit': _limit.toString(),
        'startDate': DateFormat('yyyy-MM-dd').format(_startDate),
        'endDate': DateFormat('yyyy-MM-dd').format(_endDate),
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final List<dynamic> newData = data['data'];
          print('New Data: $newData');
          final parsedData = newData.map((item) {
            return {
              'id': item['id'],
              'date': item['Date'],
              'salesAmount': double.tryParse(item['Sales Amount'].toString()) ?? 0.0,
              'costingAmount': double.tryParse(item['Costing Amount'].toString()) ?? 0.0,
              'netAmount': double.tryParse(item['Net Amount'].toString()) ?? 0.0,
              'lossAmount': double.tryParse(item['Loss Amount'].toString()) ?? 0.0,
              'cash': double.tryParse(item['Cash'].toString()) ?? 0.0,
              'bKash': double.tryParse(item['Bkash'].toString()) ?? 0.0,
              'card': double.tryParse(item['Card'].toString()) ?? 0.0,
              'nagad': double.tryParse(item['Nagad'].toString()) ?? 0.0,
              'rocket': double.tryParse(item['Rocket'].toString()) ?? 0.0,
              'bankTransfer': double.tryParse(item['Bank Transfer'].toString()) ?? 0.0,
              'other': double.tryParse(item['Other'].toString()) ?? 0.0,
            };
          }).toList();

          setState(() {
            print('Bkash: ${parsedData[0]['bKash']}');
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

  Future<void> _selectDateRange() async {
    final DateTimeRange? newDateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.deepPurple,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.deepPurple,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (newDateRange != null) {
      setState(() {
        _startDate = newDateRange.start;
        _endDate = newDateRange.end;
      });
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading && _dailyData.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage))
          : RefreshIndicator(
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSummaryGrid(),
                    const SizedBox(height: 24),
                    _buildChartSection(),
                    const SizedBox(height: 24),
                    _buildPaymentMethodSummary(),
                    const SizedBox(height: 24),
                    _buildDailyRecordsList(),
                    if (_isFetchingMore)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 10, bottom: 20, left: 24, right: 24),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Sales Overview',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            _buildDateRangePicker(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return GestureDetector(
      onTap: _selectDateRange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withOpacity(0.5),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.calendar_today, color: Colors.white, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${DateFormat('MMM d, yyyy').format(_startDate)} - ${DateFormat(
                    'MMM d, yyyy').format(_endDate)}',
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: _selectDateRange,
              child: const Text('Change', style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryGrid() {
    double totalSales = _dailyData.fold(0.0, (sum, item) => sum + item['salesAmount']);
    double totalCosting = _dailyData.fold(0.0, (sum, item) => sum + item['costingAmount']);
    double totalNet = _dailyData.fold(0.0, (sum, item) => sum + item['netAmount']);
    double totalLoss = _dailyData.fold(0.0, (sum, item) => sum + item['lossAmount']);

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth < 600 ? 2 : 4;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.8,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _buildSummaryCard(
              title: 'Total Sales',
              amount: totalSales,
              icon: Icons.attach_money,
              color: const Color(0xFF673AB7).withOpacity(0.7),
            ),
            _buildSummaryCard(
              title: 'Total Costing',
              amount: totalCosting,
              icon: Icons.shopping_basket,
              color: const Color(0xFF29B6F6).withOpacity(0.7),
            ),
            _buildSummaryCard(
              title: 'Total Net',
              amount: totalNet,
              icon: Icons.trending_up,
              color: Colors.green.withOpacity(0.7),
            ),
            _buildSummaryCard(
              title: 'Total Loss',
              amount: totalLoss,
              icon: Icons.trending_down,
              color: const Color(0xFFF44336).withOpacity(0.7),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '\$${amount.toStringAsFixed(1)}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Performance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                height: 250,
                width: _dailyData.length * 50.0,
                child: _dailyData.isEmpty
                    ? const Center(
                  child: Text(
                    'No data to display.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
                    : _buildBarChart(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    _dailyData.sort((a, b) => a['date'].compareTo(b['date']));

    double maxY = _dailyData.fold(0.0, (prev, element) {
      double sales = element['salesAmount'] ?? 0.0;
      double costing = element['costingAmount'] ?? 0.0;
      return prev > sales ? (prev > costing ? prev : costing) : (sales > costing ? sales : costing);
    });
    maxY = (maxY * 1.2).ceilToDouble();

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < _dailyData.length; i++) {
      final item = _dailyData[i];
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: item['salesAmount'],
              color: const Color(0xFF673AB7),
              width: 10,
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: item['costingAmount'],
              color: const Color(0xFF29B6F6),
              width: 10,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String date = _dailyData[group.x.toInt()]['date'];
              String type = rodIndex == 0 ? 'Sales' : 'Costing';
              return BarTooltipItem(
                '$type: \$${rod.toY.toStringAsFixed(2)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                children: <TextSpan>[
                  TextSpan(
                    text: '\n${DateFormat('MMM d').format(DateTime.parse(date))}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() % 7 == 0 && value.toInt() < _dailyData.length) {
                  String date = _dailyData[value.toInt()]['date'];
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4,
                    child: Text(
                      DateFormat('M/d').format(DateTime.parse(date)),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${value.toInt()}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
              dashArray: [5, 3],
            );
          },
        ),
        barGroups: barGroups,
      ),
    );
  }

  Widget _buildPaymentMethodSummary() {
    double totalCash = _dailyData.fold(0.0, (sum, item) => sum + (item['cash'] ?? 0.0));
    double totalbKash = _dailyData.fold(0.0, (sum, item) => sum + (item['bKash'] ?? 0.0));
    double totalCard = _dailyData.fold(0.0, (sum, item) => sum + (item['card'] ?? 0.0));
    double totalNagad = _dailyData.fold(0.0, (sum, item) => sum + (item['nagad'] ?? 0.0));
    double totalRocket = _dailyData.fold(0.0, (sum, item) => sum + (item['rocket'] ?? 0.0));
    double totalBankTransfer = _dailyData.fold(0.0, (sum, item) => sum + (item['bankTransfer'] ?? 0.0));
    double totalOther = _dailyData.fold(0.0, (sum, item) => sum + (item['other'] ?? 0.0));

    final paymentMethods = [
      {'name': 'Cash', 'amount': totalCash, 'color': Colors.green[600]},
      {'name': 'bKash', 'amount': totalbKash, 'color': Colors.pink[600]},
      {'name': 'Nagad', 'amount': totalNagad, 'color': Colors.orange[600]},
      {'name': 'Rocket', 'amount': totalRocket, 'color': Colors.purple[600]},
      {'name': 'Card', 'amount': totalCard, 'color': Colors.blue[600]},
      {'name': 'Bank', 'amount': totalBankTransfer, 'color': Colors.teal[600]},
      {'name': 'Other', 'amount': totalOther, 'color': Colors.grey[600]},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Method Breakdown',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          // Use LayoutBuilder for responsiveness
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 3; // Default for smaller screens
              if (constraints.maxWidth > 600) {
                crossAxisCount = 4;
              }
              if (constraints.maxWidth > 900) {
                crossAxisCount = 6;
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.5,
                ),
                itemCount: paymentMethods.length,
                itemBuilder: (context, index) {
                  final method = paymentMethods[index];
                  final double amount = method['amount'] as double;
                  if (amount > 0) {
                    return _buildPaymentMethodCard(
                      name: method['name'].toString(),
                      amount: amount,
                      color: method['color'] as Color,
                    );
                  }
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        ],
      ),
    );
  }
  Widget _buildPaymentMethodCard({required String name, required double amount, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '\৳${amount.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyRecordsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
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
                final netColor = isNetPositive ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DailyDetailsScreen(date: item['date']),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.05),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('MMM d, yyyy').format(DateTime.parse(item['date'])),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF673AB7),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Sales: \$${item['salesAmount'].toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF29B6F6),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Costing: \$${item['costingAmount'].toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: netColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${isNetPositive ? '+' : ''}\$${item['netAmount'].toStringAsFixed(2)}',
                            style: TextStyle(
                              color: netColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}