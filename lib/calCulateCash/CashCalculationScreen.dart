import 'dart:async';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:restaurant_inventory/alertDialog/customDialog.dart';
import 'package:restaurant_inventory/api/apiClass.dart';
import 'package:sqflite/sqflite.dart';
import '../localDB/DBHelper.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  late customDialog customdialog;
  String dailySellId = '';
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
    customdialog = customDialog(context);
    syncDataChecker();
  }

  Future<void> syncDataChecker() async {
    final localData = await DBHelper.getMenuItems();
    if (localData.isEmpty) {
      await fetchAndSaveMenuItems();
    } else {
      _loadAllDataAndCalculateMetrics(_selectedDate);
    }
  }

  Future<void> fetchAndSaveMenuItems() async {
    customdialog.showLoading('Syncing Data...', subtitle: 'Please wait');
    try {
      final stopwatch = Stopwatch()..start();
      final res = await http
          .get(Uri.parse('${apiClass.baseUrlFoodList}?action=getMenuAllItems'))
          .timeout(const Duration(seconds: 180));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final List items = json['data']['items'];
        await DBHelper.clearMenuItems();
        await DBHelper.insertMenuItems(List<Map<String, dynamic>>.from(items));
        _loadAllDataAndCalculateMetrics(_selectedDate);
      } else {
        customdialog.showError('Sync failed', 'Please try again');
      }
    } on TimeoutException {
      customdialog.showError('Sync failed', 'The request timed out');
    } catch (e) {
      customdialog.showError('Sync failed', 'An error occurred');
    } finally {
      customdialog.dismiss();
    }
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

      // Calculate sales
      for (var sale in allSales) {
        try {
          final saleDate = DateFormat('MM/dd/yyyy').parse(sale['date']);
          if (dateFormat.format(saleDate) == selectedDateString) {
            _totalSales += (sale['total'] as num).toDouble();
          }
        } catch (e) {
          print('Error parsing sale date: $e');
        }
      }

      // Calculate costing
      for (var record in allCosting) {
        if (record['date'] == selectedDateString) {
          _totalCosting += (record['amount'] as num).toDouble();
        }
      }

      _profit = _totalSales - _totalCosting;
      _profitPercentage = _totalSales > 0 ? (_profit / _totalSales).abs().clamp(0.0, 1.0) : 0.0;

      // Update profit/loss data
      if (_profit >= 0) {
        _profitLossData[0]['value'] = _profit;
      } else {
        _profitLossData[1]['value'] = _profit.abs();
      }

      // Prepare chart data
      _barGroups = [
        BarChartGroupData(
          x: 0,
          barRods: [
            BarChartRodData(
              toY: _profit,
              color: _profit >= 0 ? Colors.green : Colors.red,
              width: 30,
              borderRadius: BorderRadius.zero,
            )
          ],
        )
      ];

      _xAxisLabels = [DateFormat('MM/dd').format(date)];
      _minY = _profit < 0 ? _profit * 1.1 : 0;
      _maxY = _profit > 0 ? _profit * 1.1 : 0;

    } catch (e) {
      print('Error calculating metrics: $e');
    } finally {
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
        title: const Text('Daily Summary'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _isLoading = true);
              syncDataChecker();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildChartGraph(isSmallScreen: isSmallScreen),
                    const SizedBox(height: 16),
                    _buildDateSelector(context, isSmallScreen),
                    const SizedBox(height: 16),
                    _buildSummaryCards(isSmallScreen),
                    const SizedBox(height: 16),
                    _buildSyncButton(isSmallScreen),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context, bool isSmallScreen) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 10.0 : 14.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Selected Date:',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.w300,
                  color: const Color(0xFF341771),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => _selectDate(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: isSmallScreen ? 8 : 12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('yyyy-MM-dd').format(_selectedDate),
                    style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.calendar_today, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(bool isSmallScreen) {
    return Column(
      children: [
        _buildSummaryCard(
          title: 'Total Sales (${DateFormat('MM/dd/yyyy').format(_selectedDate)})',
          amount: _totalSales,
          color: Colors.green,
          icon: Icons.trending_up,
          isSmallScreen: isSmallScreen,
        ),
        const SizedBox(height: 12),
        _buildSummaryCard(
          title: 'Total Costing (${DateFormat('MM/dd/yyyy').format(_selectedDate)})',
          amount: _totalCosting,
          color: Colors.red,
          icon: Icons.trending_down,
          isSmallScreen: isSmallScreen,
        ),
        const SizedBox(height: 12),
        _buildProfitCard(
          profit: _profit,
          isSmallScreen: isSmallScreen,
        ),
      ],
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
        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
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
    final profitColor = profit >= 0 ? Colors.green.shade700 : Colors.red.shade700;
    final profitText = profit >= 0 ? 'Profit' : 'Loss';
    final profitIcon = profit >= 0 ? Icons.attach_money : Icons.money_off;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
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

  Widget _buildChartGraph({required bool isSmallScreen}) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
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
            'Daily Profit or Loss Percentage',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('MMM dd, yyyy').format(_selectedDate),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          CircularPercentIndicator(
            radius: isSmallScreen ? 70.0 : 90.0,
            lineWidth: 12.0,
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
            backgroundColor: Colors.white,
            circularStrokeCap: CircularStrokeCap.round,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _profitLossData.map((data) {
              return Column(
                children: [
                  Row(
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
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncButton(bool isSmallScreen) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => syncDataToGoogleSheets(_selectedDate),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16 : 24,
            vertical: isSmallScreen ? 12 : 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.cloud_upload, size: 20),
        label: Text(
          'Sync to Google Sheets',
          style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
        ),
      ),
    );
  }

  Future<void> syncDataToGoogleSheets(DateTime selectedDate) async {
    try {

      final dbClient = await DBHelper.db;
      final existingId = await dbClient.query('localCalculateCash_cache', where: 'id = ?', whereArgs: [dailySellId]);
      if (existingId.isNotEmpty) {
        customdialog.showError('Sync Failed', 'ID $dailySellId already exists. Please contact the administrator.');
        return;
      } else {
        final dateFormat = DateFormat('yyyy-MM-dd');
        final selectedDateString = dateFormat.format(selectedDate);

        final allSales = await DBHelper.getAllSalesWithItems();
        final allCosting = await DBHelper.getCostingRecords();

        final filteredSales = allSales.where((sale) {
          try {
            final saleDate = DateFormat('MM/dd/yyyy').parse(sale['date']);
            return dateFormat.format(saleDate) == selectedDateString;
          } catch (e) {
            print('Error parsing sale date: $e');
            return false;
          }
        }).toList();

        final filteredCosting = allCosting.where((record) {
          return record['date'] == selectedDateString;
        }).toList();

        final salesData = filteredSales.map((sale) {
          return {
            'saleRecord': {
              'id': sale['id'],
              'date': sale['date'],
              'total': sale['total'],
              'discount': sale['discount'],
              'paymentMethod': sale['paymentMethod'],
              'paymentStatus': sale['paymentStatus'],
            },
            'saleItems': (sale['items'] as List).map((item) {
              return {
                'saleId': item['saleId'],
                'menuItemId': item['menuItemId'],
                'name': item['name'],
                'quantity': item['quantity'],
                'price': item['price'],
                'total': item['total'],
              };
            }).toList(),
          };
        }).toList();

        final dailySummaries = _prepareDailySummaries(filteredSales, filteredCosting);

        await _sendSalesDataToGoogleSheets({
          'salesData': salesData,
          'dailySummaries': dailySummaries,
          'costingRecords': filteredCosting,
        });
      }
    } catch (e) {
      print('Error syncing data: $e');
      rethrow;
    }
  }

  List<Map<String, dynamic>> _prepareDailySummaries(
      List<Map<String, dynamic>> sales,
      List<Map<String, dynamic>> costingRecords) {
    final dailySummaries = <Map<String, dynamic>>[];
    final dateSalesMap = <String, double>{};
    final dateCostingMap = <String, double>{};
    final formatter = DateFormat('ddMMMyyyy');
     dailySellId = formatter.format(_selectedDate);

    // Calculate total sales per day
    for (var sale in sales) {
      try {
        final saleDate = DateFormat('MM/dd/yyyy').parse(sale['date']);
        final dateKey = DateFormat('yyyy-MM-dd').format(saleDate);
        dateSalesMap[dateKey] = (dateSalesMap[dateKey] ?? 0) + (sale['total'] as num).toDouble();
      } catch (e) {
        print('Error parsing sale date: $e');
      }
    }

    // Calculate total costing per day
    for (var record in costingRecords) {
      final dateKey = record['date'];
      dateCostingMap[dateKey] = (dateCostingMap[dateKey] ?? 0) + (record['amount'] as num).toDouble();
    }

    // Combine all unique dates
    final allDates = {...dateSalesMap.keys, ...dateCostingMap.keys};

    // Create summary for each date
    for (var date in allDates) {
      final salesAmount = dateSalesMap[date] ?? 0;
      final costingAmount = dateCostingMap[date] ?? 0;
      final netAmount = salesAmount - costingAmount;

      dailySummaries.add({
        'id': dailySellId,
        'date': date,
        'salesAmount': salesAmount,
        'costingAmount': costingAmount,
        'netAmount': netAmount,
        'lossAmount': netAmount < 0 ? netAmount.abs() : 0,
      });
    }

    return dailySummaries;
  }

  Future<void> _sendSalesDataToGoogleSheets(Map<String, dynamic> data) async {
    try {
      customdialog.showLoading('Syncing Data...', subtitle: 'Please wait');
      final client = http.Client();

      try {
        http.Response response = await client.post(
          Uri.parse(apiClass.baseUrlSell),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': 'syncLocalData',
            'data': data,
          }),
        ).timeout(const Duration(seconds: 30));

        // Handle redirect
        if (response.statusCode == HttpStatus.found ||
            response.statusCode == HttpStatus.movedPermanently ||
            response.statusCode == HttpStatus.seeOther ||
            response.statusCode == HttpStatus.temporaryRedirect) {
          final String? newLocation = response.headers['location'];
          if (newLocation != null) {
            response = await client.get(
              Uri.parse(newLocation),
              headers: {'Content-Type': 'application/json'},
            ).timeout(const Duration(seconds: 30));
          }
        }
        if (response.statusCode == 200) {
          final responseBody = jsonDecode(response.body);
          if (responseBody['status'] == 'success') {
            customdialog.showSuccess('Sync Successful', 'Data synced to Google Sheets');

            final dbClient = await DBHelper.db;
            await dbClient.insert('localCalculateCash_cache',
                {
              'id': dailySellId,
            }, conflictAlgorithm: ConflictAlgorithm.replace).then((value) async {
              customdialog.showSuccess('Sync Successful', 'Data synced to Google Sheets and added to local cache successfully');
             await DBHelper.clearAllTables();
              syncDataChecker();
            }).catchError((e) {
              customdialog.showError('Sync Failed', 'Failed to add to local cache');
              throw Exception('Failed to add to local cache: $e');
            });

          } else {
            throw Exception('Server error: ${responseBody['message']}');
          }
        } else {
          throw Exception('Failed to sync data: ${response.statusCode}');
        }
      } on TimeoutException {
        customdialog.showError('Sync Failed', 'Request timed out');
        throw Exception('Request timed out');
      } finally {
        client.close();
      }
    } on http.ClientException catch (e) {
      customdialog.showError('Sync Failed', 'Network error: ${e.message}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      customdialog.showError('Sync Failed', 'An error occurred');
      throw Exception('Failed to sync data: $e');
    }
  }
}