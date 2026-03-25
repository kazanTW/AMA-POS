import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/backoffice/presentation/pages/backoffice_home_page.dart';
import '../features/backoffice/presentation/pages/categories_page.dart';
import '../features/backoffice/presentation/pages/import_export_page.dart';
import '../features/backoffice/presentation/pages/products_page.dart';
import '../features/backoffice/presentation/pages/reports_page.dart';
import '../features/backoffice/presentation/pages/shifts_page.dart';
import '../features/cashier/presentation/pages/cashier_page.dart';
import '../features/cashier/presentation/pages/checkout_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/cashier',
    routes: [
      GoRoute(
        path: '/cashier',
        builder: (context, state) => const CashierPage(),
      ),
      GoRoute(
        path: '/cashier/checkout',
        builder: (context, state) {
          final orderId = state.uri.queryParameters['orderId']!;
          return CheckoutPage(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/backoffice',
        builder: (context, state) => const BackofficeHomePage(),
        routes: [
          GoRoute(
            path: 'categories',
            builder: (context, state) => const CategoriesPage(),
          ),
          GoRoute(
            path: 'products',
            builder: (context, state) => const ProductsPage(),
          ),
          GoRoute(
            path: 'shifts',
            builder: (context, state) => const ShiftsPage(),
          ),
          GoRoute(
            path: 'reports',
            builder: (context, state) => const ReportsPage(),
          ),
          GoRoute(
            path: 'import-export',
            builder: (context, state) => const ImportExportPage(),
          ),
        ],
      ),
    ],
  );
});
