import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/models.dart';
import '../data/cashier_repository.dart';

final activeOrderProvider = StreamProvider<Order?>((ref) {
  return ref.watch(cashierRepositoryProvider).watchActiveOrder();
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
