import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:restaurant_inventory/alertDialog/customDialog.dart';
import 'package:restaurant_inventory/api/apiClass.dart';
import '../alertDialog/customDialog.dart';
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
    customdialog= customDialog(context);
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

      // Reset profit/loss data
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

      // Calculate profit percentage
      if (_totalSales > 0) {
        _profitPercentage = (_profit / _totalSales).abs().clamp(0.0, 1.0);
      }

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

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error calculating metrics: $e');
      setState(() {
        _isLoading = false;
        _totalSales = 0.0;
        _totalCosting = 0.0;
        _profit = 0.0;
        _profitPercentage = 0.0;
        _profitLossData[0]['value'] = 0;
        _profitLossData[1]['value'] = 0;
      });
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          children: [

            // Chart and summary section
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Card(
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
                                  fontSize: 14,
                                  fontWeight: FontWeight.w300,
                                  color:Color(0x341771).withOpacity(1.0),

                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _selectDate(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                foregroundColor: Colors.white,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [

                                  Text(
                                    DateFormat('yyyy-MM-dd').format(_selectedDate),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.calendar_today,size: 16,),
                                  const Icon(Icons.arrow_drop_down),

                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildChartGraph(isSmallScreen: isSmallScreen),
                    const SizedBox(height: 20),
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

                    ElevatedButton(
                      onPressed: () => syncDataToGoogleSheets(_selectedDate),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_upload, size: 16),
                          SizedBox(width: 8),
                          Text('Sync to Google Sheets'),
                        ],
                      ),
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

  Widget _buildChartGraph({required bool isSmallScreen}) {
    return Container(
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

          // Circular chart
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
  Future<void> syncDataToGoogleSheets(DateTime selectedDate) async {
    try {
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
      print("All Costing");
      print(allCosting);
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
        'costingRecords': filteredCosting
      });

    } catch (e) {
      print('Error syncing data: $e');
      rethrow;
    }
  }
  List<Map<String, dynamic>> _prepareDailySummaries(
      List<Map<String, dynamic>> sales,
      List<Map<String, dynamic>> costingRecords
      ) {
    final dailySummaries = <Map<String, dynamic>>[];
    final dateSalesMap = <String, double>{};
    final dateCostingMap = <String, double>{};
    final formatter = DateFormat('ddMMMyyyy');
    final dailySellId = formatter.format(_selectedDate);

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

    // Combine all unique dates (should only be one date in this case)
    final allDates = {...dateSalesMap.keys, ...dateCostingMap.keys};

    // Create summary for each date
    for (var date in allDates) {
      final salesAmount = dateSalesMap[date] ?? 0;
      final costingAmount = dateCostingMap[date] ?? 0;
      final netAmount = salesAmount - costingAmount;
      print('dailySellId: $dailySellId date: $date salesAmount: $salesAmount costingAmount: $costingAmount netAmount: $netAmount',);
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
      // Create HTTP client
      final client = http.Client();

      try {
        // Initial POST request
        http.Response response = await client.post(
          Uri.parse(apiClass.baseUrlSell),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'action': 'syncLocalData',
            'data': data,
          }),
        ).timeout(const Duration(seconds: 30));

        print('Initial Response Status Code: ${response.statusCode}');
        print('Initial Response Body: ${response.body}');

        // Handle redirect (302, 301, etc.)
        if (response.statusCode == HttpStatus.found ||
            response.statusCode == HttpStatus.movedPermanently ||
            response.statusCode == HttpStatus.seeOther ||
            response.statusCode == HttpStatus.temporaryRedirect) {

          final String? newLocation = response.headers['location'];
          if (newLocation != null) {
            print('Redirecting to: $newLocation');

            // Follow the redirect with a GET request
            response = await client.get(
              Uri.parse(newLocation),
              headers: {
                'Content-Type': 'application/json',
              },
            ).timeout(const Duration(seconds: 30));

            print('Redirected Response Status Code: ${response.statusCode}');
            print('Redirected Response Body: ${response.body}');
          }
        }

        // Process the final response
        if (response.statusCode == 200) {
          final responseBody = jsonDecode(response.body);
          if (responseBody['status'] == 'success') {
            customdialog.dismiss();
            print('Data synced successfully');
          } else {
            customdialog.dismiss();
            throw Exception('Server error: ${responseBody['message']}');
          }
        } else {
          customdialog.dismiss();
          throw Exception('Failed to sync sales data: ${response.statusCode} - ${response.body}');
        }
      } on TimeoutException {
        customdialog.showError('sync data failed', 'Request timed out'  );
        throw Exception('Request timed out');
      } catch (e) {
        customdialog.dismiss();
        rethrow;
      } finally {
        customdialog.dismiss();
        client.close();
      }
    } on http.ClientException catch (e) {
      customdialog.showError("sync data failed","Network error: ${e.message}");
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      customdialog.dismiss();
      throw Exception('Failed to sync data: $e');
    }
  }
}
