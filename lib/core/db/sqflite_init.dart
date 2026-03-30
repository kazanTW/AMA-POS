import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Initializes the sqflite FFI database factory for desktop platforms
/// (Linux, Windows, macOS). Must be called before any [openDatabase] call.
/// On Android/iOS this is a no-op; the default sqflite factory is used.
void initSqfliteForDesktop() {
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
