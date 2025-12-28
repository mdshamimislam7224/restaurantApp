import 'package:flutter/material.dart';

import 'financial_ApiService.dart';

class ListIncomeScreen extends StatefulWidget {
  @override
  State<ListIncomeScreen> createState() => _ListIncomeScreenState();
}

class _ListIncomeScreenState extends State<ListIncomeScreen> {
  List data = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  fetchData() async {
    data = await financial_ApiService.getList("Income");
    print(data);
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Income List")),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: data.length,
        itemBuilder: (_, i) => ListTile(
          title: Text(data[i]["Source"].toString()),
          subtitle: Text("Amount: ${data[i]["Amount"]}"),
        ),
      ),
    );
  }
}
