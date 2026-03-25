import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../application/backoffice_notifier.dart';
import '../../data/backoffice_repository.dart';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(allCategoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('商品分類')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('新增分類'),
        onPressed: () => _showCategoryDialog(context, ref, null),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (cats) => ListView.builder(
          itemCount: cats.length,
          itemBuilder: (ctx, i) {
            final cat = cats[i];
            return ListTile(
              leading: Icon(
                Icons.category,
                color: cat.isActive ? null : Colors.grey,
              ),
              title: Text(
                cat.name,
                style:
                    TextStyle(color: cat.isActive ? null : Colors.grey),
              ),
              subtitle: Text(cat.isActive ? '啟用中' : '已停用'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () =>
                        _showCategoryDialog(context, ref, cat),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => ref
                        .read(backofficeRepositoryProvider)
                        .deleteCategory(cat.id),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showCategoryDialog(
      BuildContext context, WidgetRef ref, Category? existing) {
    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    bool isActive = existing?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? '新增分類' : '編輯分類'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration:
                    const InputDecoration(labelText: '分類名稱'),
                autofocus: true,
              ),
              SwitchListTile(
                title: const Text('啟用'),
                value: isActive,
                onChanged: (v) => setState(() => isActive = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                ref.read(backofficeRepositoryProvider).saveCategory(
                      id: existing?.id,
                      name: name,
                      isActive: isActive,
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
