import 'dart:convert';

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

  /// Builds a human-readable modifier summary from the JSON snapshot.
  /// e.g. "部位：頭；型態：湯"
  String? _modifierSummary() {
    final snapshot = item.modifiersSnapshot;
    if (snapshot == null || snapshot.isEmpty) return null;
    try {
      final data = jsonDecode(snapshot) as Map<String, dynamic>;
      final groups = data['groups'] as List<dynamic>?;
      if (groups == null || groups.isEmpty) return null;
      return groups.map((g) {
        final groupName = g['groupName'] as String? ?? '';
        final optionName = g['optionName'] as String? ?? '';
        return '$groupName：$optionName';
      }).join('；');
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(cashierRepositoryProvider);
    final summary = _modifierSummary();

    return ListTile(
      dense: true,
      title: Text(item.nameSnapshot, style: const TextStyle(fontSize: 16)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatMoney(item.priceSnapshot)),
          if (summary != null)
            Text(
              summary,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
        ],
      ),
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
