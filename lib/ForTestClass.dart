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

  // For the bar chart
  List<BarChartGroupData> _barGroups = [];
  double _minY = 0;
  double _maxY = 0;
  List<String> _xAxisLabels = [];

  // For the left-side description
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

      // Calculate daily totals for selected date
      _totalSales = allSales.where((sale) {
        final saleDate = DateFormat('MM/dd/yyyy').parse(sale['date']);
        return dateFormat.format(saleDate) == selectedDateString;
      }).fold(0.0, (sum, sale) => sum + (sale['total'] as double));

      _totalCosting = allCosting.where((record) {
        return record['date'] == selectedDateString;
      }).fold(0.0, (sum, record) => sum + (record['amount'] as double));

      _profit = _totalSales - _totalCosting;

      // Calculate profit percentage
      if (_totalSales > 0) {
        _profitPercentage = (_profit / _totalSales).clamp(0.0, 1.0);
      }

      // Update profit/loss legend data
      if (_profit >= 0) {
        _profitLossData[0]['value'] = _profit;
        _profitLossData[1]['value'] = 0;
      } else {
        _profitLossData[0]['value'] = 0;
        _profitLossData[1]['value'] = _profit.abs();
      }

      // Prepare chart data for the selected day only
      _barGroups = [];
      _xAxisLabels = [];

      // Create a single bar for the selected date
      final profit = _totalSales - _totalCosting;
      _barGroups.add(BarChartGroupData(
        x: 0,
        barRods: [BarChartRodData(
          toY: profit,
          color: profit >= 0 ? Colors.green : Colors.red,
          width: 30,
          borderRadius: BorderRadius.zero,
        )],
      ));

      _xAxisLabels.add(DateFormat('MM/dd').format(date));

      // Set min/max Y values for proper chart scaling
      _minY = profit < 0 ? profit * 1.1 : 0;
      _maxY = profit > 0 ? profit * 1.1 : 0;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Calculation & Profit'),
        backgroundColor: Colors.blueGrey,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Date selector card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selected Date:',
                      style: Theme.of(context).textTheme.titleLarge,
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

            // Main content with chart and legend
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side - Profit/Loss description
                  Container(
                    width: 120,
                    padding: const EdgeInsets.only(top: 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _profitLossData.map((data) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Row(
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
                              Column(
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
                        );
                      }).toList(),
                    ),
                  ),

                  // Right side - Chart and cards
                  Expanded(
                    child: Column(
                      children: [
                        // Circular percentage chart
                        Container(
                          padding: const EdgeInsets.all(16.0),
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
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${DateFormat('MMM dd').format(_selectedDate)} - ${DateFormat('MMM dd yyyy').format(_selectedDate.add(const Duration(days: 30)))}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 20),
                              CircularPercentIndicator(
                                radius: 80.0,
                                lineWidth: 15.0,
                                percent: _profitPercentage,
                                center: Text(
                                  "${(_profitPercentage * 100).toStringAsFixed(0)}%",
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: _profit >= 0 ? Colors.green : Colors.red,
                                  ),
                                ),
                                progressColor: _profit >= 0 ? Colors.green : Colors.red,
                                backgroundColor: Colors.grey.shade200,
                                circularStrokeCap: CircularStrokeCap.round,
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildProfitIndicator(true),
                                  _buildProfitIndicator(false),
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
                                ),
                                const SizedBox(height: 16),
                                _buildSummaryCard(
                                  title: 'Total Costing (${DateFormat('MM/dd/yyyy').format(_selectedDate)})',
                                  amount: _totalCosting,
                                  color: Colors.red,
                                  icon: Icons.trending_down,
                                ),
                                const SizedBox(height: 16),
                                _buildProfitCard(
                                  profit: _profit,
                                ),
                                const SizedBox(height: 30),

                                // Bar chart for the selected day
                                const Text(
                                  'Daily Profit/Loss',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  height: 200,
                                  padding: const EdgeInsets.all(16.0),
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
                                  child: BarChart(
                                    BarChartData(
                                      alignment: BarChartAlignment.center,
                                      maxY: _maxY,
                                      minY: _minY,
                                      groupsSpace: 20,
                                      barGroups: _barGroups,
                                      gridData: const FlGridData(show: false),
                                      borderData: FlBorderData(show: false),
                                      titlesData: FlTitlesData(
                                        show: true,
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (value, meta) {
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 8.0),
                                                child: Text(
                                                  _xAxisLabels[value.toInt()],
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                              );
                                            },
                                            reservedSize: 30,
                                          ),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (value, meta) {
                                              return Text(
                                                '\$${value.toInt()}',
                                                style: const TextStyle(fontSize: 10),
                                              );
                                            },
                                            reservedSize: 40,
                                          ),
                                        ),
                                        rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                      ),
                                      barTouchData: BarTouchData(
                                        touchTooltipData: BarTouchTooltipData(
                                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                            return BarTooltipItem(
                                              '${_xAxisLabels[group.x]}\n${rod.toY >= 0 ? 'Profit' : 'Loss'}: \$${rod.toY.abs().toStringAsFixed(2)}',
                                              const TextStyle(color: Colors.white),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildProfitIndicator(bool isProfit) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isProfit ? Colors.green : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isProfit ? 'Profit' : 'Cancel',
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 40,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 28,
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

  Widget _buildProfitCard({required double profit}) {
    Color profitColor = profit >= 0 ? Colors.green.shade700 : Colors.red.shade700;
    String profitText = profit >= 0 ? 'Profit' : 'Loss';
    IconData profitIcon = profit >= 0 ? Icons.attach_money : Icons.money_off;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Icon(
              profitIcon,
              color: profitColor,
              size: 40,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Net $profitText',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${profit.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 28,
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