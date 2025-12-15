import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'AttendanceRecord.dart';

class ApiServiceAttendance {
  // Your web app URL
  static const String _baseUrl = 'https://script.google.com/macros/s/AKfycbwflwfYh9f9ihAZMlTjL5uRA-FrX-Vu7aiKeR1Brx0fwlU6d697ZzCKJes1qDGIIw0EYA/exec';

  // ============================================================================
  // ✅ FIXED: POST REQUEST WITH MANUAL REDIRECT HANDLING
  // ============================================================================

  Future<http.Response> _makePostRequest(Map<String, dynamic> body) async {
    final client = http.Client();

    try {
      print('🌐 Making POST request to: $_baseUrl');
      print('📦 Request body: ${jsonEncode(body)}');

      // Step 1: Make initial POST request (don't follow redirects automatically)
      final request = http.Request('POST', Uri.parse(_baseUrl))
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
      if (response.statusCode == HttpStatus.found || // 302
          response.statusCode == HttpStatus.movedPermanently || // 301
          response.statusCode == HttpStatus.movedTemporarily || // 302
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
      if (response.body.length > 500) {
        print('✅ Response (first 500 chars): ${response.body.substring(0, 500)}...');
      } else {
        print('✅ Response: ${response.body}');
      }

      return response;

    } catch (e) {
      print('❌ POST Request error: $e');
      rethrow;
    } finally {
      client.close();
    }
  }

  // ============================================================================
  // API METHODS
  // ============================================================================
  Future<StaffInfo> getStaffInfo(String staffId) async {
    try {
      final response = await _makePostRequest({
        'endpoint': 'getStaffInfo',
        'staffId': staffId,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return StaffInfo.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Failed to get staff info');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('❌ getStaffInfo error: $e');
      rethrow;
    }
  }

  Future<PunchResult> punchAttendance({
    required String staffId,
    required String action,
    required double latitude,
    required double longitude,
    String notes = '',
  }) async {
    try {
      final response = await _makePostRequest({
        'endpoint': 'attendance',
        'staffId': staffId,
        'action': action,
        'latitude': latitude,
        'longitude': longitude,
        'notes': notes,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return PunchResult.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Attendance failed');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('❌ punchAttendance error: $e');
      rethrow;
    }
  }

  Future<AttendanceResponse> getAttendancespecificStaff({
    String? staffId,
    String? startDate,
    String? endDate,
    String? date,
    int? dailyPage,
    int? logPage,
    int? dailyLimit,
    int? logLimit,
  }) async {
    try {
      // Build request body (exactly like Postman)
      final Map<String, dynamic> requestBody = {
        'endpoint': 'getAllAttendance',
        'dailyPage': dailyPage,
        'logPage': logPage,
        'dailyLimit': dailyLimit,
        'logLimit': logLimit,
      };

      // Add optional parameters
      if (staffId != null && staffId.isNotEmpty) {
        requestBody['staffId'] = staffId;
      }
      if (date != null && date.isNotEmpty) {
        requestBody['date'] = date;
      }
      if (startDate != null && startDate.isNotEmpty) {
        requestBody['startDate'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        requestBody['endDate'] = endDate;
      }

      print('📤 Request body: $requestBody');

      // Make POST request with redirect handling
      final response = await _makePostRequest(requestBody);

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);

          if (data['status'] == 'success') {
            print('✅ Successfully parsed attendance data');
            return AttendanceResponse.fromJson(data);
          } else {
            throw Exception(data['message'] ?? 'Failed to get attendance');
          }
        } catch (e) {
          print('❌ JSON Parse error: $e');
          print('📄 Raw response: ${response.body}');
          rethrow;
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('❌ getAllAttendance error: $e');
      rethrow;
    }
  }

  // Test if API is working

  Future<AttendanceResponse> getAllAttendance({
    String? startDate,
    String? endDate,
    String? date,
    int dailyPage = 1,
    int logPage = 1,
    int dailyLimit = 50,
    int logLimit = 50,
  }) async {
    try {
      // Build request body (exactly like Postman)
      final Map<String, dynamic> requestBody = {
        'endpoint': 'getAllAttendance',
        'dailyPage': dailyPage,
        'logPage': logPage,
        'dailyLimit': dailyLimit,
        'logLimit': logLimit,
        "limit": 30
      };

      // Add optional parameters
      if (date != null && date.isNotEmpty) {
        requestBody['date'] = date;
      }
      if (startDate != null && startDate.isNotEmpty) {
        requestBody['startDate'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        requestBody['endDate'] = endDate;
      }

      print('📤 Request body: $requestBody');

      // Make POST request with redirect handling
      final response = await _makePostRequest(requestBody);

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);

          if (data['status'] == 'success') {
            print('✅ Successfully parsed attendance data');
            return AttendanceResponse.fromJson(data);
          } else {
            throw Exception(data['message'] ?? 'Failed to get attendance');
          }
        } catch (e) {
          print('❌ JSON Parse error: $e');
          print('📄 Raw response: ${response.body}');
          rethrow;
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('❌ getAllAttendance error: $e');
      rethrow;
    }
  }

}