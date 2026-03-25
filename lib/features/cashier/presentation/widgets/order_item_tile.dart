import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/utils/money.dart';
import '../../data/cashier_repository.dart';

class OrderItemTile extends ConsumerWidget {
  const OrderItemTile({
    super.key,
    required this.item,
    required this.orderId,
  });

  final OrderItem item;
  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(cashierRepositoryProvider);
    return ListTile(
      dense: true,
      title: Text(item.nameSnapshot, style: const TextStyle(fontSize: 16)),
      subtitle: Text(formatMoney(item.priceSnapshot)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () =>
                repo.updateItemQty(orderId, item.id, item.qty - 1),
          ),
          Text(
            '${item.qty}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () =>
                repo.updateItemQty(orderId, item.id, item.qty + 1),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => repo.removeItem(orderId, item.id),
          ),
          SizedBox(
            width: 80,
            child: Text(
              formatMoney(item.lineTotal),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
