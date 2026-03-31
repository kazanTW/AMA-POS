import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/models.dart';

final backofficeRepositoryProvider = Provider<BackofficeRepository>((ref) {
  return BackofficeRepository(ref.watch(appDatabaseProvider));
});

class BackofficeRepository {
  BackofficeRepository(this._db);
  final AppDatabase _db;

  // ---- Categories ----
  Stream<List<Category>> watchAllCategories() => _db.watchAllCategories();

  Future<void> saveCategory({
    int? id,
    required String name,
    required bool isActive,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (id == null) {
      await _db.insertCategory({
        'name': name,
        'isActive': isActive ? 1 : 0,
        'sortOrder': 0,
        'updatedAt': now,
      });
    } else {
      await _db.updateCategory(id, {
        'name': name,
        'isActive': isActive ? 1 : 0,
        'updatedAt': now,
      });
    }
  }

  Future<void> deleteCategory(int id) => _db.deleteCategory(id);

  // ---- Products ----
  Stream<List<Product>> watchAllProducts() => _db.watchAllProducts();

  Future<int> saveProduct({
    int? id,
    required String name,
    required int price,
    required bool isActive,
    int? categoryId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (id == null) {
      return _db.insertProduct({
        'name': name,
        'price': price,
        'categoryId': categoryId,
        'isActive': isActive ? 1 : 0,
        'sortOrder': 0,
        'updatedAt': now,
      });
    } else {
      await _db.updateProduct(id, {
        'name': name,
        'price': price,
        'categoryId': categoryId,
        'isActive': isActive ? 1 : 0,
        'updatedAt': now,
      });
      return id;
    }
  }

  Future<void> deleteProduct(int id) => _db.deleteProduct(id);

  // ---- Modifier Groups ----
  Stream<List<ModifierGroup>> watchAllModifierGroups() =>
      _db.watchAllModifierGroups();

  Future<void> saveModifierGroup({
    int? id,
    required String name,
    required bool isActive,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (id == null) {
      await _db.insertModifierGroup({
        'name': name,
        'isActive': isActive ? 1 : 0,
        'sortOrder': 0,
        'updatedAt': now,
      });
    } else {
      await _db.updateModifierGroup(id, {
        'name': name,
        'isActive': isActive ? 1 : 0,
        'updatedAt': now,
      });
    }
  }

  Future<void> deleteModifierGroup(int id) => _db.deleteModifierGroup(id);

  // ---- Modifier Options ----
  Stream<List<ModifierOption>> watchModifierOptionsByGroup(int groupId) =>
      _db.watchModifierOptionsByGroup(groupId);

  Future<void> saveModifierOption({
    int? id,
    required int groupId,
    required String name,
    required bool isActive,
    int priceDelta = 0,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (id == null) {
      await _db.insertModifierOption({
        'groupId': groupId,
        'name': name,
        'priceDelta': priceDelta,
        'isActive': isActive ? 1 : 0,
        'sortOrder': 0,
        'updatedAt': now,
      });
    } else {
      await _db.updateModifierOption(id, {
        'name': name,
        'priceDelta': priceDelta,
        'isActive': isActive ? 1 : 0,
        'updatedAt': now,
      });
    }
  }

  Future<void> deleteModifierOption(int id) => _db.deleteModifierOption(id);

  // ---- Product Modifier Group Mappings ----
  Future<List<int>> getGroupIdsForProduct(int productId) =>
      _db.getGroupIdsForProduct(productId);

  Future<void> setProductModifierGroups(int productId, List<int> groupIds) =>
      _db.setProductModifierGroups(productId, groupIds);

  // ---- Shifts ----
  Stream<List<Shift>> watchAllShifts() => _db.watchAllShifts();

  Future<Shift?> getOpenShift() => _db.getOpenShift();

  Future<int> openShift({int? openingCash}) =>
      _db.insertShift({
        'openedAt': DateTime.now().millisecondsSinceEpoch,
        'openingCash': openingCash,
      });

  Future<void> closeShift(
    Shift shift, {
    int? closingCash,
    String? note,
  }) =>
      _db.updateShift(shift.id, {
        'closedAt': DateTime.now().millisecondsSinceEpoch,
        'closingCash': closingCash,
        'note': note,
      });

  Future<Map<String, dynamic>> getShiftStats(int shiftId) async {
    final orders = await _db.getPaidOrdersByShift(shiftId);
    final total = orders.fold<int>(0, (s, o) => s + o.total);
    return {
      'orderCount': orders.length,
      'salesTotal': total,
    };
  }

  Future<Map<String, dynamic>> getDailyStats(DateTime date) async {
    final orders = await _db.getPaidOrdersByDate(date);
    final total = orders.fold<int>(0, (s, o) => s + o.total);
    return {
      'orderCount': orders.length,
      'salesTotal': total,
      'orders': orders,
    };
  }

  // ---- Merchant Config ----
  Future<MerchantConfig> getMerchantConfig() => _db.getMerchantConfig();

  Future<void> setTableCount(int tableCount) =>
      _db.updateMerchantConfig({'tableCount': tableCount});

  Future<void> setTerminalCode(String terminalCode) =>
      _db.updateMerchantConfig({'terminalCode': terminalCode.toUpperCase()});

  // ---- Import/Export ----
  Future<String> exportConfig() async {
    final data = await _db.exportConfigData();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/amapos_config_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(jsonStr);
    return file.path;
  }

  Future<void> importConfig(String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    await _db.importConfigData(data);
  }

  Future<String?> pickImportFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.first.path;
    if (path == null) return null;
    return File(path).readAsString();
  }

  /// Lets the user pick a SQLite file (any filename), backs up the current DB,
  /// then replaces it with the chosen file.
  ///
  /// Returns the backup file path on success, `null` if the user cancelled the
  /// picker, or throws on error.
  Future<String?> importSqliteDatabase() async {
    // 1. Pick file (sqlite / db, or any extension – allow all so the user can
    //    pick a file named amapos.sqlite even if the picker filters differ by
    //    platform).
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return null;
    final srcPath = result.files.first.path;
    if (srcPath == null) return null;

    // 2. Minimal validation: check the SQLite magic header.
    final src = File(srcPath);
    final raf = await src.open();
    late List<int> headerBytes;
    try {
      headerBytes = await raf.read(16);
    } finally {
      await raf.close();
    }
    // "SQLite format 3\0"
    const sqliteMagic = <int>[
      0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66,
      0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
    ];
    final valid = headerBytes.length >= sqliteMagic.length &&
        Iterable<int>.generate(sqliteMagic.length)
            .every((i) => headerBytes[i] == sqliteMagic[i]);
    if (!valid) throw Exception('所選檔案不是有效的 SQLite 資料庫');

    // 3. Determine canonical DB path.
    final docsDir = await getApplicationDocumentsDirectory();
    final destPath = '${docsDir.path}/amapos.sqlite';
    final dest = File(destPath);

    // 4. Back up existing DB if present.
    String backupPath = '';
    if (await dest.exists()) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      backupPath = '$destPath.bak_$ts';
      await dest.copy(backupPath);
    }

    // 5. Close DB connection so the file is not locked.
    await _db.closeAndReset();

    // 6. Copy selected file to canonical path.
    await src.copy(destPath);

    return backupPath;
  }
}
