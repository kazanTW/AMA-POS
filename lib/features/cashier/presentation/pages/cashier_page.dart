import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/db/models.dart';
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
    Future.microtask(_restoreActiveOrder);
  }

  Future<void> _loadTableCount() async {
    final config =
        await ref.read(backofficeRepositoryProvider).getMerchantConfig();
    if (mounted) {
      setState(() => _tableCount = config.tableCount);
    }
  }

  /// On startup, restore the most-recently-updated unpaid order (if any) so
  /// the cashier doesn't lose work after a navigation or app restart.
  Future<void> _restoreActiveOrder() async {
    if (ref.read(currentOrderIdProvider) != null) return;
    final orders =
        await ref.read(cashierRepositoryProvider).getUnpaidOrders();
    if (orders.isNotEmpty && mounted) {
      final order = orders.first;
      // If a crash left an order in pendingPayment, reset it to open.
      if (order.status == 'pendingPayment') {
        await ref
            .read(cashierRepositoryProvider)
            .setOrderOpen(order.id);
      }
      ref.read(currentOrderIdProvider.notifier).state = order.id;
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
              // Middle: Product grid (always shown; creates order on first tap)
              const Expanded(
                flex: 3,
                child: ProductGrid(),
              ),
              // Right: Order panel
              SizedBox(
                width: 360,
                child: Card(
                  margin: EdgeInsets.zero,
                  shape: const RoundedRectangleBorder(),
                  child: order == null
                      ? _buildEmptyOrderPanel(context, ref)
                      : _buildActiveOrderPanel(context, ref, order),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Shown in the right panel when no order is currently selected.
  Widget _buildEmptyOrderPanel(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        const Text(
          '尚無進行中訂單\n請點選商品開始點餐',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          icon: const Icon(Icons.list_alt),
          label: const Text('取單'),
          onPressed: () => _showSwitchDialog(context, ref),
        ),
      ],
    );
  }

  /// Shown in the right panel when an order is active.
  Widget _buildActiveOrderPanel(
      BuildContext context, WidgetRef ref, Order order) {
    final itemsAsync = ref.watch(orderItemsProvider(order.id));
    final canCheckout =
        order.total > 0 && (!_isDineIn || _selectedTable != null);

    return Column(
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
                      prefixIcon: Icon(Icons.table_restaurant),
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
        if (_isDineIn && _selectedTable == null && _tableCount > 0)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              '請選擇桌號才能結帳',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        const Divider(),
        // Order info: serial number, hold label, and time
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '流水號：${order.orderNo}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '時間：${formatDateTime(order.createdAt)}',
                    style:
                        const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
              if (order.holdLabel != null && order.holdLabel!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '備註：${order.holdLabel}',
                    style: const TextStyle(
                        fontSize: 13, color: Colors.deepOrange),
                  ),
                ),
            ],
          ),
        ),
        // Order items
        Expanded(
          child: itemsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
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
        // Total & action buttons
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('合計', style: TextStyle(fontSize: 18)),
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
              // Checkout button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.payment),
                  label: const Text('結帳',
                      style: TextStyle(fontSize: 18)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
              Row(
                children: [
                  // Hold / 掛單
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: const Text('掛單'),
                      onPressed: () =>
                          _showHoldDialog(context, ref, order),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Switch / 取單
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.list_alt),
                      label: const Text('取單'),
                      onPressed: () =>
                          _showSwitchDialog(context, ref),
                    ),
                  ),
                ],
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
    );
  }

  // ---------------------------------------------------------------------------
  // Hold dialog (掛單)
  // ---------------------------------------------------------------------------

  void _showHoldDialog(BuildContext context, WidgetRef ref, Order order) {
    final controller =
        TextEditingController(text: order.holdLabel ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('掛單'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '桌號／備註',
            hintText: '例如：1號桌、外帶王先生',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final label = controller.text.trim();
              Navigator.pop(ctx);
              await ref
                  .read(cashierRepositoryProvider)
                  .setHoldLabel(order.id, label.isEmpty ? null : label);
              // Deselect current order so cashier starts fresh.
              ref.read(currentOrderIdProvider.notifier).state = null;
              setState(() {
                _isDineIn = false;
                _selectedTable = null;
              });
            },
            child: const Text('掛單確認'),
          ),
        ],
      ),
    ).whenComplete(() => controller.dispose());
  }

  // ---------------------------------------------------------------------------
  // Switch dialog (取單)
  // ---------------------------------------------------------------------------

  void _showSwitchDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _SwitchOrderDialog(
        onSelect: (orderId) {
          ref.read(currentOrderIdProvider.notifier).state = orderId;
          setState(() {
            _isDineIn = false;
            _selectedTable = null;
          });
        },
        currentOrderId: ref.read(currentOrderIdProvider),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Clear order dialog
  // ---------------------------------------------------------------------------

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

// =============================================================================
// Switch-order dialog widget
// =============================================================================

class _SwitchOrderDialog extends ConsumerWidget {
  const _SwitchOrderDialog({
    required this.onSelect,
    required this.currentOrderId,
  });

  final void Function(int orderId) onSelect;
  final int? currentOrderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(unpaidOrdersProvider);

    return AlertDialog(
      title: const Text('取單 — 未結帳訂單'),
      content: SizedBox(
        width: 400,
        child: ordersAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
          data: (orders) {
            if (orders.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '目前沒有未結帳訂單',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              itemCount: orders.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final o = orders[i];
                final isActive = o.id == currentOrderId;
                return ListTile(
                  selected: isActive,
                  leading: isActive
                      ? const Icon(Icons.bookmark,
                          color: Colors.deepOrange)
                      : const Icon(Icons.receipt_outlined),
                  title: Text(
                    o.holdLabel != null && o.holdLabel!.isNotEmpty
                        ? o.holdLabel!
                        : o.orderNo,
                  ),
                  subtitle: Text(
                    '${formatDateTime(o.createdAt)}　合計 ${formatMoney(o.total)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red),
                    tooltip: '作廢此訂單',
                    onPressed: () => _confirmVoid(context, ref, o.id),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onSelect(o.id);
                  },
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('關閉'),
        ),
      ],
    );
  }

  void _confirmVoid(BuildContext context, WidgetRef ref, int orderId) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('作廢訂單'),
        content: const Text('確定要作廢此訂單嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(cashierRepositoryProvider)
                  .voidOrder(orderId);
              // If we just voided the active order, deselect it.
              if (ref.read(currentOrderIdProvider) == orderId) {
                ref.read(currentOrderIdProvider.notifier).state = null;
              }
            },
            child: const Text('作廢'),
          ),
        ],
      ),
    );
  }
}
