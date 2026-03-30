import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/utils/datetime_utils.dart';
import '../../../../core/utils/money.dart';
import '../../application/cashier_notifier.dart';
import '../../data/cashier_repository.dart';
import '../widgets/order_item_tile.dart';
import '../widgets/product_grid.dart';
import '../../../backoffice/data/backoffice_repository.dart';

class CashierPage extends ConsumerStatefulWidget {
  const CashierPage({super.key});

  @override
  ConsumerState<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends ConsumerState<CashierPage> {
  bool _isDineIn = false;
  int? _selectedTable;
  int _tableCount = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadTableCount);
  }

  Future<void> _loadTableCount() async {
    final config =
        await ref.read(backofficeRepositoryProvider).getMerchantConfig();
    if (mounted) {
      setState(() => _tableCount = config.tableCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(activeOrderProvider);
    final categoriesAsync = ref.watch(activeCategoriesProvider);
    final selectedCatId = ref.watch(selectedCategoryIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AMA-POS 櫃台'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.settings),
            label: const Text('後台'),
            onPressed: () => context.go('/backoffice'),
          ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (order) {
          if (order == null) {
            Future.microtask(() async {
              await ref.read(cashierRepositoryProvider).getOrCreateOrder();
            });
            return const Center(child: CircularProgressIndicator());
          }

          final itemsAsync = ref.watch(orderItemsProvider(order.id));
          final canCheckout = order.total > 0 &&
              (!_isDineIn || _selectedTable != null);

          return Row(
            children: [
              // Left: Category list
              SizedBox(
                width: 140,
                child: Card(
                  margin: EdgeInsets.zero,
                  shape: const RoundedRectangleBorder(),
                  child: categoriesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => const SizedBox.shrink(),
                    data: (categories) => ListView(
                      children: [
                        ListTile(
                          title: const Text('全部'),
                          selected: selectedCatId == null,
                          onTap: () => ref
                              .read(selectedCategoryIdProvider.notifier)
                              .state = null,
                        ),
                        ...categories.map(
                          (cat) => ListTile(
                            title: Text(cat.name),
                            selected: selectedCatId == cat.id,
                            onTap: () => ref
                                .read(selectedCategoryIdProvider.notifier)
                                .state = cat.id,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Middle: Product grid
              Expanded(
                flex: 3,
                child: ProductGrid(orderId: order.id),
              ),
              // Right: Order panel
              SizedBox(
                width: 360,
                child: Card(
                  margin: EdgeInsets.zero,
                  shape: const RoundedRectangleBorder(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Order type toggle
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              label: Text('外帶'),
                              icon: Icon(Icons.shopping_bag_outlined),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text('內用'),
                              icon: Icon(Icons.restaurant),
                            ),
                          ],
                          selected: {_isDineIn},
                          onSelectionChanged: (vals) {
                            final isDineIn = vals.first;
                            setState(() {
                              _isDineIn = isDineIn;
                              if (!isDineIn) _selectedTable = null;
                            });
                            ref
                                .read(cashierRepositoryProvider)
                                .updateOrderType(
                                  order.id,
                                  isDineIn ? 'dineIn' : 'takeOut',
                                  tableNo: isDineIn && _selectedTable != null
                                      ? _selectedTable.toString()
                                      : null,
                                );
                          },
                        ),
                      ),
                      // Table number dropdown (dineIn only)
                      if (_isDineIn)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _tableCount == 0
                              ? const Text(
                                  '請先至後台「商家設定」設定桌數',
                                  style: TextStyle(color: Colors.orange),
                                )
                              : DropdownButtonFormField<int>(
                                  value: _selectedTable,
                                  decoration: const InputDecoration(
                                    labelText: '桌號',
                                    prefixIcon:
                                        Icon(Icons.table_restaurant),
                                    border: OutlineInputBorder(),
                                  ),
                                  hint: const Text('請選擇桌號'),
                                  items: List.generate(
                                    _tableCount,
                                    (i) => DropdownMenuItem(
                                      value: i + 1,
                                      child: Text('${i + 1} 號桌'),
                                    ),
                                  ),
                                  onChanged: (val) {
                                    setState(() => _selectedTable = val);
                                    ref
                                        .read(cashierRepositoryProvider)
                                        .updateOrderType(
                                          order.id,
                                          'dineIn',
                                          tableNo: val?.toString(),
                                        );
                                  },
                                ),
                        ),
                      // Hint when dine-in but no table selected
                      if (_isDineIn &&
                          _selectedTable == null &&
                          _tableCount > 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: Text(
                            '請選擇桌號才能結帳',
                            style: TextStyle(
                                color: Colors.red, fontSize: 12),
                          ),
                        ),
                      const Divider(),
                      // Order info: serial number and time
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '流水號：${order.orderNo}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '時間：${formatDateTime(order.createdAt)}',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      // Order items
                      Expanded(
                        child: itemsAsync.when(
                          loading: () => const Center(
                              child: CircularProgressIndicator()),
                          error: (e, _) => Center(child: Text('Error: $e')),
                          data: (items) => items.isEmpty
                              ? const Center(
                                  child: Text(
                                    '尚無品項\n請從商品區選取',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: items.length,
                                  itemBuilder: (ctx, i) => OrderItemTile(
                                    item: items[i],
                                    orderId: order.id,
                                  ),
                                ),
                        ),
                      ),
                      const Divider(),
                      // Total & checkout
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('合計',
                                    style: TextStyle(fontSize: 18)),
                                Text(
                                  formatMoney(order.total),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                icon: const Icon(Icons.payment),
                                label: const Text('結帳',
                                    style: TextStyle(fontSize: 18)),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                ),
                                onPressed: canCheckout
                                    ? () async {
                                        await ref
                                            .read(cashierRepositoryProvider)
                                            .setOrderPendingPayment(order.id);
                                        if (context.mounted) {
                                          context.push(
                                            '/cashier/checkout?orderId=${order.id}',
                                          );
                                        }
                                      }
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('清除訂單'),
                                onPressed: () =>
                                    _confirmClearOrder(context, ref, order.id),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmClearOrder(
      BuildContext context, WidgetRef ref, int orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除訂單'),
        content: const Text('確定要清除目前的訂單嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final db = ref.read(appDatabaseProvider);
              await db.clearOrderItems(orderId);
              await db.updateOrder(orderId, {
                'subtotal': 0,
                'total': 0,
                'type': 'takeOut',
                'tableNo': null,
                'updatedAt': DateTime.now().millisecondsSinceEpoch,
              });
              if (mounted) {
                setState(() {
                  _isDineIn = false;
                  _selectedTable = null;
                });
              }
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }
}
