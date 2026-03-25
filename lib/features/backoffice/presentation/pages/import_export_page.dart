import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backoffice_repository.dart';

class ImportExportPage extends ConsumerWidget {
  const ImportExportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('匯入/匯出設定')),
      body: Center(
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
                      padding:
                          const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () => _export(context, ref),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('匯入設定檔 (JSON)',
                      style: TextStyle(fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () => _import(context, ref),
                ),
              ],
            ),
          ),
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
}
