import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String generateId() => _uuid.v4();
