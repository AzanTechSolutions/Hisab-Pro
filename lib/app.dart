import 'package:flutter/material.dart';
import 'package:hisab_pro/core/router/app_router.dart';
import 'package:hisab_pro/core/theme/app_theme.dart';

class HisabProApp extends StatelessWidget {
  const HisabProApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.router;

    return MaterialApp.router(
      title: 'Hisab Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
