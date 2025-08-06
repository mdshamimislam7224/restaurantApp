import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../localDB/DBHelper.dart';

class CashCalculationScreen extends StatefulWidget {
  const CashCalculationScreen({Key? key}) : super(key: key);

  @override
  _CashCalculationScreenState createState() => _CashCalculationScreenState();
}

class _CashCalculationScreenState extends State<CashCalculationScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  double _totalSales = 0.0;
  double _totalCosting = 0.0;
  double _profit = 0.0;
  double _profitPercentage = 0.0;

  List<BarChartGroupData> _barGroups = [];
  double _minY = 0;
  double _maxY = 0;
  List<String> _xAxisLabels = [];

  final List<Map<String, dynamic>> _profitLossData = [
    {'label': 'Profit', 'value': 0, 'color': Colors.green},
    {'label': 'Loss', 'value': 0, 'color': Colors.red},
  ];

  @override
  void initState() {
    super.initState();
    _loadAllDataAndCalculateMetrics(_selectedDate);
  }

  Future<void> _loadAllDataAndCalculateMetrics(DateTime date) async {
    setState(() => _isLoading = true);

    try {
      final allSales = await DBHelper.getSales();
      final allCosting = await DBHelper.getCostingRecords();
      final dateFormat = DateFormat('yyyy-MM-dd');
      final selectedDateString = dateFormat.format(date);

      // Reset values
      _totalSales = 0.0;
      _totalCosting = 0.0;
      _profit = 0.0;
      _profitPercentage = 0.0;
      _profitLossData[0]['value'] = 0;
      _profitLossData[1]['value'] = 0;

      // Calculate data if exists
      final hasData = allSales.any((sale) {
        final saleDate = DateFormat('MM/dd/yyyy').parse(sale['date']);
        return dateFormat.format(saleDate) == selectedDateString;
      }) || allCosting.any((record) => record['date'] == selectedDateString);

      if (hasData) {
        _totalSales = allSales.where((sale) {
          final saleDate = DateFormat('MM/dd/yyyy').parse(sale['date']);
          return dateFormat.format(saleDate) == selectedDateString;
        }).fold(0.0, (sum, sale) => sum + (sale['total'] as double));

        _totalCosting = allCosting.where((record) {
          return record['date'] == selectedDateString;
        }).fold(0.0, (sum, record) => sum + (record['amount'] as double));

        _profit = _totalSales - _totalCosting;

        if (_totalSales > 0) {
          _profitPercentage = (_profit / _totalSales).abs().clamp(0.0, 1.0);
        }

        if (_profit >= 0) {
          _profitLossData[0]['value'] = _profit;
        } else {
          _profitLossData[1]['value'] = _profit.abs();
        }
      }

      // Prepare chart
      _barGroups = [
        BarChartGroupData(
          x: 0,
          barRods: [BarChartRodData(
            toY: _profit,
            color: _profit >= 0 ? Colors.green : Colors.red,
            width: 30,
            borderRadius: BorderRadius.zero,
          )],
        )
      ];

      _xAxisLabels = [DateFormat('MM/dd').format(date)];
      _minY = _profit < 0 ? _profit * 1.1 : 0;
      _maxY = _profit > 0 ? _profit * 1.1 : 0;

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error calculating metrics: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadAllDataAndCalculateMetrics(_selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Calculation & Profit'),
        backgroundColor: Colors.blueGrey,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          children: [
            // Date selector
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Selected Date:',
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _selectDate(context),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        DateFormat('yyyy-MM-dd').format(_selectedDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Stats Container
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Products Sales',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('MMM dd').format(_selectedDate)} - ${DateFormat('MMM dd yyyy').format(_selectedDate.add(const Duration(days: 30)))}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Circular chart and indicators
                  Column(
                    children: [
                      CircularPercentIndicator(
                        radius: isSmallScreen ? 50.0 : 60.0,
                        lineWidth: 10.0,
                        percent: _profitPercentage,
                        center: Text(
                          _totalSales > 0
                              ? "${(_profitPercentage * 100 * (_profit >= 0 ? 1 : -1)).toStringAsFixed(0)}%"
                              : "0%",
                          style: TextStyle(
                            fontSize: isSmallScreen ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: _totalSales > 0
                                ? (_profit >= 0 ? Colors.green : Colors.red)
                                : Colors.grey,
                          ),
                        ),
                        progressColor: _totalSales > 0
                            ? (_profit >= 0 ? Colors.green : Colors.red)
                            : Colors.grey,
                        backgroundColor: Colors.grey.shade200,
                        circularStrokeCap: CircularStrokeCap.round,
                      ),
                      const SizedBox(height: 20),

                      // Profit/Loss indicators
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: isSmallScreen ? 20.0 : 40.0,
                        children: _profitLossData.map((data) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: data['color'],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                 Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['label'],
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      Text(
                                        '\$${data['value'].toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: data['color'],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Summary cards
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSummaryCard(
                      title: 'Total Sales (${DateFormat('MM/dd/yyyy').format(_selectedDate)})',
                      amount: _totalSales,
                      color: Colors.green,
                      icon: Icons.trending_up,
                      isSmallScreen: isSmallScreen,
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryCard(
                      title: 'Total Costing (${DateFormat('MM/dd/yyyy').format(_selectedDate)})',
                      amount: _totalCosting,
                      color: Colors.red,
                      icon: Icons.trending_down,
                      isSmallScreen: isSmallScreen,
                    ),
                    const SizedBox(height: 16),
                    _buildProfitCard(
                      profit: _profit,
                      isSmallScreen: isSmallScreen,
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

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
    required bool isSmallScreen,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: isSmallScreen ? 32 : 40,
            ),
            SizedBox(width: isSmallScreen ? 12 : 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 22 : 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitCard({
    required double profit,
    required bool isSmallScreen,
  }) {
    Color profitColor = profit >= 0 ? Colors.green.shade700 : Colors.red.shade700;
    String profitText = profit >= 0 ? 'Profit' : 'Loss';
    IconData profitIcon = profit >= 0 ? Icons.attach_money : Icons.money_off;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
        child: Row(
          children: [
            Icon(
              profitIcon,
              color: profitColor,
              size: isSmallScreen ? 32 : 40,
            ),
            SizedBox(width: isSmallScreen ? 12 : 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Net $profitText',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${profit.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 22 : 28,
                      fontWeight: FontWeight.bold,
                      color: profitColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}