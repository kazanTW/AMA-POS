import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/models.dart';

final backofficeRepositoryProvider = Provider<BackofficeRepository>((ref) {
  return BackofficeRepository(ref.watch(appDatabaseProvider));
});

/// Result returned by [BackofficeRepository.importSqliteDatabase] on success.
class SqliteImportResult {
  const SqliteImportResult({
    required this.backupPath,
    required this.tableNames,
    required this.categoryCount,
    required this.productCount,
  });

  /// Path to the backup of the previous DB, or empty string if there was none.
  final String backupPath;

  /// Table names found in the imported DB.
  final List<String> tableNames;

  /// Row count of the `categories` table in the imported DB (0 if absent).
  final int categoryCount;

  /// Row count of active rows in the `products` table (0 if absent).
  final int productCount;
}

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
  /// then **atomically** replaces it with the chosen file.
  ///
  /// Supports Android SAF `content://` URIs returned by the file picker by
  /// requesting in-memory bytes directly (no assumption that a file path
  /// exists on disk).  The replace is done via a temp-file + rename so a
  /// partial write never corrupts the canonical DB.
  ///
  /// After the replace, WAL and SHM companion files are deleted so the newly
  /// imported DB is opened cleanly on next launch.
  ///
  /// Returns a [SqliteImportResult] with verification counts on success,
  /// `null` if the user cancelled the picker, or throws on error (the
  /// existing DB is **not** touched on error).
  Future<SqliteImportResult?> importSqliteDatabase() async {
    // 1. Pick file – request bytes so SAF content:// URIs work on Android.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final pickedFile = result.files.first;

    // 2. Obtain raw bytes (prefer bytes; fall back to path for desktop/iOS).
    Uint8List fileBytes;
    if (pickedFile.bytes != null && pickedFile.bytes!.isNotEmpty) {
      fileBytes = pickedFile.bytes!;
    } else if (pickedFile.path != null) {
      fileBytes = await File(pickedFile.path!).readAsBytes();
    } else {
      throw Exception('無法讀取所選檔案（路徑和資料均不可用）');
    }

    // 3. Validate SQLite magic header ("SQLite format 3\0").
    const sqliteMagic = <int>[
      0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66,
      0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
    ];
    if (fileBytes.length < sqliteMagic.length ||
        !Iterable<int>.generate(sqliteMagic.length)
            .every((i) => fileBytes[i] == sqliteMagic[i])) {
      throw Exception('所選檔案不是有效的 SQLite 資料庫');
    }

    // 4. Determine canonical DB path.
    final docsDir = await getApplicationDocumentsDirectory();
    final destPath = '${docsDir.path}/amapos.sqlite';
    final dest = File(destPath);

    // 5. Back up existing DB if present (before closing the connection).
    String backupPath = '';
    if (await dest.exists()) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      backupPath = '$destPath.bak_$ts';
      await dest.copy(backupPath);
    }

    // 6. Close DB connection so the file is not locked during replace.
    await _db.closeAndReset();

    // 7. Atomic replace: write to a temp file, then rename over the target.
    //    This prevents partial-write corruption if the process is interrupted.
    final tempPath = '$destPath.tmp';
    final tempFile = File(tempPath);
    try {
      await tempFile.writeAsBytes(fileBytes, flush: true);
      await tempFile.rename(destPath);
    } catch (e) {
      // Clean up temp file if rename failed; do NOT overwrite the original.
      if (await tempFile.exists()) await tempFile.delete();
      rethrow;
    }

    // 8. Remove WAL / SHM companion files so the new DB opens cleanly.
    for (final suffix in ['-wal', '-shm']) {
      final companion = File('$destPath$suffix');
      if (await companion.exists()) {
        try {
          await companion.delete();
        } catch (_) {
          // Non-fatal: companion files will be handled by SQLite on open.
        }
      }
    }

    // 9. Verify the imported DB by opening it read-only and querying metadata.
    int categoryCount = 0;
    int productCount = 0;
    final List<String> tableNames = [];
    Database? verifyDb;
    try {
      verifyDb = await openDatabase(destPath, readOnly: true);
      final tableRows = await verifyDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      for (final row in tableRows) {
        final name = row['name'] as String?;
        if (name != null) tableNames.add(name);
      }
      if (tableNames.contains('categories')) {
        final r = await verifyDb
            .rawQuery('SELECT COUNT(*) AS cnt FROM categories');
        categoryCount = Sqflite.firstIntValue(r) ?? 0;
      }
      if (tableNames.contains('products')) {
        final r = await verifyDb.rawQuery(
          'SELECT COUNT(*) AS cnt FROM products WHERE isActive = 1',
        );
        productCount = Sqflite.firstIntValue(r) ?? 0;
      }
    } finally {
      await verifyDb?.close();
    }

    return SqliteImportResult(
      backupPath: backupPath,
      tableNames: tableNames,
      categoryCount: categoryCount,
      productCount: productCount,
    );
  }
}
