import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io'; // Add this for HttpStatus constants

class FinancialApiService {
  static const String baseUrl = "https://script.google.com/macros/s/AKfycbzjsyPA1RR3BjXxix59d8XDlSfTcjQ55YS4jmKrtjX9Prmyqd0pezxMdYzIUDboqqeSwQ/exec";

  // =============================
  // Helper: POST request with redirect handling
  // =============================
  static Future<http.Response> _makePostRequest(Map<String, dynamic> body) async {
    final client = http.Client();

    try {
      print('🌐 Making POST request to: $baseUrl');
      print('📦 Request body: ${jsonEncode(body)}');

      // Step 1: Make initial POST request (don't follow redirects automatically)
      final request = http.Request('POST', Uri.parse(baseUrl))
        ..followRedirects = false  // ✅ Don't auto-follow, we'll handle manually
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        })
        ..body = jsonEncode(body);

      var streamedResponse = await client.send(request).timeout(
        const Duration(seconds: 30),
      );

      var response = await http.Response.fromStream(streamedResponse);

      print('📡 Initial Response status: ${response.statusCode}');

      // Step 2: Handle redirects (302, 301, 303, 307, 308)
      if (response.statusCode == HttpStatus.movedTemporarily || // 302
          response.statusCode == HttpStatus.found || // 302
          response.statusCode == HttpStatus.movedPermanently || // 301
          response.statusCode == HttpStatus.seeOther || // 303
          response.statusCode == HttpStatus.temporaryRedirect || // 307
          response.statusCode == 308) { // 308 Permanent Redirect

        final String? redirectUrl = response.headers['location'];

        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          print('🔄 Following redirect to: $redirectUrl');

          // ✅ CRITICAL: Use GET for the redirect (Google Apps Script pattern)
          final redirectResponse = await client.get(
            Uri.parse(redirectUrl),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Mozilla/5.0',
            },
          ).timeout(const Duration(seconds: 30));

          response = redirectResponse;
          print('📡 Redirect Response status: ${response.statusCode}');
        } else {
          throw Exception('Redirect location header is missing');
        }
      }

      // Step 3: Check if response is HTML (error page)
      if (response.body.trim().startsWith('<!DOCTYPE html>') ||
          response.body.trim().startsWith('<HTML>') ||
          response.body.contains('<html>')) {
        print('❌ ERROR: Received HTML instead of JSON');
        print('📄 HTML Preview: ${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}');
        throw Exception('Server returned HTML error page');
      }

      // Step 4: Log successful response
      print('✅ Response (first 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) + "..." : response.body}');

      return response;

    } catch (e) {
      print('❌ POST Request error: $e');
      rethrow;
    } finally {
      client.close();
    }
  }

  // =============================
  // CREATE - Insert Operations (Updated)
  // =============================

  static Future<Map<String, dynamic>> addIncome(
      String source,
      String description,
      String amount,
      String method
      ) async {
    final body = {
      "action": "insert",
      "type": "income",
      "source": source,
      "description": description,
      "amount": amount,
      "method": method,
    };

    try {
      final res = await _makePostRequest(body);

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {"success": false, "error": "Failed to add income. Status: ${res.statusCode}"};
    } catch (e) {
      print('Error adding income: $e');
      return {"success": false, "error": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> addExpense(
      String category,
      String description,
      String amount,
      String method
      ) async {
    final body = {
      "action": "insert",
      "type": "expense",
      "category": category,
      "description": description,
      "amount": amount,
      "method": method,
    };

    try {
      final res = await _makePostRequest(body);

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {"success": false, "error": "Failed to add expense. Status: ${res.statusCode}"};
    } catch (e) {
      print('Error adding expense: $e');
      return {"success": false, "error": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> addInvestment(
      String source,
      String description,
      String amount,
      String method
      ) async {
    final body = {
      "action": "insert",
      "type": "investment",
      "source": source,
      "description": description,
      "amount": amount,
      "method": method,
    };

    try {
      final res = await _makePostRequest(body);

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {"success": false, "error": "Failed to add investment. Status: ${res.statusCode}"};
    } catch (e) {
      print('Error adding investment: $e');
      return {"success": false, "error": e.toString()};
    }
  }

  // =============================
  // READ - Get Operations (GET requests typically don't need redirect handling)
  // =============================

  /// Get list with pagination and filters
  static Future<Map<String, dynamic>> getList({
    required String sheet,
    int page = 1,
    int limit = 10,
    String? searchId,
    String? searchMethod,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = {
        'action': 'list',
        'sheet': sheet,
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (searchId != null && searchId.isNotEmpty) {
        queryParams['searchId'] = searchId;
      }
      if (searchMethod != null && searchMethod.isNotEmpty) {
        queryParams['searchMethod'] = searchMethod;
      }
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['startDate'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['endDate'] = endDate;
      }

      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

      print('Get List URL: $uri');

      final res = await http.get(uri);

      print('Get List - Status: ${res.statusCode}');

      // Check for redirect in GET requests too
      if (res.statusCode >= 300 && res.statusCode < 400) {
        final String? redirectUrl = res.headers['location'];
        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          print('🔄 GET Redirect to: $redirectUrl');
          final redirectRes = await http.get(Uri.parse(redirectUrl));
          print('Redirect Response status: ${redirectRes.statusCode}');

          if (redirectRes.statusCode == 200) {
            return jsonDecode(redirectRes.body);
          }
        }
      }

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {
        "data": [],
        "pagination": {"page": 1, "limit": limit, "total": 0, "totalPages": 0},
        "error": "Failed to fetch data. Status: ${res.statusCode}"
      };
    } catch (e) {
      print('Error getting list: $e');
      return {
        "data": [],
        "pagination": {"page": 1, "limit": limit, "total": 0, "totalPages": 0},
        "error": e.toString()
      };
    }
  }

  /// Get single record by ID
  static Future<Map<String, dynamic>> getRecord({
    required String sheet,
    required String id,
  }) async {
    try {
      final uri = Uri.parse(baseUrl).replace(queryParameters: {
        'action': 'get',
        'sheet': sheet,
        'id': id,
      });

      print('Get Record URL: $uri');

      final res = await http.get(uri);

      print('Get Record - Status: ${res.statusCode}');

      // Handle redirect for GET requests
      if (res.statusCode >= 300 && res.statusCode < 400) {
        final String? redirectUrl = res.headers['location'];
        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          print('🔄 GET Redirect to: $redirectUrl');
          final redirectRes = await http.get(Uri.parse(redirectUrl));
          print('Redirect Response status: ${redirectRes.statusCode}');

          if (redirectRes.statusCode == 200) {
            return jsonDecode(redirectRes.body);
          }
        }
      }

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {"error": "Record not found. Status: ${res.statusCode}"};
    } catch (e) {
      print('Error getting record: $e');
      return {"error": e.toString()};
    }
  }

  // =============================
  // UPDATE Operations (Updated)
  // =============================

  static Future<Map<String, dynamic>> updateIncome({
    required String id,
    String? source,
    String? description,
    String? amount,
    String? method,
    String? date,
  }) async {
    final body = {
      "action": "update",
      "sheet": "Income",
      "id": id,
    };

    if (source != null) body["source"] = source;
    if (description != null) body["description"] = description;
    if (amount != null) body["amount"] = amount;
    if (method != null) body["method"] = method;
    if (date != null) body["date"] = date;

    try {
      final res = await _makePostRequest(body);

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {"success": false, "error": "Failed to update income. Status: ${res.statusCode}"};
    } catch (e) {
      print('Error updating income: $e');
      return {"success": false, "error": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateExpense({
    required String id,
    String? category,
    String? description,
    String? amount,
    String? method,
    String? date,
  }) async {
    final body = {
      "action": "update",
      "sheet": "Expenses",
      "id": id,
    };

    if (category != null) body["category"] = category;
    if (description != null) body["description"] = description;
    if (amount != null) body["amount"] = amount;
    if (method != null) body["method"] = method;
    if (date != null) body["date"] = date;

    try {
      final res = await _makePostRequest(body);

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {"success": false, "error": "Failed to update expense. Status: ${res.statusCode}"};
    } catch (e) {
      print('Error updating expense: $e');
      return {"success": false, "error": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateInvestment({
    required String id,
    String? source,
    String? description,
    String? amount,
    String? method,
    String? date,
  }) async {
    final body = {
      "action": "update",
      "sheet": "Investment",
      "id": id,
    };

    if (source != null) body["source"] = source;
    if (description != null) body["description"] = description;
    if (amount != null) body["amount"] = amount;
    if (method != null) body["method"] = method;
    if (date != null) body["date"] = date;

    try {
      final res = await _makePostRequest(body);

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {"success": false, "error": "Failed to update investment. Status: ${res.statusCode}"};
    } catch (e) {
      print('Error updating investment: $e');
      return {"success": false, "error": e.toString()};
    }
  }

  // =============================
  // DELETE Operations (Updated)
  // =============================

  static Future<Map<String, dynamic>> deleteRecord({
    required String sheet,
    required String id,
  }) async {
    final body = {
      "action": "delete",
      "sheet": sheet,
      "id": id,
    };

    try {
      final res = await _makePostRequest(body);

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {"success": false, "error": "Failed to delete record. Status: ${res.statusCode}"};
    } catch (e) {
      print('Error deleting record: $e');
      return {"success": false, "error": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteIncome(String id) async {
    return deleteRecord(sheet: "Income", id: id);
  }

  static Future<Map<String, dynamic>> deleteExpense(String id) async {
    return deleteRecord(sheet: "Expenses", id: id);
  }

  static Future<Map<String, dynamic>> deleteInvestment(String id) async {
    return deleteRecord(sheet: "Investment", id: id);
  }

  /// Get dashboard summary data
  static Future<Map<String, dynamic>> getDashboardData({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = {
        'action': 'dashboard',
      };

      if (startDate != null && startDate.isNotEmpty) {
        queryParams['startDate'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['endDate'] = endDate;
      }

      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

      print('Get Dashboard URL: $uri');

      final res = await http.get(uri);

      print('Get Dashboard - Status: ${res.statusCode}');

      // Handle redirect for GET requests
      if (res.statusCode >= 300 && res.statusCode < 400) {
        final String? redirectUrl = res.headers['location'];
        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          print('🔄 GET Redirect to: $redirectUrl');
          final redirectRes = await http.get(Uri.parse(redirectUrl));
          print('Redirect Response status: ${redirectRes.statusCode}');

          if (redirectRes.statusCode == 200) {
            return jsonDecode(redirectRes.body);
          }
        }
      }

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {
        "success": false,
        "error": "Failed to fetch dashboard data. Status: ${res.statusCode}"
      };
    } catch (e) {
      print('Error getting dashboard data: $e');
      return {
        "success": false,
        "error": e.toString()
      };
    }
  }

  // Keep legacy getAllRecords method for backward compatibility
  static Future<List<dynamic>> getAllRecords(String sheet) async {
    try {
      final res = await http.get(
          Uri.parse(baseUrl).replace(queryParameters: {
            'action': 'list',
            'sheet': sheet,
            'page': '1',
            'limit': '1000',
          })
      );

      if (res.statusCode == 200) {
        final Map<String, dynamic> response = jsonDecode(res.body);
        return response['data'] ?? [];
      }
      return [];
    } catch (e) {
      print('Error getting all records: $e');
      return [];
    }
  }
}