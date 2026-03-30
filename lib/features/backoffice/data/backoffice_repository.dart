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

  Future<void> saveProduct({
    int? id,
    required String name,
    required int price,
    required bool isActive,
    int? categoryId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (id == null) {
      await _db.insertProduct({
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
    }
  }

  Future<void> deleteProduct(int id) => _db.deleteProduct(id);

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
}
