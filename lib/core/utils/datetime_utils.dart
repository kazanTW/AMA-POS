import 'package:intl/intl.dart';

final _dateFmt = DateFormat('yyyy-MM-dd');
final _timeFmt = DateFormat('HH:mm');
final _dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');

String formatDate(DateTime dt) => _dateFmt.format(dt);
String formatTime(DateTime dt) => _timeFmt.format(dt);
String formatDateTime(DateTime dt) => _dateTimeFmt.format(dt);

String generateOrderNo(String terminalCode, int sequence) {
  return '${terminalCode.toUpperCase()}-${sequence.toString().padLeft(4, '0')}';
}
