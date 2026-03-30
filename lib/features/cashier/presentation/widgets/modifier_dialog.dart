import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/db/models.dart';

/// An AlertDialog that lets the cashier make required single-choice selections
/// for each modifier group attached to a product.
///
/// Returns the JSON snapshot string on confirm, or null if dismissed.
Future<String?> showModifierDialog(
  BuildContext context,
  String productName,
  List<ModifierGroupWithOptions> groups,
) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ModifierDialog(
      productName: productName,
      groups: groups,
    ),
  );
}

class _ModifierDialog extends StatefulWidget {
  const _ModifierDialog({
    required this.productName,
    required this.groups,
  });

  final String productName;
  final List<ModifierGroupWithOptions> groups;

  @override
  State<_ModifierDialog> createState() => _ModifierDialogState();
}

class _ModifierDialogState extends State<_ModifierDialog> {
  /// Maps groupId → selected option (or null if nothing chosen yet)
  late final Map<int, ModifierOption?> _selections;

  @override
  void initState() {
    super.initState();
    _selections = {for (final g in widget.groups) g.group.id: null};
  }

  bool get _allSelected =>
      _selections.values.every((v) => v != null);

  String _buildSnapshot() {
    final groupList = widget.groups.map((g) {
      final option = _selections[g.group.id]!;
      return {
        'groupId': g.group.id,
        'groupName': g.group.name,
        'optionId': option.id,
        'optionName': option.name,
        'priceDelta': option.priceDelta,
      };
    }).toList();
    return jsonEncode({'groups': groupList});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.productName),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widget.groups.map((g) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    g.group.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ...g.options.map((opt) => RadioListTile<ModifierOption>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(opt.name),
                      value: opt,
                      groupValue: _selections[g.group.id],
                      onChanged: (v) =>
                          setState(() => _selections[g.group.id] = v),
                    )),
                const Divider(),
              ],
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _allSelected
              ? () => Navigator.pop(context, _buildSnapshot())
              : null,
          child: const Text('確認'),
        ),
      ],
    );
  }
}
