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

  Stream<List<OrderItem>> watchOrderItems(int orderId) =>
      _db.watchOrderItems(orderId);

  Stream<List<Category>> watchActiveCategories() =>
      _db.watchActiveCategories();

  Stream<List<Product>> watchActiveProducts({int? categoryId}) =>
      _db.watchActiveProducts(categoryId: categoryId);

  Future<List<ModifierGroupWithOptions>> getModifierGroupsForProduct(
          int productId) =>
      _db.getModifierGroupsForProduct(productId);

  Future<Order?> getOrCreateOrder() async {
    final existing = await _db.getActiveOrder();
    if (existing != null) return existing;

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
    return _db.getOrderById(id);
  }

  Future<void> addItemToOrder(
    int orderId,
    Product product, {
    String? modifiersSnapshot,
  }) async {
    final items = await _db.getOrderItems(orderId);
    // Only merge items that have no modifiers AND share the same productId.
    // Items with modifiers are always added as separate line items because
    // each modifier combination is a distinct selection.
    if (modifiersSnapshot == null) {
      final existing = items
          .where((i) =>
              i.productId == product.id && i.modifiersSnapshot == null)
          .firstOrNull;
      if (existing != null) {
        final newQty = existing.qty + 1;
        await _db.updateOrderItem(existing.id, {
          'qty': newQty,
          'lineTotal': product.price * newQty,
        });
        await _recalcOrder(orderId);
        return;
      }
    }
    await _db.addOrderItem({
      'orderId': orderId,
      'productId': product.id,
      'nameSnapshot': product.name,
      'priceSnapshot': product.price,
      'qty': 1,
      'lineTotal': product.price,
      'modifiersSnapshot': modifiersSnapshot,
    });
    await _recalcOrder(orderId);
  }

  Future<void> updateItemQty(int orderId, int itemId, int qty) async {
    if (qty <= 0) {
      await _db.deleteOrderItem(itemId);
    } else {
      final items = await _db.getOrderItems(orderId);
      final item = items.firstWhere((i) => i.id == itemId);
      await _db.updateOrderItem(itemId, {
        'qty': qty,
        'lineTotal': item.priceSnapshot * qty,
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
