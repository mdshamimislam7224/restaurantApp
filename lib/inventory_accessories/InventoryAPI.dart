import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;

import 'model/InventoryItem.dart';

class InventoryAPI {
  static const String BASE_URL = 'https://script.google.com/macros/s/AKfycbwmcKPQv_CUvv2eIJignVBu1ytBx3Q3ZoCsIvbzg7JcbFWLMn-DZqXGUm4vKijIQRy_/exec'; //

  // Helper method to handle Google Apps Script redirects
  static Future<http.Response> _makePostRequest(Map<String, dynamic> body) async {
    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse(BASE_URL))
        ..followRedirects = false // [cite: 67]
        ..headers.addAll({'Content-Type': 'application/json'})
        ..body = jsonEncode(body);

      var response = await http.Response.fromStream(await client.send(request)); // [cite: 68, 69]

      if (response.statusCode >= 300 && response.statusCode < 400) {
        final String? redirectUrl = response.headers['location']; // [cite: 70, 71]
        if (redirectUrl != null) {
          response = await client.get(Uri.parse(redirectUrl)); // [cite: 72]
        }
      }
      return response; // [cite: 79]
    } finally {
      client.close(); // [cite: 80]
    }
  }

  // Get all items
  static Future<List<InventoryItem>> getAllItems() async {
    try {
      final response = await _makePostRequest({
        'endpoint': 'getAll',
      });
      print('📊 getAll response status: ${response.statusCode}');
      print('📊 getAll response headers: ${response.headers}');
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          print('📊 getAll response: $data');

          if (data['success'] == true) {
            List items = data['data'] ?? [];
            return items.map((item) => InventoryItem.fromJson(item)).toList();
          } else {
            print('❌ API returned success: false: ${data['error']}');
            return [];
          }
        } catch (e) {
          print('❌ JSON parsing error: $e');
          print('Raw response: ${response.body}');
          return [];
        }
      } else {
        print('❌ HTTP Error ${response.statusCode}: ${response.reasonPhrase}');
        print('Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching inventory: $e');
      return [];
    }
  }

  // Add item with image
  static Future<Map<String, dynamic>> addItemWithImage({
    required String name,
    required String category,
    required int quantity,
    required List<Map<String, String>> images,
    String location = 'Storage',
    String status = 'Good',
    String notes = '',
  }) async {
    try {
      final response = await _makePostRequest({
        'endpoint': 'addItem',
        'name': name,
        'category': category,
        'quantity': quantity,
        'location': location,
        'status': status,
        'notes': notes,
        'images': images, // [cite: 89]
      });
      print('📊 addItemWithImage response: ${response.body}');
      print('📊 addItemWithImage statusCode: ${response.statusCode}');
      return json.decode(response.body); // [cite: 91]
    } catch (e) {
      return {'success': false, 'error': e.toString()}; // [cite: 94]
    }
  }

  // Simple test function
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await _makePostRequest({
        'endpoint': 'test',
      });

      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Helper to convert XFile to your image object format
  static Future<List<Map<String, String>>> convertImagesToFormat(List<XFile> imageFiles) async {
    List<Map<String, String>> images = [];

    for (var imageFile in imageFiles) {
      try {
        final bytes = await imageFile.readAsBytes();
        final base64String = base64Encode(bytes);

        // Determine MIME type
        String mimeType = 'image/jpeg';
        final path = imageFile.path.toLowerCase();
        if (path.endsWith('.png')) {
          mimeType = 'image/png';
        } else if (path.endsWith('.gif')) {
          mimeType = 'image/gif';
        } else if (path.endsWith('.webp')) {
          mimeType = 'image/webp';
        }

        images.add({
          'data': base64String,
          'mimeType': mimeType,
          'fileName': imageFile.name.split('/').last,
        });

        print('📸 Converted image: ${imageFile.name}, size: ${bytes.length} bytes');
      } catch (e) {
        print('❌ Error converting image: $e');
      }
    }

    return images;
  }

  // Update quantity
  static Future<Map<String, dynamic>> updateQuantity({
    required String itemId,
    required int newQuantity,
  }) async {
    try {
      final response = await _makePostRequest({
        'endpoint': 'updateQuantity',
        'id': itemId,
        'quantity': newQuantity,
      });

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        };
      }
    } catch (e) {
      print('❌ Update quantity error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}