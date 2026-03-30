import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Override appDatabaseProvider in main()');
});

// ---------------------------------------------------------------------------
// Database helper
// ---------------------------------------------------------------------------

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = p.join(docsDir.path, 'amapos.sqlite');
    return openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        isActive INTEGER NOT NULL DEFAULT 1,
        updatedAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoryId INTEGER,
        name TEXT NOT NULL,
        price INTEGER NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        updatedAt INTEGER NOT NULL,
        FOREIGN KEY (categoryId) REFERENCES categories(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        openedAt INTEGER NOT NULL,
        closedAt INTEGER,
        openingCash INTEGER,
        closingCash INTEGER,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderNo TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'takeOut',
        tableNo TEXT,
        status TEXT NOT NULL DEFAULT 'open',
        subtotal INTEGER NOT NULL DEFAULT 0,
        total INTEGER NOT NULL DEFAULT 0,
        shiftId INTEGER,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        FOREIGN KEY (shiftId) REFERENCES shifts(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE orderItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId INTEGER NOT NULL,
        productId INTEGER,
        nameSnapshot TEXT NOT NULL,
        priceSnapshot INTEGER NOT NULL,
        qty INTEGER NOT NULL DEFAULT 1,
        lineTotal INTEGER NOT NULL DEFAULT 0,
        modifierTotal INTEGER NOT NULL DEFAULT 0,
        modifiersSnapshot TEXT,
        FOREIGN KEY (orderId) REFERENCES orders(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE modifierGroups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        updatedAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE modifierOptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        groupId INTEGER NOT NULL,
        name TEXT NOT NULL,
        priceDelta INTEGER NOT NULL DEFAULT 0,
        isActive INTEGER NOT NULL DEFAULT 1,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        updatedAt INTEGER NOT NULL,
        FOREIGN KEY (groupId) REFERENCES modifierGroups(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE productModifierGroups (
        productId INTEGER NOT NULL,
        groupId INTEGER NOT NULL,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (productId, groupId),
        FOREIGN KEY (productId) REFERENCES products(id),
        FOREIGN KEY (groupId) REFERENCES modifierGroups(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId INTEGER NOT NULL,
        method TEXT NOT NULL DEFAULT 'cash',
        amountDue INTEGER NOT NULL,
        amountReceived INTEGER NOT NULL,
        change INTEGER NOT NULL,
        paidAt INTEGER NOT NULL,
        FOREIGN KEY (orderId) REFERENCES orders(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE merchantConfigs (
        id INTEGER PRIMARY KEY DEFAULT 1,
        merchantName TEXT NOT NULL DEFAULT 'AMA POS',
        currency TEXT NOT NULL DEFAULT 'TWD',
        schemaVersion INTEGER NOT NULL DEFAULT 1,
        tableCount INTEGER NOT NULL DEFAULT 0,
        terminalCode TEXT NOT NULL DEFAULT 'A1',
        updatedAt INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE merchantConfigs ADD COLUMN tableCount INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE merchantConfigs ADD COLUMN terminalCode TEXT NOT NULL DEFAULT 'A1'",
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE orderItems ADD COLUMN modifiersSnapshot TEXT',
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS modifierGroups (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          isActive INTEGER NOT NULL DEFAULT 1,
          sortOrder INTEGER NOT NULL DEFAULT 0,
          updatedAt INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS modifierOptions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          groupId INTEGER NOT NULL,
          name TEXT NOT NULL,
          priceDelta INTEGER NOT NULL DEFAULT 0,
          isActive INTEGER NOT NULL DEFAULT 1,
          sortOrder INTEGER NOT NULL DEFAULT 0,
          updatedAt INTEGER NOT NULL,
          FOREIGN KEY (groupId) REFERENCES modifierGroups(id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS productModifierGroups (
          productId INTEGER NOT NULL,
          groupId INTEGER NOT NULL,
          sortOrder INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (productId, groupId),
          FOREIGN KEY (productId) REFERENCES products(id),
          FOREIGN KEY (groupId) REFERENCES modifierGroups(id)
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE orderItems ADD COLUMN modifierTotal INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  // -------------------------------------------------------------------------
  // Seed data
  // -------------------------------------------------------------------------

  Future<void> seedDataIfEmpty() async {
    final db = await database;
    final rows = await db.query('categories', limit: 1);
    if (rows.isNotEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    final drinksCatId = await db.insert('categories', {
      'name': '飲料',
      'sortOrder': 0,
      'isActive': 1,
      'updatedAt': now,
    });
    final foodCatId = await db.insert('categories', {
      'name': '餐點',
      'sortOrder': 1,
      'isActive': 1,
      'updatedAt': now,
    });
    final snackCatId = await db.insert('categories', {
      'name': '小食',
      'sortOrder': 2,
      'isActive': 1,
      'updatedAt': now,
    });

    for (final item in [
      ('珍珠奶茶', 60, drinksCatId, 0),
      ('紅茶', 30, drinksCatId, 1),
      ('綠茶', 30, drinksCatId, 2),
      ('咖啡', 50, drinksCatId, 3),
      ('柳橙汁', 45, drinksCatId, 4),
    ]) {
      await db.insert('products', {
        'categoryId': item.$3,
        'name': item.$1,
        'price': item.$2,
        'sortOrder': item.$4,
        'isActive': 1,
        'updatedAt': now,
      });
    }

    for (final item in [
      ('蛋炒飯', 80, foodCatId, 0),
      ('牛肉麵', 120, foodCatId, 1),
      ('雞腿飯', 100, foodCatId, 2),
      ('炒麵', 75, foodCatId, 3),
    ]) {
      await db.insert('products', {
        'categoryId': item.$3,
        'name': item.$1,
        'price': item.$2,
        'sortOrder': item.$4,
        'isActive': 1,
        'updatedAt': now,
      });
    }

    for (final item in [
      ('薯條', 40, snackCatId, 0),
      ('雞塊', 50, snackCatId, 1),
      ('玉米濃湯', 35, snackCatId, 2),
    ]) {
      await db.insert('products', {
        'categoryId': item.$3,
        'name': item.$1,
        'price': item.$2,
        'sortOrder': item.$4,
        'isActive': 1,
        'updatedAt': now,
      });
    }

    await db.insert('merchantConfigs', {
      'id': 1,
      'merchantName': 'AMA 小店',
      'currency': 'TWD',
      'schemaVersion': 1,
      'tableCount': 0,
      'terminalCode': 'A1',
      'updatedAt': now,
    });
  }

  // -------------------------------------------------------------------------
  // Categories
  // -------------------------------------------------------------------------

  Future<List<Category>> getActiveCategories() async {
    final db = await database;
    final maps = await db.query(
      'categories',
      where: 'isActive = 1',
      orderBy: 'sortOrder ASC',
    );
    return maps.map(Category.fromMap).toList();
  }

  Future<List<Category>> getAllCategories() async {
    final db = await database;
    final maps = await db.query('categories', orderBy: 'sortOrder ASC');
    return maps.map(Category.fromMap).toList();
  }

  Future<int> insertCategory(Map<String, dynamic> values) async {
    final db = await database;
    return db.insert('categories', values);
  }

  Future<int> updateCategory(int id, Map<String, dynamic> values) async {
    final db = await database;
    return db.update('categories', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // -------------------------------------------------------------------------
  // Products
  // -------------------------------------------------------------------------

  Future<List<Product>> getActiveProducts({int? categoryId}) async {
    final db = await database;
    String where = 'isActive = 1';
    List<Object?> args = [];
    if (categoryId != null) {
      where += ' AND categoryId = ?';
      args.add(categoryId);
    }
    final maps = await db.query(
      'products',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'sortOrder ASC, name ASC',
    );
    return maps.map(Product.fromMap).toList();
  }

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final maps = await db.query(
      'products',
      orderBy: 'categoryId ASC, sortOrder ASC',
    );
    return maps.map(Product.fromMap).toList();
  }

  Future<int> insertProduct(Map<String, dynamic> values) async {
    final db = await database;
    return db.insert('products', values);
  }

  Future<int> updateProduct(int id, Map<String, dynamic> values) async {
    final db = await database;
    return db.update('products', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // -------------------------------------------------------------------------
  // Orders
  // -------------------------------------------------------------------------

  Future<Order?> getActiveOrder() async {
    final db = await database;
    final maps = await db.query(
      'orders',
      where: "status IN ('open', 'pendingPayment')",
      orderBy: 'createdAt DESC',
      limit: 1,
    );
    return maps.isEmpty ? null : Order.fromMap(maps.first);
  }

  Future<Order?> getOrderById(int id) async {
    final db = await database;
    final maps =
        await db.query('orders', where: 'id = ?', whereArgs: [id]);
    return maps.isEmpty ? null : Order.fromMap(maps.first);
  }

  Future<int> createOrder(Map<String, dynamic> values) async {
    final db = await database;
    return db.insert('orders', values);
  }

  Future<int> updateOrder(int id, Map<String, dynamic> values) async {
    final db = await database;
    return db.update('orders', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Order>> getPaidOrdersByDate(DateTime date) async {
    final db = await database;
    final start = DateTime(date.year, date.month, date.day)
        .millisecondsSinceEpoch;
    final end = DateTime(date.year, date.month, date.day + 1)
        .millisecondsSinceEpoch;
    final maps = await db.query(
      'orders',
      where: "status = 'paid' AND createdAt >= ? AND createdAt < ?",
      whereArgs: [start, end],
      orderBy: 'createdAt DESC',
    );
    return maps.map(Order.fromMap).toList();
  }

  Future<List<Order>> getPaidOrdersByShift(int shiftId) async {
    final db = await database;
    final maps = await db.query(
      'orders',
      where: "status = 'paid' AND shiftId = ?",
      whereArgs: [shiftId],
    );
    return maps.map(Order.fromMap).toList();
  }

  // -------------------------------------------------------------------------
  // Order Items
  // -------------------------------------------------------------------------

  Future<List<OrderItem>> getOrderItems(int orderId) async {
    final db = await database;
    final maps = await db.query(
      'orderItems',
      where: 'orderId = ?',
      whereArgs: [orderId],
    );
    return maps.map(OrderItem.fromMap).toList();
  }

  Future<int> addOrderItem(Map<String, dynamic> values) async {
    final db = await database;
    return db.insert('orderItems', values);
  }

  Future<int> updateOrderItem(int id, Map<String, dynamic> values) async {
    final db = await database;
    return db.update('orderItems', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteOrderItem(int id) async {
    final db = await database;
    return db.delete('orderItems', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearOrderItems(int orderId) async {
    final db = await database;
    await db.delete('orderItems', where: 'orderId = ?', whereArgs: [orderId]);
  }

  // -------------------------------------------------------------------------
  // Modifier Groups
  // -------------------------------------------------------------------------

  Future<List<ModifierGroup>> getAllModifierGroups() async {
    final db = await database;
    final maps = await db.query('modifierGroups', orderBy: 'sortOrder ASC, name ASC');
    return maps.map(ModifierGroup.fromMap).toList();
  }

  Future<int> insertModifierGroup(Map<String, dynamic> values) async {
    final db = await database;
    return db.insert('modifierGroups', values);
  }

  Future<int> updateModifierGroup(int id, Map<String, dynamic> values) async {
    final db = await database;
    return db.update('modifierGroups', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteModifierGroup(int id) async {
    final db = await database;
    await db.delete('modifierOptions', where: 'groupId = ?', whereArgs: [id]);
    await db.delete('productModifierGroups', where: 'groupId = ?', whereArgs: [id]);
    return db.delete('modifierGroups', where: 'id = ?', whereArgs: [id]);
  }

  // -------------------------------------------------------------------------
  // Modifier Options
  // -------------------------------------------------------------------------

  Future<List<ModifierOption>> getModifierOptionsByGroup(int groupId) async {
    final db = await database;
    final maps = await db.query(
      'modifierOptions',
      where: 'groupId = ?',
      whereArgs: [groupId],
      orderBy: 'sortOrder ASC, name ASC',
    );
    return maps.map(ModifierOption.fromMap).toList();
  }

  Future<int> insertModifierOption(Map<String, dynamic> values) async {
    final db = await database;
    return db.insert('modifierOptions', values);
  }

  Future<int> updateModifierOption(int id, Map<String, dynamic> values) async {
    final db = await database;
    return db.update('modifierOptions', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteModifierOption(int id) async {
    final db = await database;
    return db.delete('modifierOptions', where: 'id = ?', whereArgs: [id]);
  }

  // -------------------------------------------------------------------------
  // Product Modifier Group Mappings
  // -------------------------------------------------------------------------

  Future<List<int>> getGroupIdsForProduct(int productId) async {
    final db = await database;
    final maps = await db.query(
      'productModifierGroups',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'sortOrder ASC',
    );
    return maps.map((m) => m['groupId'] as int).toList();
  }

  Future<void> setProductModifierGroups(
      int productId, List<int> groupIds) async {
    final db = await database;
    await db.delete('productModifierGroups',
        where: 'productId = ?', whereArgs: [productId]);
    for (var i = 0; i < groupIds.length; i++) {
      await db.insert('productModifierGroups', {
        'productId': productId,
        'groupId': groupIds[i],
        'sortOrder': i,
      });
    }
  }

  /// Returns active modifier groups (with their active options) for a product.
  Future<List<ModifierGroupWithOptions>> getModifierGroupsForProduct(
      int productId) async {
    final db = await database;
    final mappings = await db.query(
      'productModifierGroups',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'sortOrder ASC',
    );
    final result = <ModifierGroupWithOptions>[];
    for (final m in mappings) {
      final groupId = m['groupId'] as int;
      final groupMaps = await db.query(
        'modifierGroups',
        where: 'id = ? AND isActive = 1',
        whereArgs: [groupId],
      );
      if (groupMaps.isEmpty) continue;
      final group = ModifierGroup.fromMap(groupMaps.first);
      final optionMaps = await db.query(
        'modifierOptions',
        where: 'groupId = ? AND isActive = 1',
        whereArgs: [groupId],
        orderBy: 'sortOrder ASC, name ASC',
      );
      final options = optionMaps.map(ModifierOption.fromMap).toList();
      result.add(ModifierGroupWithOptions(group: group, options: options));
    }
    return result;
  }

  // Streams for modifier groups

  Stream<List<ModifierGroup>> watchAllModifierGroups() {
    late StreamController<List<ModifierGroup>> controller;
    Timer? timer;

    controller = StreamController<List<ModifierGroup>>(
      onListen: () async {
        controller.add(await getAllModifierGroups());
        timer = Timer.periodic(const Duration(seconds: 1), (_) async {
          if (!controller.isClosed) {
            controller.add(await getAllModifierGroups());
          }
        });
      },
      onCancel: () {
        timer?.cancel();
        controller.close();
      },
    );
    return controller.stream;
  }

  Stream<List<ModifierOption>> watchModifierOptionsByGroup(int groupId) {
    late StreamController<List<ModifierOption>> controller;
    Timer? timer;

    controller = StreamController<List<ModifierOption>>(
      onListen: () async {
        controller.add(await getModifierOptionsByGroup(groupId));
        timer = Timer.periodic(const Duration(seconds: 1), (_) async {
          if (!controller.isClosed) {
            controller.add(await getModifierOptionsByGroup(groupId));
          }
        });
      },
      onCancel: () {
        timer?.cancel();
        controller.close();
      },
    );
    return controller.stream;
  }

  // -------------------------------------------------------------------------
  // Payments
  // -------------------------------------------------------------------------

  Future<int> recordPayment(Map<String, dynamic> values) async {
    final db = await database;
    return db.insert('payments', values);
  }

  // -------------------------------------------------------------------------
  // Shifts
  // -------------------------------------------------------------------------

  Future<Shift?> getOpenShift() async {
    final db = await database;
    final maps = await db.query(
      'shifts',
      where: 'closedAt IS NULL',
      orderBy: 'openedAt DESC',
      limit: 1,
    );
    return maps.isEmpty ? null : Shift.fromMap(maps.first);
  }

  Future<List<Shift>> getAllShifts() async {
    final db = await database;
    final maps = await db.query('shifts', orderBy: 'openedAt DESC');
    return maps.map(Shift.fromMap).toList();
  }

  Future<int> insertShift(Map<String, dynamic> values) async {
    final db = await database;
    return db.insert('shifts', values);
  }

  Future<int> updateShift(int id, Map<String, dynamic> values) async {
    final db = await database;
    return db.update('shifts', values, where: 'id = ?', whereArgs: [id]);
  }

  // -------------------------------------------------------------------------
  // Stream helpers (poll-based for simplicity)
  // -------------------------------------------------------------------------

  Stream<Order?> watchActiveOrder() {
    late StreamController<Order?> controller;
    Timer? timer;

    controller = StreamController<Order?>(
      onListen: () async {
        controller.add(await getActiveOrder());
        timer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
          if (!controller.isClosed) {
            controller.add(await getActiveOrder());
          }
        });
      },
      onCancel: () {
        timer?.cancel();
        controller.close();
      },
    );
    return controller.stream.distinct((a, b) {
      if (a == null && b == null) return true;
      if (a == null || b == null) return false;
      return a.id == b.id &&
          a.status == b.status &&
          a.total == b.total &&
          a.type == b.type &&
          a.tableNo == b.tableNo;
    });
  }

  Stream<List<OrderItem>> watchOrderItems(int orderId) {
    late StreamController<List<OrderItem>> controller;
    Timer? timer;

    controller = StreamController<List<OrderItem>>(
      onListen: () async {
        controller.add(await getOrderItems(orderId));
        timer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
          if (!controller.isClosed) {
            controller.add(await getOrderItems(orderId));
          }
        });
      },
      onCancel: () {
        timer?.cancel();
        controller.close();
      },
    );
    return controller.stream;
  }

  Stream<List<Category>> watchActiveCategories() {
    late StreamController<List<Category>> controller;
    Timer? timer;

    controller = StreamController<List<Category>>(
      onListen: () async {
        controller.add(await getActiveCategories());
        timer = Timer.periodic(const Duration(seconds: 2), (_) async {
          if (!controller.isClosed) {
            controller.add(await getActiveCategories());
          }
        });
      },
      onCancel: () {
        timer?.cancel();
        controller.close();
      },
    );
    return controller.stream;
  }

  Stream<List<Category>> watchAllCategories() {
    late StreamController<List<Category>> controller;
    Timer? timer;

    controller = StreamController<List<Category>>(
      onListen: () async {
        controller.add(await getAllCategories());
        timer = Timer.periodic(const Duration(seconds: 1), (_) async {
          if (!controller.isClosed) {
            controller.add(await getAllCategories());
          }
        });
      },
      onCancel: () {
        timer?.cancel();
        controller.close();
      },
    );
    return controller.stream;
  }

  Stream<List<Product>> watchActiveProducts({int? categoryId}) {
    late StreamController<List<Product>> controller;
    Timer? timer;

    controller = StreamController<List<Product>>(
      onListen: () async {
        controller.add(await getActiveProducts(categoryId: categoryId));
        timer = Timer.periodic(const Duration(seconds: 2), (_) async {
          if (!controller.isClosed) {
            controller
                .add(await getActiveProducts(categoryId: categoryId));
          }
        });
      },
      onCancel: () {
        timer?.cancel();
        controller.close();
      },
    );
    return controller.stream;
  }

  Stream<List<Product>> watchAllProducts() {
    late StreamController<List<Product>> controller;
    Timer? timer;

    controller = StreamController<List<Product>>(
      onListen: () async {
        controller.add(await getAllProducts());
        timer = Timer.periodic(const Duration(seconds: 1), (_) async {
          if (!controller.isClosed) {
            controller.add(await getAllProducts());
          }
        });
      },
      onCancel: () {
        timer?.cancel();
        controller.close();
      },
    );
    return controller.stream;
  }

  Stream<List<Shift>> watchAllShifts() {
    late StreamController<List<Shift>> controller;
    Timer? timer;

    controller = StreamController<List<Shift>>(
      onListen: () async {
        controller.add(await getAllShifts());
        timer = Timer.periodic(const Duration(seconds: 2), (_) async {
          if (!controller.isClosed) {
            controller.add(await getAllShifts());
          }
        });
      },
      onCancel: () {
        timer?.cancel();
        controller.close();
      },
    );
    return controller.stream;
  }

  // -------------------------------------------------------------------------
  // Merchant Config
  // -------------------------------------------------------------------------

  Future<MerchantConfig> getMerchantConfig() async {
    final db = await database;
    final maps = await db.query('merchantConfigs', where: 'id = 1', limit: 1);
    if (maps.isEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('merchantConfigs', {
        'id': 1,
        'merchantName': 'AMA 小店',
        'currency': 'TWD',
        'schemaVersion': 3,
        'tableCount': 0,
        'terminalCode': 'A1',
        'updatedAt': now,
      });
      return MerchantConfig(
        id: 1,
        merchantName: 'AMA 小店',
        currency: 'TWD',
        schemaVersion: 3,
        tableCount: 0,
        terminalCode: 'A1',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    }
    return MerchantConfig.fromMap(maps.first);
  }

  Future<void> updateMerchantConfig(Map<String, dynamic> values) async {
    final db = await database;
    await db.update(
      'merchantConfigs',
      {...values, 'updatedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = 1',
    );
  }

  // -------------------------------------------------------------------------
  // Import / Export
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> exportConfigData() async {
    final categories = await getAllCategories();
    final products = await getAllProducts();
    final config = await getMerchantConfig();
    return {
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'merchantSettings': {
        'merchantName': config.merchantName,
        'currency': config.currency,
        'tableCount': config.tableCount,
        'terminalCode': config.terminalCode,
      },
      'categories': categories
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'sortOrder': c.sortOrder,
                'isActive': c.isActive,
              })
          .toList(),
      'products': products
          .map((p) => {
                'id': p.id,
                'categoryId': p.categoryId,
                'name': p.name,
                'price': p.price,
                'isActive': p.isActive,
                'sortOrder': p.sortOrder,
              })
          .toList(),
    };
  }

  Future<void> importConfigData(Map<String, dynamic> data) async {
    final db = await database;
    final categories = (data['categories'] as List?) ?? [];
    final products = (data['products'] as List?) ?? [];
    final merchantSettings =
        data['merchantSettings'] as Map<String, dynamic>?;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (merchantSettings != null) {
      await db.update(
        'merchantConfigs',
        {
          if (merchantSettings['merchantName'] != null)
            'merchantName': merchantSettings['merchantName'] as String,
          if (merchantSettings['currency'] != null)
            'currency': merchantSettings['currency'] as String,
          'tableCount': merchantSettings['tableCount'] as int? ?? 0,
          'terminalCode':
              merchantSettings['terminalCode'] as String? ?? 'A1',
          'updatedAt': now,
        },
        where: 'id = 1',
      );
    }

    await db.delete('categories');
    for (final cat in categories) {
      await db.insert('categories', {
        'name': cat['name'] as String,
        'sortOrder': cat['sortOrder'] as int? ?? 0,
        'isActive': (cat['isActive'] as bool? ?? true) ? 1 : 0,
        'updatedAt': now,
      });
    }

    await db.delete('products');
    for (final prod in products) {
      await db.insert('products', {
        'name': prod['name'] as String,
        'price': prod['price'] as int,
        'categoryId': prod['categoryId'] as int?,
        'isActive': (prod['isActive'] as bool? ?? true) ? 1 : 0,
        'sortOrder': prod['sortOrder'] as int? ?? 0,
        'updatedAt': now,
      });
    }
  }
}
