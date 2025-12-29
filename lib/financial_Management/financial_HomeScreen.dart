import 'package:flutter/material.dart';
import 'financial_add_income_screen.dart';
import 'financial_add_investment_screen.dart';
import 'financialadd_expense_screen.dart';
import 'financial_ApiService.dart';

class financial_HomeScreen extends StatefulWidget {
  const financial_HomeScreen({super.key});

  @override
  State<financial_HomeScreen> createState() => _financial_HomeScreenState();
}

class _financial_HomeScreenState extends State<financial_HomeScreen> {
  bool loading = true;
  Map<String, dynamic> dashboardData = {};

  // Date range filters
  String? startDate;
  String? endDate;
  String dateRangeText = "All Time";

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    setState(() => loading = true);

    final response = await FinancialApiService.getDashboardData(
      startDate: startDate,
      endDate: endDate,
    );

    setState(() {
      if (response['success'] == true) {
        dashboardData = response['data'] ?? {};
      }
      loading = false;
    });
  }

  void _showDateRangeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Select Date Range"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.calendar_today),
              title: Text("All Time"),
              onTap: () {
                setState(() {
                  startDate = null;
                  endDate = null;
                  dateRangeText = "All Time";
                });
                Navigator.pop(context);
                loadDashboardData();
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.today),
              title: Text("Today"),
              onTap: () {
                final today = DateTime.now();
                final todayStr = "${today.month.toString().padLeft(2, '0')}/${today.day.toString().padLeft(2, '0')}/${today.year}";
                setState(() {
                  startDate = todayStr;
                  endDate = todayStr;
                  dateRangeText = "Today";
                });
                Navigator.pop(context);
                loadDashboardData();
              },
            ),
            ListTile(
              leading: Icon(Icons.view_week),
              title: Text("This Week"),
              onTap: () {
                final now = DateTime.now();
                final weekStart = now.subtract(Duration(days: now.weekday - 1));
                final startStr = "${weekStart.month.toString().padLeft(2, '0')}/${weekStart.day.toString().padLeft(2, '0')}/${weekStart.year}";
                final endStr = "${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}";
                setState(() {
                  startDate = startStr;
                  endDate = endStr;
                  dateRangeText = "This Week";
                });
                Navigator.pop(context);
                loadDashboardData();
              },
            ),
            ListTile(
              leading: Icon(Icons.calendar_month),
              title: Text("This Month"),
              onTap: () {
                final now = DateTime.now();
                final monthStart = DateTime(now.year, now.month, 1);
                final startStr = "${monthStart.month.toString().padLeft(2, '0')}/${monthStart.day.toString().padLeft(2, '0')}/${monthStart.year}";
                final endStr = "${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}";
                setState(() {
                  startDate = startStr;
                  endDate = endStr;
                  dateRangeText = "This Month";
                });
                Navigator.pop(context);
                loadDashboardData();
              },
            ),
            ListTile(
              leading: Icon(Icons.date_range),
              title: Text("Custom Range"),
              onTap: () async {
                Navigator.pop(context);
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  final startStr = "${picked.start.month.toString().padLeft(2, '0')}/${picked.start.day.toString().padLeft(2, '0')}/${picked.start.year}";
                  final endStr = "${picked.end.month.toString().padLeft(2, '0')}/${picked.end.day.toString().padLeft(2, '0')}/${picked.end.year}";
                  setState(() {
                    startDate = startStr;
                    endDate = endStr;
                    dateRangeText = "${picked.start.day}/${picked.start.month}/${picked.start.year} - ${picked.end.day}/${picked.end.month}/${picked.end.year}";
                  });
                  loadDashboardData();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String formatCurrency(dynamic amount) {
    try {
      double value = double.parse(amount.toString());
      return "৳${value.toStringAsFixed(2)}";
    } catch (e) {
      return "৳0.00";
    }
  }

  Color getBalanceColor(double balance) {
    if (balance > 0) return Colors.green;
    if (balance < 0) return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Restaurant Accounts"),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showDateRangeDialog,
            tooltip: "Filter by Date",
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: loadDashboardData,
            tooltip: "Refresh",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadDashboardData,
        child: loading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Range Filter Chip
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.blue[700]),
                    SizedBox(width: 8),
                    Text(
                      dateRangeText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[700],
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, size: 20, color: Colors.blue[700]),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Summary Cards Section
              Text(
                "Financial Summary",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 12),

              // Balance Card (Main)
              Card(
                elevation: 4,
                color: getBalanceColor(
                    double.tryParse(dashboardData['balance']?.toString() ?? "0") ?? 0
                ).withOpacity(0.1),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        "Net Balance",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        formatCurrency(dashboardData['balance'] ?? 0),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: getBalanceColor(
                              double.tryParse(dashboardData['balance']?.toString() ?? "0") ?? 0
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Income - Expenses - Investments",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Income, Expense, Investment Summary
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      title: "Income",
                      amount: dashboardData['income']?['total'] ?? 0,
                      count: dashboardData['income']?['count'] ?? 0,
                      color: Colors.green,
                      icon: Icons.arrow_upward,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _summaryCard(
                      title: "Expense",
                      amount: dashboardData['expense']?['total'] ?? 0,
                      count: dashboardData['expense']?['count'] ?? 0,
                      color: Colors.red,
                      icon: Icons.arrow_downward,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              _summaryCard(
                title: "Investment",
                amount: dashboardData['investment']?['total'] ?? 0,
                count: dashboardData['investment']?['count'] ?? 0,
                color: Colors.purple,
                icon: Icons.trending_up,
                fullWidth: true,
              ),

              SizedBox(height: 24),

              // Quick Actions Section
              Text(
                "Quick Actions",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 12),

              // Action Grid
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _actionCard(
                    context,
                    title: "Income",
                    subtitle: "Add & View",
                    icon: Icons.account_balance_wallet,
                    color: Colors.green,
                    page: financial_add_income_screen(),
                  ),
                  _actionCard(
                    context,
                    title: "Expense",
                    subtitle: "Add & View",
                    icon: Icons.shopping_cart,
                    color: Colors.red,
                    page: financialadd_expense_screen(),
                  ),
                  _actionCard(
                    context,
                    title: "Investment",
                    subtitle: "Add & View",
                    icon: Icons.trending_up,
                    color: Colors.purple,
                    page: financial_add_investment_screen(),
                  ),
                  _actionCard(
                    context,
                    title: "Reports",
                    subtitle: "Coming Soon",
                    icon: Icons.bar_chart,
                    color: Colors.blue,
                    page: null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required dynamic amount,
    required int count,
    required Color color,
    required IconData icon,
    bool fullWidth = false,
  }) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.2),
                  radius: 20,
                  child: Icon(icon, color: color, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        formatCurrency(amount),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              "$count transaction${count != 1 ? 's' : ''}",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required Widget? page,
      }) {
    return GestureDetector(
      onTap: () {
        if (page != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => page),
          ).then((_) => loadDashboardData()); // Refresh on return
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("$title feature coming soon!")),
          );
        }
      },
      child: Card(
        elevation: 3,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: color,
                radius: 30,
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}