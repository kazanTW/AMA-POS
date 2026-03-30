import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/db/app_database.dart';
import 'core/db/sqflite_init.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize sqflite FFI on desktop platforms (Linux/Windows/macOS).
  initSqfliteForDesktop();
  final db = AppDatabase.instance;
  await db.seedDataIfEmpty();
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const AmaApp(),
    ),
  );
}
