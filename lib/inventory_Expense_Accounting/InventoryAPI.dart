import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;

import 'model/InventoryItem.dart';

class InventoryAPI {
  static const String BASE_URL =
      'https://script.google.com/macros/s/AKfycbz60kp8DKfnCJXhKk2vB4QMIsFfiV_9CKhfWWthrY_NMhWlj6hxHjv0qYsQNA3dZ6hp/exec';

  // Get all items
  static Future<List<InventoryItem>> getAllItems() async {
    try {
      final response = await http.get(
          Uri.parse('$BASE_URL?endpoint=getAll')
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List items = data['data'] ?? [];
          return items.map((item) => InventoryItem.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching inventory: $e');
      return [];
    }
  }

  // Add new item
  // Add item with image
  static Future<Map<String, dynamic>> addItemWithImage({
    required String name,
    required String category,
    required int quantity,
    required String imageBase64, // Base64 image string
    String location = 'Storage',
    String status = 'Good',
    String notes = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$BASE_URL?endpoint=addItem'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'category': category,
          'quantity': quantity,
          'location': location,
          'status': status,
          'notes': notes,
          'imageBase64': imageBase64, // This matches your working pattern
        }),
      );

      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
  // Update quantity
  static Future<Map<String, dynamic>> updateQuantity({
    required String itemId,
    required int newQuantity,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$BASE_URL?endpoint=updateQuantity'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id': itemId,
          'quantity': newQuantity,
        }),
      );

      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}