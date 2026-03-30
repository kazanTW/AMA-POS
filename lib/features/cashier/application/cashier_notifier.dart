import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/models.dart';
import '../data/cashier_repository.dart';

/// Tracks which unpaid order is currently active in the cashier.
/// Null means no order is selected (empty state / start-new-order).
final currentOrderIdProvider = StateProvider<int?>((ref) => null);

/// Watches the currently selected order by ID.
final activeOrderProvider = StreamProvider<Order?>((ref) {
  final orderId = ref.watch(currentOrderIdProvider);
  if (orderId == null) return Stream.value(null);
  return ref.watch(cashierRepositoryProvider).watchOrderById(orderId);
});

/// Lists all unpaid (open / pendingPayment) orders for the hold/switch dialog.
final unpaidOrdersProvider = StreamProvider<List<Order>>((ref) {
  return ref.watch(cashierRepositoryProvider).watchUnpaidOrders();
});

final orderItemsProvider =
    StreamProvider.family<List<OrderItem>, int>((ref, orderId) {
  return ref.watch(cashierRepositoryProvider).watchOrderItems(orderId);
});

final activeCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(cashierRepositoryProvider).watchActiveCategories();
});

final activeProductsProvider =
    StreamProvider.family<List<Product>, int?>((ref, categoryId) {
  return ref
      .watch(cashierRepositoryProvider)
      .watchActiveProducts(categoryId: categoryId);
});

// Selected category filter
final selectedCategoryIdProvider = StateProvider<int?>((ref) => null);
