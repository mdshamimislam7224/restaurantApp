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
          saleId INTEGER,
          menuItemId INTEGER,
          name TEXT,
          quantity INTEGER,
          price REAL,
          total REAL,
          FOREIGN KEY (saleId) REFERENCES sales(id)
        )
      ''');
      },
    );
  }

  static Future<void> insertMenuItems(List<Map<String, dynamic>> items) async {
    final dbClient = await db;
    final batch = dbClient.batch();
    for (var item in items) {
      batch.insert('menu_items', item, conflictAlgorithm: ConflictAlgorithm.replace);
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
          'saleId': saleId,
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





  static Future<void> clearMenuItems() async {
    final dbClient = await db;
    await dbClient.delete('menu_items');
  }
}
