import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a UUID v4 string. Available for use by features that require
/// client-generated IDs (e.g., sync, offline-first conflict resolution).
String generateId() => _uuid.v4();
