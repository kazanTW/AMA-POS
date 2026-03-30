import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backoffice_repository.dart';

class MerchantSettingsPage extends ConsumerStatefulWidget {
  const MerchantSettingsPage({super.key});

  @override
  ConsumerState<MerchantSettingsPage> createState() =>
      _MerchantSettingsPageState();
}

class _MerchantSettingsPageState extends ConsumerState<MerchantSettingsPage> {
  final _tableCountController = TextEditingController();
  final _terminalCodeController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _terminalCodeError;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadConfig);
  }

  Future<void> _loadConfig() async {
    final config =
        await ref.read(backofficeRepositoryProvider).getMerchantConfig();
    if (mounted) {
      setState(() {
        _tableCountController.text = config.tableCount.toString();
        _terminalCodeController.text = config.terminalCode;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tableCountController.dispose();
    _terminalCodeController.dispose();
    super.dispose();
  }

  String? _validateTerminalCode(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '不可為空';
    if (trimmed.length > 4) return '最多 4 個字元';
    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(trimmed)) return '僅允許英文字母與數字';
    return null;
  }

  Future<void> _save() async {
    final terminalCode = _terminalCodeController.text.trim().toUpperCase();
    final terminalCodeErr = _validateTerminalCode(terminalCode);
    setState(() => _terminalCodeError = terminalCodeErr);
    if (terminalCodeErr != null) return;

    final count = int.tryParse(_tableCountController.text.trim()) ?? 0;
    setState(() => _saving = true);
    try {
      await ref.read(backofficeRepositoryProvider).setTableCount(count);
      await ref
          .read(backofficeRepositoryProvider)
          .setTerminalCode(terminalCode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已儲存')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('商家設定')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '機台代碼',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _terminalCodeController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9]')),
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: InputDecoration(
                        labelText: '機台代碼',
                        hintText: 'A1',
                        border: const OutlineInputBorder(),
                        helperText: '1–4 碼英數，存為大寫',
                        errorText: _terminalCodeError,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '桌號設定',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _tableCountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: '桌數',
                        hintText: '0',
                        border: OutlineInputBorder(),
                        helperText: '設為 0 表示不開放內用桌號',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('儲存'),
                  ),
                ],
              ),
            ),
    );
  }
}
