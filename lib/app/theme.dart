import 'package:flutter/material.dart';

final appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1565C0),
    brightness: Brightness.light,
  ),
  cardTheme: const CardTheme(
    elevation: 2,
    margin: EdgeInsets.all(4),
  ),
  appBarTheme: const AppBarTheme(
    centerTitle: false,
  ),
);
