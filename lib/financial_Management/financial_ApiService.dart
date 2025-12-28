import 'dart:convert';
import 'package:http/http.dart' as http;

class financial_ApiService {
  static const String baseUrl = "https://script.google.com/macros/s/AKfycbwY8NdNvZXtXsFydXp27Nr_C9W7jHMcUKr1gTMbCnIGWPFZ9E-IdLF0_IB1ZTsocInkRg/exec";

  static Future<bool> addIncome(String source, String description, String amount, String method) async {
    final body = {
      "type": "income",
      "source": source,
      "description": description,
      "amount": amount,
      "method": method,
    };

    final res = await http.post(Uri.parse(baseUrl), body: jsonEncode(body));
    print('Status Code: ${res.statusCode}');
    print('Response Body: ${res.body}');
    return res.statusCode == 200;
  }
  static Future<bool> addExpense(String category, String description, String amount, String method) async {
    final body = {
      "type": "expense",
      "category": category,
      "description": description,
      "amount": amount,
      "method": method,
    };
    final res = await http.post(Uri.parse(baseUrl), body: jsonEncode(body));
    print('Status Code: ${res.statusCode}');
    print('Response Body: ${res.body}');
    return res.statusCode == 200;
  }

  static Future<bool> addInvestment(String source, String description, String amount, String method) async {
    final body = {
      "type": "investment",
      "source": source,
      "description": description,
      "amount": amount,
      "method": method,
    };
    final res = await http.post(Uri.parse(baseUrl), body: jsonEncode(body));

    return res.statusCode == 200;
  }
  static Future<List<dynamic>> getList(String sheet) async {
    final res = await http.get(Uri.parse("$baseUrl?sheet=$sheet"));
    if (res.statusCode == 200) {
      try {
        return jsonDecode(res.body);
      } catch (e) {
        print("Response Body: ${res.body}");
        return [];
      }
    }
    return [];
  }

}
