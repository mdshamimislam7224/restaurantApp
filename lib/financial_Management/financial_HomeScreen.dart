import 'package:flutter/material.dart';
import 'package:restaurant_inventory/financial_Management/financial_add_income_screen.dart';
import 'package:restaurant_inventory/financial_Management/financial_add_investment_screen.dart';
import 'package:restaurant_inventory/financial_Management/financialadd_expense_screen.dart';

import 'list_expense_screen.dart';
import 'list_income_screen.dart';
import 'list_investment_screen.dart';

class financial_HomeScreen extends StatelessWidget {
  const financial_HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Restaurant Accounts")),
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2,
        children: [
          _menu(context, "Add Income", financial_add_income_screen()),
          _menu(context, "Add Expense", financialadd_expense_screen()),
          _menu(context, "Add Investment", financial_add_investment_screen()),
          _menu(context, "Income List", ListIncomeScreen()),
          _menu(context, "Expense List", ListExpenseScreen()),
          _menu(context, "Investment List", ListInvestmentScreen()),
        ],
      ),
    );
  }

  Widget _menu(BuildContext context, String title, Widget page) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Card(
        child: Center(child: Text(title, textAlign: TextAlign.center)),
      ),
    );
  }
}
