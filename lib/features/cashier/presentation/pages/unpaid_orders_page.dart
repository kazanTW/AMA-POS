import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/db/models.dart';
import '../../../../core/utils/datetime_utils.dart';
import '../../../../core/utils/money.dart';
import '../../application/cashier_notifier.dart';
import '../../data/cashier_repository.dart';

/// Full-page list of all unpaid (open / pendingPayment) orders.
/// Phase 2 – 取單 destination (A1: full page).
class UnpaidOrdersPage extends ConsumerWidget {
  const UnpaidOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(unpaidOrdersProvider);
    final currentOrderId = ref.watch(currentOrderIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('未結帳訂單'),
        leading: BackButton(onPressed: () => context.go('/cashier')),
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '目前沒有未結帳訂單',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: orders.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final order = orders[i];
              final isActive = order.id == currentOrderId;
              final label =
                  (order.holdLabel != null && order.holdLabel!.isNotEmpty)
                      ? order.holdLabel!
                      : '(未命名) …${order.id}';

              return ListTile(
                selected: isActive,
                selectedTileColor:
                    Theme.of(context).colorScheme.primaryContainer,
                leading: CircleAvatar(
                  backgroundColor: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    isActive ? Icons.bookmark : Icons.receipt_outlined,
                    color: isActive
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                title: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: _OrderSubtitle(order: order),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: '刪除此訂單',
                  onPressed: () =>
                      _confirmDelete(context, ref, order, currentOrderId),
                ),
                onTap: () {
                  ref.read(currentOrderIdProvider.notifier).state = order.id;
                  context.go('/cashier');
                },
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Order order,
    int? currentOrderId,
  ) {
    final label =
        (order.holdLabel != null && order.holdLabel!.isNotEmpty)
            ? order.holdLabel!
            : '(未命名) …${order.id}';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除訂單'),
        content: Text('確定要刪除「$label」嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(cashierRepositoryProvider)
                  .deleteOrder(order.id);
              // If the deleted order was the active one, deselect it.
              if (currentOrderId == order.id) {
                ref.read(currentOrderIdProvider.notifier).state = null;
              }
            },
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }
}

/// Subtitle showing createdAt time, item count, and total amount.
class _OrderSubtitle extends ConsumerWidget {
  const _OrderSubtitle({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(orderItemsProvider(order.id));

    return itemsAsync.when(
      loading: () => Text(formatDateTime(order.createdAt)),
      error: (_, __) => Text(formatDateTime(order.createdAt)),
      data: (items) {
        final itemCount = items.fold<int>(0, (sum, i) => sum + i.qty);
        return Text(
          '${formatDateTime(order.createdAt)}　'
          '$itemCount 件　'
          '合計 ${formatMoney(order.total)}',
        );
      },
    );
  }
}
