import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../../../core/utils/money.dart';
import '../../application/backoffice_notifier.dart';
import '../../data/backoffice_repository.dart';

const double _kFabClearance = 88.0;

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
              padding: const EdgeInsets.only(bottom: _kFabClearance),
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
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showProductActions(context, ref, p, cats),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showProductActions(BuildContext context, WidgetRef ref,
      Product product, List<Category> categories) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('編輯'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showProductDialog(context, ref, product, categories);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('刪除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmDeleteProduct(context, ref, product);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteProduct(
      BuildContext context, WidgetRef ref, Product product) {
    showDialog<void>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('刪除商品'),
        content: Text('要刪除「${product.name}」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dlgCtx);
              ref
                  .read(backofficeRepositoryProvider)
                  .deleteProduct(product.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
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
      builder: (ctx) => _ProductDialog(
        existing: existing,
        nameCtrl: nameCtrl,
        priceCtrl: priceCtrl,
        isActive: isActive,
        selectedCatId: selectedCatId,
        categories: categories,
      ),
    );
  }
}

/// A stateful product dialog that also lets the user pick modifier groups.
class _ProductDialog extends ConsumerStatefulWidget {
  const _ProductDialog({
    required this.existing,
    required this.nameCtrl,
    required this.priceCtrl,
    required this.isActive,
    required this.selectedCatId,
    required this.categories,
  });

  final Product? existing;
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  final bool isActive;
  final int? selectedCatId;
  final List<Category> categories;

  @override
  ConsumerState<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends ConsumerState<_ProductDialog> {
  late bool _isActive;
  late int? _selectedCatId;
  late Set<int> _selectedGroupIds;
  bool _groupIdsLoaded = false;

  @override
  void initState() {
    super.initState();
    _isActive = widget.isActive;
    _selectedCatId = widget.selectedCatId;
    _selectedGroupIds = {};
    if (widget.existing != null) {
      _loadGroupIds();
    } else {
      _groupIdsLoaded = true;
    }
  }

  Future<void> _loadGroupIds() async {
    final ids = await ref
        .read(backofficeRepositoryProvider)
        .getGroupIdsForProduct(widget.existing!.id);
    if (mounted) {
      setState(() {
        _selectedGroupIds = ids.toSet();
        _groupIdsLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(allModifierGroupsProvider);

    return AlertDialog(
      title: Text(widget.existing == null ? '新增商品' : '編輯商品'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: widget.nameCtrl,
              decoration: const InputDecoration(labelText: '商品名稱'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.priceCtrl,
              decoration: const InputDecoration(labelText: '售價 (元)'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: const InputDecoration(labelText: '分類'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _selectedCatId,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('未分類')),
                    ...widget.categories.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedCatId = v),
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('啟用'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const Divider(),
            const Text(
              '選項群組（必選）',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            if (!_groupIdsLoaded)
              const Center(child: CircularProgressIndicator())
            else
              groupsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (groups) => groups.isEmpty
                    ? const Text(
                        '尚無選項群組，請先至後台建立',
                        style: TextStyle(color: Colors.grey),
                      )
                    : Column(
                        children: groups
                            .map((g) => CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(g.name),
                                  subtitle: Text(g.isActive ? '啟用' : '停用'),
                                  value: _selectedGroupIds.contains(g.id),
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _selectedGroupIds.add(g.id);
                                      } else {
                                        _selectedGroupIds.remove(g.id);
                                      }
                                    });
                                  },
                                ))
                            .toList(),
                      ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _groupIdsLoaded ? _save : null,
          child: const Text('儲存'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = widget.nameCtrl.text.trim();
    final price = int.tryParse(widget.priceCtrl.text) ?? 0;
    if (name.isEmpty || price <= 0) return;

    final repo = ref.read(backofficeRepositoryProvider);
    final productId = await repo.saveProduct(
      id: widget.existing?.id,
      name: name,
      price: price,
      isActive: _isActive,
      categoryId: _selectedCatId,
    );

    await repo.setProductModifierGroups(
        productId, _selectedGroupIds.toList());

    if (mounted) Navigator.pop(context);
  }
}
