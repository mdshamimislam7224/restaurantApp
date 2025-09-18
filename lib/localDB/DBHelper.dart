import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDB();
    return _db!;
  }

  static Future<Database> initDB() async {
    final path = join(await getDatabasesPath(), 'restaurant.db');
    return openDatabase(
      path,
      version: 1, // 🔁 bump version if already using v1
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE menu_items(
          id INTEGER PRIMARY KEY,
          name TEXT,
          price REAL,
          categoryId INTEGER,
          categoryName TEXT
        )
      ''');

        await db.execute('''
        CREATE TABLE sales(
          id TEXT PRIMARY KEY,
          date TEXT,
          total REAL,
          discount REAL,
          paymentMethod TEXT,
          paymentStatus TEXT
        )
      ''');

        await db.execute('''
        CREATE TABLE sales_items(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          saleId TEXT,
          menuItemId INTEGER,
          name TEXT,
          quantity INTEGER,
          price REAL,
          total REAL,
          FOREIGN KEY (saleId) REFERENCES sales(id)
        )
      ''');
        await db.execute('''
        CREATE TABLE costing_records(
          id TEXT PRIMARY KEY,
          date TEXT,
          type TEXT,
          description TEXT,
          amount REAL,
          paymentStatus TEXT
        )
      ''');

        await db.execute('''
    CREATE TABLE staff_signup (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    nid TEXT,
    phone TEXT,
    position TEXT,
    present_address TEXT,
    permanent_address TEXT,
    salary TEXT,
    staff_id TEXT,
    join_date TEXT,
    email TEXT,
    guardian_info TEXT,
    info TEXT,
    profileImage TEXT, -- base64 string
    imagesData TEXT -- base64 list (JSON encoded)
  )
''');
        await db.execute('''
        CREATE TABLE staff_basic_cache (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          staff_id TEXT,
          name TEXT,
          salary TEXT
        )
      ''');
        await db.execute('''
        CREATE TABLE localCalculateCash_cache (
          id TEXT PRIMARY KEY
        )
      ''');
      },
    );
  }

  // DBHelper.dart
  static Future<List<Map<String, dynamic>>> getAllSalesWithItems() async {
    final dbClient = await db;
    List<Map<String, dynamic>> sales = await dbClient.query('sales');

    List<Map<String, dynamic>> salesWithItems = [];

    for (var sale in sales) {
      String saleId = sale['id'];

      // Get items for each sale
      List<Map<String, dynamic>> items = await dbClient.query(
        'sales_items',
        where: 'saleId = ?',
        whereArgs: [saleId],
      );

      // Append items into the sale map
      Map<String, dynamic> saleWithItems = Map<String, dynamic>.from(sale);
      saleWithItems['items'] = items;

      salesWithItems.add(saleWithItems);
    }

    return salesWithItems;
  }

  static Future<void> insertMenuItems(List<Map<String, dynamic>> items) async {
    final dbClient = await db;
    final batch = dbClient.batch();
    for (var item in items) {
      batch.insert('menu_items', item,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getMenuItems() async {
    final dbClient = await db;
    return await dbClient.query('menu_items');
  }

  static Future<void> saveSale({
    required String sale_ID,
    required String date,
    required double total,
    required double discount,
    required String paymentMethod,
    required String paymentStatus,
    required List<Map<String, dynamic>> items,
  }) async {
    final dbClient = await db;

    await dbClient.transaction((txn) async {
      // 1. Insert into `sales`
      int saleId = await txn.insert('sales', {
        'id': sale_ID,
        'date': date,
        'total': total,
        'discount': discount,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
      });

      // 2. Insert each item into `sales_items`
      for (var item in items) {
        await txn.insert('sales_items', {
          'saleId': sale_ID,
          'menuItemId': item['id'],
          'name': item['name'],
          'quantity': item['quantity'],
          'price': item['price'],
          'total': item['total'],
        });
      }
    });
  }

  static Future<List<Map<String, dynamic>>> getSales() async {
    final dbClient = await db;
    return await dbClient.query('sales', orderBy: 'date DESC');
  }

  static Future<void> deleteSaleById(String id) async {
    final dbClient = await db;
    await dbClient.delete('sales_items', where: 'saleId = ?', whereArgs: [id]);
    await dbClient.delete('sales', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateFullSale({
    required String id,
    required String paymentMethod,
    required String paymentStatus,
    required double discount,
    required double total,
    required List<Map<String, dynamic>> items,
  }) async {
    final dbClient = await db;

    await dbClient.transaction((txn) async {
      // 1. Update `sales` table
      await txn.update(
        'sales',
        {
          'discount': discount,
          'total': total,
          'paymentMethod': paymentMethod,
          'paymentStatus': paymentStatus,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      // 2. Delete old `sales_items`
      await txn.delete('sales_items', where: 'saleId = ?', whereArgs: [id]);

      // 3. Insert updated `sales_items`
      for (var item in items) {
        await txn.insert('sales_items', {
          'saleId': id,
          'menuItemId': item['id'],
          'name': item['name'],
          'quantity': item['quantity'],
          'price': item['price'],
          'total': item['total'],
        });
      }
    });
  }

  static Future<void> updatePaymentStatus({
    required String id,
    required String paymentStatus,
  }) async {
    final db = await DBHelper.db;
    await db.update(
      'sales',
      {'paymentStatus': paymentStatus},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> clearMenuItems() async {
    final dbClient = await db;
    await dbClient.delete('menu_items');
  }

  // Costing Db
  static Future<void> insertCostingRecord({
    required String id,
    required String date,
    required String type,
    required String description,
    required double amount,
    required String paymentStatus,
  }) async {
    final dbClient = await db;
    await dbClient.insert('costing_records', {
      'id': id,
      'date': date,
      'type': type,
      'description': description,
      'amount': amount,
      'paymentStatus': paymentStatus,
    });
  }

  static Future<List<Map<String, dynamic>>> getCostingRecords() async {
    final dbClient = await db;
    return await dbClient.query('costing_records', orderBy: 'date DESC');
  }

  static Future<void> deleteCostingRecord(int id) async {
    final dbClient = await db;
    await dbClient.delete('costing_records', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateCostingRecord({
    required int id,
    required String date,
    required String type,
    required String description,
    required double amount,
    required String paymentStatus,
  }) async {
    final dbClient = await db;
    await dbClient.update(
      'costing_records',
      {
        'date': date,
        'type': type,
        'description': description,
        'amount': amount,
        'paymentStatus': paymentStatus,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> updateCostingPaymentStatus({
    required int id,
    required String paymentStatus,
  }) async {
    final db = await DBHelper.db;
    await db.update(
      'costing_records',
      {'paymentStatus': paymentStatus},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  //Staff Sign Up (Add Staff)
  static Future<bool> insertStaff(Map<String, dynamic> staffData) async {
    try {
      final db = await DBHelper.db;

      // Convert images to JSON strings
      final profileImageJson = jsonEncode(staffData['profileImage']);
      final imagesDataJson = jsonEncode(staffData['imagesData']);

      final result = await db.insert('staff_signup', {
        'name': staffData['name'],
        'nid': staffData['nid'],
        'phone': staffData['phone'],
        'position': staffData['position'],
        'present_address': staffData['present_address'],
        'permanent_address': staffData['permanent_address'],
        'salary': staffData['salary'],
        'staff_id': staffData['staff_id'],
        'join_date': staffData['join_date'],
        'email': staffData['email'],
        'guardian_info': staffData['guardian_info'],
        'info': staffData['info'],
        'profileImage': profileImageJson,
        'imagesData': imagesDataJson,
      });

      return result > 0; // true if insert succeeded
    } catch (e) {
      print('Insert Error: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getAllStaff() async {
    final db = await DBHelper.db;
    // First get all basic info without images
    final basicInfoList = await db.query('staff_signup', columns: [
      'id',
      'name',
      'nid',
      'phone',
      'position',
      'present_address',
      'permanent_address',
      'salary',
      'staff_id',
      'join_date',
      'email',
      'guardian_info',
      'info'
    ]);
    return basicInfoList;
  }

  static Future<void> clearAllStaff() async {
    final dbClient = await db;
    await dbClient.delete('staff_signup');
  }

  static Future<int> updateStaff(int id, Map<String, dynamic> newData) async {
    final db = await DBHelper.db;

    final profileImageJson = jsonEncode(newData['profileImage']);
    final imagesDataJson = jsonEncode(newData['imagesData']);
    return await db.update(
      'staff_signup',
      {
        'name': newData['name'],
        'nid': newData['nid'],
        'phone': newData['phone'],
        'position': newData['position'],
        'present_address': newData['present_address'],
        'permanent_address': newData['permanent_address'],
        'salary': newData['salary'],
        'staff_id': newData['staff_id'],
        'join_date': newData['join_date'],
        'email': newData['email'],
        'guardian_info': newData['guardian_info'],
        'info': newData['info'],
        'profileImage': profileImageJson,
        'imagesData': imagesDataJson,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> deleteStaff(int id) async {
    final db = await DBHelper.db;
    await db.delete('staff_signup', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Map<String, dynamic>>> getAllCachedStaff() async {
    final dbClient = await db;
    return await dbClient.query('staff_basic_cache', orderBy: 'staff_id ASC');
  }

  static Future<void> clearAllTables() async {
    final dbClient = await db;
    try {
      await dbClient.transaction((txn) async {
        // List all your tables here
        const tables = [
          'sales',
          'sales_items',
          'costing_records',
          // 'staff_basic_cache',
        ];

        // Delete all data from each table
        for (final table in tables) {
          await txn.delete(table);
        }
      });
    } catch (e) {
      debugPrint('Error clearing tables: $e');
      rethrow;
    }
  }
}
