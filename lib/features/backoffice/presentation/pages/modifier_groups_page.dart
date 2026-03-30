import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/db/models.dart';
import '../../application/backoffice_notifier.dart';
import '../../data/backoffice_repository.dart';

const double _kFabClearance = 88.0;

class ModifierGroupsPage extends ConsumerWidget {
  const ModifierGroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(allModifierGroupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('選項群組管理')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('新增群組'),
        onPressed: () => _showGroupDialog(context, ref, null),
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (groups) => groups.isEmpty
            ? const Center(child: Text('尚無選項群組'))
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: _kFabClearance),
                itemCount: groups.length,
                itemBuilder: (ctx, i) {
                  final g = groups[i];
                  return ListTile(
                    leading: Icon(
                      Icons.tune,
                      color: g.isActive ? null : Colors.grey,
                    ),
                    title: Text(
                      g.name,
                      style:
                          TextStyle(color: g.isActive ? null : Colors.grey),
                    ),
                    subtitle: Text(g.isActive ? '啟用' : '停用'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showGroupActions(context, ref, g),
                  );
                },
              ),
      ),
    );
  }

  void _showGroupActions(
      BuildContext context, WidgetRef ref, ModifierGroup group) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('管理選項'),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.push(
                    '/backoffice/modifier-groups/${group.id}/options',
                    extra: group.name);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('編輯'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showGroupDialog(context, ref, group);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title:
                  const Text('刪除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmDelete(context, ref, group);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, ModifierGroup group) {
    showDialog<void>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('刪除選項群組'),
        content: Text('要刪除「${group.name}」及其所有選項嗎？'),
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
                  .deleteModifierGroup(group.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  void _showGroupDialog(
      BuildContext context, WidgetRef ref, ModifierGroup? existing) {
    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    bool isActive = existing?.isActive ?? true;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? '新增選項群組' : '編輯選項群組'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '群組名稱'),
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
                ref.read(backofficeRepositoryProvider).saveModifierGroup(
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
