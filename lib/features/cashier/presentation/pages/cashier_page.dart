import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/db/models.dart' as db;
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
    // Reset category selection to "All" each time the cashier page is opened.
    ref.read(selectedCategoryIdProvider.notifier).state = null;
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

    // If the currently selected category is deleted/deactivated, reset to
    // the first available category.  null means "All" and is always valid.
    ref.listen<AsyncValue<List<db.Category>>>(activeCategoriesProvider,
        (_, next) {
      next.whenData((cats) {
        if (cats.isEmpty) return;
        final current = ref.read(selectedCategoryIdProvider);
        final ids = cats.map((c) => c.id).toSet();
        if (current != null && !ids.contains(current)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref.read(selectedCategoryIdProvider.notifier).state = cats.first.id;
          });
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('AMA-POS 櫃台'),
        actions: [
          // 掛單/改名
          orderAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (order) => order != null
                ? IconButton(
                    icon: const Icon(Icons.bookmark_add_outlined),
                    tooltip: '掛單/改名',
                    onPressed: () =>
                        _showHoldDialog(context, ref, order),
                  )
                : const SizedBox.shrink(),
          ),
          // 取單 (full page)
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: '取單',
            onPressed: () => _guardedNavigateToUnpaidOrders(context, ref),
          ),
          // 新單
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '新單',
            onPressed: () => _guardedNewOrder(context, ref),
          ),
          // 刪除未結帳單
          orderAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (order) => order != null && order.isUnpaid
                ? IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red),
                    tooltip: '刪除未結帳單',
                    onPressed: () =>
                        _confirmDeleteOrder(context, ref, order.id),
                  )
                : const SizedBox.shrink(),
          ),
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
          onPressed: () => context.push('/cashier/unpaid-orders'),
        ),
      ],
    );
  }

  /// Shown in the right panel when an order is active.
  Widget _buildActiveOrderPanel(
      BuildContext context, WidgetRef ref, db.Order order) {
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
                  // Switch / 取單 (navigates to full page)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.list_alt),
                      label: const Text('取單'),
                      onPressed: () =>
                          _guardedNavigateToUnpaidOrders(context, ref),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('新單'),
                  onPressed: () => _guardedNewOrder(context, ref),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Hold dialog (掛單/改名)
  // ---------------------------------------------------------------------------

  void _showHoldDialog(BuildContext context, WidgetRef ref, db.Order order) {
    final controller =
        TextEditingController(text: order.holdLabel ?? '');
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        var isSaving = false;
        return StatefulBuilder(
          builder: (dialogCtx, setState) => AlertDialog(
            title: const Text('掛單／改名'),
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
                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final label = controller.text.trim();
                        setState(() => isSaving = true);
                        try {
                          await ref
                              .read(cashierRepositoryProvider)
                              .setHoldLabel(
                                  order.id, label.isEmpty ? null : label);
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('儲存失敗：$e')),
                            );
                          }
                          if (dialogCtx.mounted) {
                            setState(() => isSaving = false);
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('儲存'),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() => controller.dispose());
  }

  // ---------------------------------------------------------------------------
  // Delete current order (刪除未結帳單) – hard delete
  // ---------------------------------------------------------------------------

  void _confirmDeleteOrder(
      BuildContext context, WidgetRef ref, int orderId) {
    showDialog(
      context: context,
      builder: (ctx) {
        var isDeleting = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('刪除未結帳單'),
            content: const Text('確定要刪除目前的未結帳單嗎？此操作無法復原。'),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: isDeleting
                    ? null
                    : () async {
                        setDialogState(() => isDeleting = true);
                        try {
                          await ref
                              .read(cashierRepositoryProvider)
                              .deleteOrder(orderId);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ref.read(currentOrderIdProvider.notifier).state =
                                null;
                            setState(() {
                              _isDineIn = false;
                              _selectedTable = null;
                            });
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('刪除失敗：$e')),
                            );
                          }
                          if (ctx.mounted) {
                            setDialogState(() => isDeleting = false);
                          }
                        }
                      },
                child: isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : const Text('刪除'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Guarded navigation: prompt when current order is unlabeled and has items
  // ---------------------------------------------------------------------------

  /// Returns true if the current order is "at risk" (has items but no label),
  /// which means we should warn before leaving it.
  Future<bool> _currentOrderNeedsGuard(WidgetRef ref) async {
    final orderId = ref.read(currentOrderIdProvider);
    if (orderId == null) return false;
    final repo = ref.read(cashierRepositoryProvider);
    final order = await repo.getOrderById(orderId);
    if (order == null || !order.isUnpaid) return false;
    if (order.holdLabel != null && order.holdLabel!.isNotEmpty) return false;
    final items = await repo.getOrderItems(orderId);
    return items.isNotEmpty;
  }

  /// Shows the UX guardrail dialog.
  /// Returns true if caller should proceed (Save or Discard was chosen).
  Future<bool> _showGuardDialog(
      BuildContext context, WidgetRef ref, db.Order order) async {
    final result = await showDialog<_GuardDialogResult>(
      context: context,
      builder: (ctx) => _GuardDialog(order: order),
    );

    if (result == null || result.action == _GuardAction.cancel) return false;

    if (result.action == _GuardAction.save) {
      final label = result.label.trim();
      await ref
          .read(cashierRepositoryProvider)
          .setHoldLabel(order.id, label.isEmpty ? null : label);
      return true;
    }

    // Discard: hard-delete the current order.
    if (result.action == _GuardAction.discard) {
      if (!mounted) {
        // Widget was unmounted while dialog was open – cannot safely update
        // state.  Show a user-visible message if possible and bail out.
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('目前無法捨棄訂單，請直接取消或掛單。')),
          );
        }
        return false;
      }
      try {
        await ref.read(cashierRepositoryProvider).deleteOrder(order.id);
        ref.read(currentOrderIdProvider.notifier).state = null;
        if (mounted) {
          setState(() {
            _isDineIn = false;
            _selectedTable = null;
          });
        }
        return true;
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('目前無法捨棄訂單，請直接取消或掛單。')),
          );
        }
        return false;
      }
    }

    return false;
  }

  /// Navigates to the unpaid orders full page, with guardrail if needed.
  Future<void> _guardedNavigateToUnpaidOrders(
      BuildContext context, WidgetRef ref) async {
    final needsGuard = await _currentOrderNeedsGuard(ref);
    if (needsGuard && mounted) {
      final orderId = ref.read(currentOrderIdProvider);
      if (orderId == null) {
        if (mounted) context.push('/cashier/unpaid-orders');
        return;
      }
      final repo = ref.read(cashierRepositoryProvider);
      final order = await repo.getOrderById(orderId);
      if (order == null) {
        if (mounted) context.push('/cashier/unpaid-orders');
        return;
      }
      final proceed = await _showGuardDialog(context, ref, order);
      if (!proceed) return;
    }
    if (mounted) context.push('/cashier/unpaid-orders');
  }

  /// Starts a new order context, with guardrail if needed.
  Future<void> _guardedNewOrder(BuildContext context, WidgetRef ref) async {
    final needsGuard = await _currentOrderNeedsGuard(ref);
    if (needsGuard && mounted) {
      final orderId = ref.read(currentOrderIdProvider);
      if (orderId != null) {
        final repo = ref.read(cashierRepositoryProvider);
        final order = await repo.getOrderById(orderId);
        if (order != null) {
          final proceed = await _showGuardDialog(context, ref, order);
          if (!proceed) return;
        }
      }
    }
    // Clear current order so the cashier enters "new order" state.
    ref.read(currentOrderIdProvider.notifier).state = null;
    if (mounted) {
      setState(() {
        _isDineIn = false;
        _selectedTable = null;
      });
    }
  }
}

// =============================================================================
// UX guardrail helpers
// =============================================================================

enum _GuardAction { save, discard, cancel }

/// Return value from [_GuardDialog]: the chosen action plus the label text
/// the user may have typed (only meaningful for [_GuardAction.save]).
class _GuardDialogResult {
  const _GuardDialogResult(this.action, this.label);
  final _GuardAction action;
  final String label;
}

class _GuardDialog extends StatefulWidget {
  const _GuardDialog({required this.order});

  final db.Order order;

  @override
  State<_GuardDialog> createState() => _GuardDialogState();
}

class _GuardDialogState extends State<_GuardDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('目前訂單尚未命名'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('目前的未結帳單尚未設定桌號／備註，要先儲存還是捨棄？'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '桌號／備註（選填）',
              hintText: '例如：1號桌、外帶王先生',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(
              context, const _GuardDialogResult(_GuardAction.cancel, '')),
          child: const Text('取消'),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => Navigator.pop(
              context, const _GuardDialogResult(_GuardAction.discard, '')),
          child: const Text('捨棄'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
              context,
              _GuardDialogResult(_GuardAction.save, _controller.text)),
          child: const Text('儲存掛單'),
        ),
      ],
    );
  }
}
