import 'package:intl/intl.dart';

final _nf = NumberFormat('#,##0', 'zh_TW');

String formatMoney(int amount) => 'NT\$ ${_nf.format(amount)}';

int parseMoneyInput(String input) {
  final cleaned = input.replaceAll(RegExp(r'[^\d]'), '');
  return int.tryParse(cleaned) ?? 0;
}
