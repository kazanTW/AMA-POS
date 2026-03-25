import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/utils/datetime_utils.dart';
import '../../../../core/utils/money.dart';
import '../../application/backoffice_notifier.dart';
import '../../data/backoffice_repository.dart';

class ShiftsPage extends ConsumerWidget {
  const ShiftsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftsAsync = ref.watch(allShiftsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('班次管理')),
      floatingActionButton: FutureBuilder<Shift?>(
        future: ref.read(backofficeRepositoryProvider).getOpenShift(),
        builder: (ctx, snap) {
          final openShift = snap.data;
          if (openShift == null) {
            return FloatingActionButton.extended(
              icon: const Icon(Icons.play_arrow),
              label: const Text('開班'),
              onPressed: () => _openShiftDialog(context, ref),
            );
          }
          return FloatingActionButton.extended(
            icon: const Icon(Icons.stop),
            label: const Text('關班'),
            backgroundColor: Colors.red,
            onPressed: () => _closeShiftDialog(context, ref, openShift),
          );
        },
      ),
      body: shiftsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (shifts) => ListView.builder(
          itemCount: shifts.length,
          itemBuilder: (ctx, i) {
            final s = shifts[i];
            final isOpen = s.closedAt == null;
            return Card(
              margin: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
              child: ListTile(
                leading: Icon(
                  isOpen ? Icons.lock_open : Icons.lock,
                  color: isOpen ? Colors.green : Colors.grey,
                ),
                title: Text('開班：${formatDateTime(s.openedAt)}'),
                subtitle: isOpen
                    ? const Text(
                        '班次進行中',
                        style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold),
                      )
                    : Text('關班：${formatDateTime(s.closedAt!)}'),
                trailing: isOpen
                    ? null
                    : FutureBuilder<Map<String, dynamic>>(
                        future: ref
                            .read(backofficeRepositoryProvider)
                            .getShiftStats(s.id),
                        builder: (ctx, snap) {
                          if (!snap.hasData) {
                            return const SizedBox.shrink();
                          }
                          final stats = snap.data!;
                          return Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            crossAxisAlignment:
                                CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${stats['orderCount']} 筆',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(formatMoney(
                                  stats['salesTotal'] as int)),
                            ],
                          );
                        },
                      ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openShiftDialog(BuildContext context, WidgetRef ref) {
    final cashCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('開班'),
        content: TextField(
          controller: cashCtrl,
          decoration: const InputDecoration(
            labelText: '開班現金 (選填)',
            prefixText: 'NT\$ ',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final cash = int.tryParse(cashCtrl.text);
              await ref
                  .read(backofficeRepositoryProvider)
                  .openShift(openingCash: cash);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('開班'),
          ),
        ],
      ),
    );
  }

  void _closeShiftDialog(
      BuildContext context, WidgetRef ref, Shift shift) {
    final cashCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('關班'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cashCtrl,
              decoration: const InputDecoration(
                labelText: '結班現金 (選填)',
                prefixText: 'NT\$ ',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              decoration:
                  const InputDecoration(labelText: '備註 (選填)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () async {
              final cash = int.tryParse(cashCtrl.text);
              final note = noteCtrl.text.trim();
              await ref
                  .read(backofficeRepositoryProvider)
                  .closeShift(
                    shift,
                    closingCash: cash,
                    note: note.isEmpty ? null : note,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('關班'),
          ),
        ],
      ),
    );
  }
}
