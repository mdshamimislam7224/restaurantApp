import 'package:flutter/material.dart';

import 'financial_ApiService.dart';

class ListExpenseScreen extends StatefulWidget {
  @override
  State<ListExpenseScreen> createState() => _ListExpenseScreenState();
}

class _ListExpenseScreenState extends State<ListExpenseScreen> {
  List<Map<String, dynamic>> mockData = List.generate(10, (i) => {"title": "Expense $i", "amount": 500});
  List data = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    fetchData();
  }
  fetchData() async {
    data = await financial_ApiService.getList("Expenses");
    print(data);
    setState(() => loading = false);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Expense List")),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: data.length,
        itemBuilder: (_, i) => ListTile(
          title: Text(data[i]["Category"].toString()),
          subtitle: Text("Amount: ${data[i]["Amount"]}"),
        ),
      ),
    );
  }
}


