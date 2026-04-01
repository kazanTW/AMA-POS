import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/utils/money.dart';
import '../../application/cashier_notifier.dart';
import '../../data/cashier_repository.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _receivedController = TextEditingController();
  int _amountReceived = 0;

  int get _orderId => int.parse(widget.orderId);

  @override
  void dispose() {
    _receivedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(orderItemsProvider(_orderId));

    return FutureBuilder(
      future: ref.read(appDatabaseProvider).getOrderById(_orderId),
      builder: (context, snapshot) {
        final order = snapshot.data;
        final amountDue = order?.total ?? 0;
        final change = _amountReceived >= amountDue
            ? _amountReceived - amountDue
            : 0;

        return Scaffold(
          appBar: AppBar(
            title: const Text('結帳'),
            leading: BackButton(
              onPressed: () async {
                await ref
                    .read(cashierRepositoryProvider)
                    .setOrderOpen(_orderId);
                if (context.mounted) context.pop();
              },
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '訂單品項',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                              const Divider(),
                              itemsAsync.when(
                                loading: () =>
                                    const CircularProgressIndicator(),
                                error: (e, _) => Text('$e'),
                                data: (items) => Column(
                                  children: items
                                      .map(
                                        (item) => Padding(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 4),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                    '${item.nameSnapshot} × ${item.qty}'),
                                              ),
                                              Text(formatMoney(
                                                  item.lineTotal)),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('應付金額',
                                      style: TextStyle(fontSize: 20)),
                                  Text(
                                    formatMoney(amountDue),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _receivedController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  labelText: '收款金額',
                                  prefixText: 'NT\$ ',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 20),
                                ),
                                style: const TextStyle(fontSize: 24),
                                onChanged: (v) {
                                  setState(() {
                                    _amountReceived =
                                        int.tryParse(v) ?? 0;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [500, 1000].map((amt) {
                                  return OutlinedButton(
                                    onPressed: () {
                                      int newAmt = amt;
                                      while (newAmt < amountDue) {
                                        newAmt += amt;
                                      }
                                      setState(() {
                                        _amountReceived = newAmt;
                                        _receivedController.text =
                                            newAmt.toString();
                                      });
                                    },
                                    child: Text('NT\$ $amt'),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('找零',
                                      style: TextStyle(fontSize: 20)),
                                  Text(
                                    _amountReceived >= amountDue
                                        ? formatMoney(change)
                                        : '---',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: _amountReceived >= amountDue
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        icon: const Icon(Icons.check_circle),
                        label: const Text('確認收款',
                            style: TextStyle(fontSize: 20)),
                        style: FilledButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 20),
                          backgroundColor: Colors.green,
                        ),
                        onPressed: _amountReceived < amountDue
                            ? null
                            : () => _confirmPayment(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmPayment(BuildContext context) async {
    await ref.read(cashierRepositoryProvider).completePayment(
          orderId: _orderId,
          amountReceived: _amountReceived,
        );

    if (!context.mounted) return;

    // Reset cashier to empty state; next order starts on first product tap.
    ref.read(currentOrderIdProvider.notifier).state = null;

    if (!context.mounted) return;
    context.go('/cashier');
  }
}
