import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/models.dart';
import '../../application/backoffice_notifier.dart';
import '../../data/backoffice_repository.dart';

const double _kFabClearance = 88.0;

class ModifierOptionsPage extends ConsumerWidget {
  const ModifierOptionsPage({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  final int groupId;
  final String groupName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optionsAsync = ref.watch(modifierOptionsByGroupProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: Text('$groupName 的選項')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('新增選項'),
        onPressed: () => _showOptionDialog(context, ref, null),
      ),
      body: optionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (options) => options.isEmpty
            ? const Center(child: Text('尚無選項'))
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: _kFabClearance),
                itemCount: options.length,
                itemBuilder: (ctx, i) {
                  final o = options[i];
                  return ListTile(
                    leading: Icon(
                      Icons.radio_button_checked,
                      color: o.isActive ? null : Colors.grey,
                    ),
                    title: Text(
                      o.name,
                      style:
                          TextStyle(color: o.isActive ? null : Colors.grey),
                    ),
                    subtitle: Text(o.isActive ? '啟用' : '停用'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showOptionActions(context, ref, o),
                  );
                },
              ),
      ),
    );
  }

  void _showOptionActions(
      BuildContext context, WidgetRef ref, ModifierOption option) {
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
                _showOptionDialog(context, ref, option);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title:
                  const Text('刪除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmDelete(context, ref, option);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, ModifierOption option) {
    showDialog<void>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('刪除選項'),
        content: Text('要刪除「${option.name}」嗎？'),
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
                  .deleteModifierOption(option.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  void _showOptionDialog(
      BuildContext context, WidgetRef ref, ModifierOption? existing) {
    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    bool isActive = existing?.isActive ?? true;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? '新增選項' : '編輯選項'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '選項名稱'),
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
                ref.read(backofficeRepositoryProvider).saveModifierOption(
                      id: existing?.id,
                      groupId: groupId,
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
