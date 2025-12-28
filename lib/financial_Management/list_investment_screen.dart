import 'package:flutter/material.dart';

import 'financial_ApiService.dart';

class ListInvestmentScreen extends StatefulWidget {
  @override
  State<ListInvestmentScreen> createState() => _ListInvestmentScreenState();
}

class _ListInvestmentScreenState extends State<ListInvestmentScreen> {
      List data = [];
      bool loading = true;
  @override
  void initState() {
    super.initState();
    fetchData();
  }
  fetchData() async {
    data = await financial_ApiService.getList("Investment");
    print(data);
    setState(() => loading = false);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Investment List")),
      body: ListView.builder(
        itemCount: data.length,
        itemBuilder: (_, i) => ListTile(
          title: Text(data[i]["Source"]),
          subtitle: Text("Amount: ${data[i]["Amount"]}"),
        ),
      ),
    );
  }
}
