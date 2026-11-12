import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class AppTheme {
  static const Color navy = Color(0xFF0F172A);
  static const Color emerald = Color(0xFF10B981);
  static const Color slate = Color(0xFFE2E8F0);
  static const Color paper = Color(0xFFF8FAFC);
  static const Color ink = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: emerald,
        brightness: Brightness.light,
        primary: emerald,
        secondary: navy,
      ),
      scaffoldBackgroundColor: paper,
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: paper,
      ),
      textTheme: Typography.material2021().black.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
    );

    return base.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF020817),
      colorScheme: ColorScheme.fromSeed(
        seedColor: emerald,
        brightness: Brightness.dark,
        primary: emerald,
        secondary: navy,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
