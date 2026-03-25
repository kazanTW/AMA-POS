import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/utils/money.dart';
import '../../application/backoffice_notifier.dart';
import '../../data/backoffice_repository.dart';

class ProductsPage extends ConsumerWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(allProductsProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('商品管理')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('新增商品'),
        onPressed: () => categoriesAsync.whenData(
          (cats) => _showProductDialog(context, ref, null, cats),
        ),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (products) => categoriesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
          data: (cats) {
            final catMap = {for (final c in cats) c.id: c.name};
            return ListView.builder(
              itemCount: products.length,
              itemBuilder: (ctx, i) {
                final p = products[i];
                return ListTile(
                  leading: Icon(
                    Icons.inventory_2_outlined,
                    color: p.isActive ? null : Colors.grey,
                  ),
                  title: Text(
                    p.name,
                    style: TextStyle(
                        color: p.isActive ? null : Colors.grey),
                  ),
                  subtitle: Text(
                    '${catMap[p.categoryId] ?? '未分類'} · ${formatMoney(p.price)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            _showProductDialog(context, ref, p, cats),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => ref
                            .read(backofficeRepositoryProvider)
                            .deleteProduct(p.id),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showProductDialog(BuildContext context, WidgetRef ref,
      Product? existing, List<Category> categories) {
    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    final priceCtrl =
        TextEditingController(text: existing?.price.toString() ?? '');
    bool isActive = existing?.isActive ?? true;
    int? selectedCatId = existing?.categoryId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? '新增商品' : '編輯商品'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: '商品名稱'),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceCtrl,
                  decoration:
                      const InputDecoration(labelText: '售價 (元)'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: const InputDecoration(labelText: '分類'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: selectedCatId,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('未分類')),
                        ...categories.map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            )),
                      ],
                      onChanged: (v) => setState(() => selectedCatId = v),
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('啟用'),
                  value: isActive,
                  onChanged: (v) => setState(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final price = int.tryParse(priceCtrl.text) ?? 0;
                if (name.isEmpty || price <= 0) return;
                ref.read(backofficeRepositoryProvider).saveProduct(
                      id: existing?.id,
                      name: name,
                      price: price,
                      isActive: isActive,
                      categoryId: selectedCatId,
                    );
                Navigator.pop(ctx);
              },
              child: const Text('儲存'),
            ),
          ],
        ),
      ),
    );
  }
}
