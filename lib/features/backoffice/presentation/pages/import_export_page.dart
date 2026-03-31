import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backoffice_repository.dart';

class ImportExportPage extends ConsumerWidget {
  const ImportExportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('匯入/匯出設定')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '設定檔包含：商家設定、分類、商品',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const Text(
                            '（不含訂單與交易記錄）',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          FilledButton.icon(
                            icon: const Icon(Icons.upload_file),
                            label: const Text('匯出設定檔 (JSON)',
                                style: TextStyle(fontSize: 16)),
                            style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16)),
                            onPressed: () => _export(context, ref),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.download),
                            label: const Text('匯入設定檔 (JSON)',
                                style: TextStyle(fontSize: 16)),
                            style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16)),
                            onPressed: () => _import(context, ref),
                          ),
                          const SizedBox(height: 32),
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text(
                            '匯入資料庫 (SQLite)',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '完整搬移整個資料庫（含分類、商品、選項群組及對應設定）。\n'
                            '⚠️ 匯入前會自動備份，但匯入後本機資料將被覆蓋，請謹慎操作。',
                            style:
                                TextStyle(fontSize: 13, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.storage),
                            label: const Text('匯入資料庫 (SQLite)',
                                style: TextStyle(fontSize: 16)),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              foregroundColor: Colors.orange,
                              side:
                                  const BorderSide(color: Colors.orange),
                            ),
                            onPressed: () => _importSqlite(context, ref),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final path =
          await ref.read(backofficeRepositoryProvider).exportConfig();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已匯出至：$path')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('匯出失敗：$e')),
        );
      }
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    try {
      final jsonStr =
          await ref.read(backofficeRepositoryProvider).pickImportFile();
      if (jsonStr == null) return;
      await ref.read(backofficeRepositoryProvider).importConfig(jsonStr);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('匯入成功')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('匯入失敗：$e')),
        );
      }
    }
  }

  Future<void> _importSqlite(BuildContext context, WidgetRef ref) async {
    // Confirmation dialog before overwriting local data.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確認匯入資料庫'),
        content: const Text(
          '匯入 SQLite 資料庫將覆蓋本機所有資料（商品、分類、選項群組等）。\n\n'
          '系統會在覆蓋前自動備份目前的資料庫，但匯入後需重啟 App 才會生效。\n\n'
          '確定要繼續嗎？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('確定匯入'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      final backupPath =
          await ref.read(backofficeRepositoryProvider).importSqliteDatabase();
      if (backupPath == null) return; // user cancelled the picker
      if (context.mounted) {
        final msg = backupPath.isNotEmpty
            ? '匯入完成，請重啟 App\n（備份：$backupPath）'
            : '匯入完成，請重啟 App';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('匯入失敗：$e')),
        );
      }
    }
  }
}
