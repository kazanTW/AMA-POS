import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/models.dart';
import '../../../core/utils/datetime_utils.dart';

final cashierRepositoryProvider = Provider<CashierRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CashierRepository(db);
});

class CashierRepository {
  CashierRepository(this._db);
  final AppDatabase _db;

  Stream<Order?> watchActiveOrder() => _db.watchActiveOrder();

  Stream<Order?> watchOrderById(int id) => _db.watchOrderById(id);

  Stream<List<Order>> watchUnpaidOrders() => _db.watchUnpaidOrders();

  Stream<List<OrderItem>> watchOrderItems(int orderId) =>
      _db.watchOrderItems(orderId);

  Stream<List<Category>> watchActiveCategories() =>
      _db.watchActiveCategories();

  Stream<List<Product>> watchActiveProducts({int? categoryId}) =>
      _db.watchActiveProducts(categoryId: categoryId);

  Future<List<ModifierGroupWithOptions>> getModifierGroupsForProduct(
          int productId) =>
      _db.getModifierGroupsForProduct(productId);

  Future<List<Order>> getUnpaidOrders() => _db.getUnpaidOrders();

  /// Creates a brand-new unpaid order and returns it.
  Future<Order> createNewOrder() async {
    final now = DateTime.now();
    final todayOrders = await _db.getPaidOrdersByDate(now);
    final seq = todayOrders.length + 1;
    final config = await _db.getMerchantConfig();
    final orderNo = generateOrderNo(config.terminalCode, seq);

    final openShift = await _db.getOpenShift();

    final id = await _db.createOrder({
      'orderNo': orderNo,
      'type': 'takeOut',
      'status': 'open',
      'subtotal': 0,
      'total': 0,
      'shiftId': openShift?.id,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    return (await _db.getOrderById(id))!;
  }

  /// Finds an existing unpaid order or creates a new one.
  /// Kept for backward compatibility; prefer [createNewOrder] for new flows.
  Future<Order?> getOrCreateOrder() async {
    final existing = await _db.getActiveOrder();
    if (existing != null) return existing;
    return createNewOrder();
  }

  Future<void> addItemToOrder(
    int orderId,
    Product product, {
    String? modifiersSnapshot,
  }) async {
    // Rule 2B: never merge – always insert a new orderItem row.
    final modifierTotal = _calcModifierTotal(modifiersSnapshot);
    final unitPrice = product.price + modifierTotal;
    await _db.addOrderItem({
      'orderId': orderId,
      'productId': product.id,
      'nameSnapshot': product.name,
      'priceSnapshot': product.price,
      'qty': 1,
      'lineTotal': unitPrice,
      'modifierTotal': modifierTotal,
      'modifiersSnapshot': modifiersSnapshot,
    });
    await _recalcOrder(orderId);
  }

  /// Parses [snapshot] JSON and returns the sum of all `priceDelta` values.
  /// Returns 0 if snapshot is null or cannot be parsed.
  static int _calcModifierTotal(String? snapshot) {
    if (snapshot == null || snapshot.isEmpty) return 0;
    try {
      final data = jsonDecode(snapshot) as Map<String, dynamic>;
      final groups = data['groups'] as List<dynamic>?;
      if (groups == null) return 0;
      return groups.fold<int>(
        0,
        (sum, g) => sum + ((g['priceDelta'] as num?)?.toInt() ?? 0),
      );
    } catch (_) {
      return 0;
    }
  }

  Future<void> updateItemQty(int orderId, int itemId, int qty) async {
    if (qty <= 0) {
      await _db.deleteOrderItem(itemId);
    } else {
      final items = await _db.getOrderItems(orderId);
      final item = items.firstWhere((i) => i.id == itemId);
      await _db.updateOrderItem(itemId, {
        'qty': qty,
        'lineTotal': (item.priceSnapshot + item.modifierTotal) * qty,
      });
    }
    await _recalcOrder(orderId);
  }

  Future<void> removeItem(int orderId, int itemId) async {
    await _db.deleteOrderItem(itemId);
    await _recalcOrder(orderId);
  }

  Future<void> _recalcOrder(int orderId) async {
    final items = await _db.getOrderItems(orderId);
    final total = items.fold<int>(0, (sum, i) => sum + i.lineTotal);
    await _db.updateOrder(orderId, {
      'subtotal': total,
      'total': total,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateOrderType(int orderId, String type,
      {String? tableNo}) async {
    await _db.updateOrder(orderId, {
      'type': type,
      'tableNo': tableNo,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Sets the hold label (桌號/備註) for an unpaid order.
  Future<void> setHoldLabel(int orderId, String? label) async {
    await _db.updateOrder(orderId, {
      'holdLabel': label,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Voids an unpaid order (clears its items and marks it voided).
  Future<void> voidOrder(int orderId) async {
    await _db.clearOrderItems(orderId);
    await _db.updateOrder(orderId, {
      'status': 'voided',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> setOrderPendingPayment(int orderId) async {
    await _db.updateOrder(orderId, {
      'status': 'pendingPayment',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> setOrderOpen(int orderId) async {
    await _db.updateOrder(orderId, {
      'status': 'open',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> completePayment({
    required int orderId,
    required int amountReceived,
  }) async {
    final order = await _db.getOrderById(orderId);
    if (order == null) return;
    final amountDue = order.total;
    final change = amountReceived - amountDue;
    await _db.recordPayment({
      'orderId': orderId,
      'method': 'cash',
      'amountDue': amountDue,
      'amountReceived': amountReceived,
      'change': change,
      'paidAt': DateTime.now().millisecondsSinceEpoch,
    });
    await _db.updateOrder(orderId, {
      'status': 'paid',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
