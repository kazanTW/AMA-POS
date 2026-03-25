import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/models.dart';
import '../data/backoffice_repository.dart';

final allCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(backofficeRepositoryProvider).watchAllCategories();
});

final allProductsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(backofficeRepositoryProvider).watchAllProducts();
});

final allShiftsProvider = StreamProvider<List<Shift>>((ref) {
  return ref.watch(backofficeRepositoryProvider).watchAllShifts();
});
