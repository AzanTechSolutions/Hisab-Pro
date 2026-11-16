import 'package:flutter/material.dart';

class AppSettingsState {
  const AppSettingsState({
    this.currencyCode = 'PKR',
    this.currencySymbol = 'Rs.',
    this.locale = const Locale('en'),
    this.themeMode = ThemeMode.system,
    this.isBiometricEnabled = false,
    this.autoLockMinutes = 5,
  });

  final String currencyCode;
  final String currencySymbol;
  final Locale locale;
  final ThemeMode themeMode;
  final bool isBiometricEnabled;
  final int autoLockMinutes;

  bool get isUrdu => locale.languageCode == 'ur';

  AppSettingsState copyWith({
    String? currencyCode,
    String? currencySymbol,
    Locale? locale,
    ThemeMode? themeMode,
    bool? isBiometricEnabled,
    int? autoLockMinutes,
  }) {
    return AppSettingsState(
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
    );
  }
}

