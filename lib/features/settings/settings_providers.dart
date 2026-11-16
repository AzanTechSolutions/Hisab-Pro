import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab_pro/features/settings/data/settings_repository.dart';
import 'package:hisab_pro/features/settings/domain/app_settings_state.dart';
import 'package:hisab_pro/features/user_profiles/profile_providers.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return SettingsRepository(databaseService: dbService);
});

class SettingsNotifier extends StateNotifier<AppSettingsState> {
  SettingsNotifier(this._repository, this._userId) : super(const AppSettingsState()) {
    _loadSettings();
  }

  final SettingsRepository _repository;
  final String? _userId;

  Future<void> _loadSettings() async {
    if (_userId == null) return;
    try {
      final settings = await _repository.getAllSettings(userId: _userId);

      ThemeMode theme = ThemeMode.system;
      if (settings['theme_mode'] == 'light') theme = ThemeMode.light;
      if (settings['theme_mode'] == 'dark') theme = ThemeMode.dark;

      final langCode = settings['language_code'] ?? 'en';
      final currencyCode = settings['currency_code'] ?? 'PKR';
      final currencySymbol = settings['currency_symbol'] ?? 'Rs.';
      final isBio = settings['biometric_enabled'] == 'true';
      final autoLock = int.tryParse(settings['auto_lock_minutes'] ?? '5') ?? 5;

      state = AppSettingsState(
        currencyCode: currencyCode,
        currencySymbol: currencySymbol,
        locale: Locale(langCode),
        themeMode: theme,
        isBiometricEnabled: isBio,
        autoLockMinutes: autoLock,
      );
    } catch (_) {}
  }

  Future<void> setCurrency(String code, String symbol) async {
    state = state.copyWith(currencyCode: code, currencySymbol: symbol);
    if (_userId != null) {
      await _repository.saveSetting(userId: _userId, key: 'currency_code', value: code);
      await _repository.saveSetting(userId: _userId, key: 'currency_symbol', value: symbol);
    }
  }

  Future<void> setLanguage(String languageCode) async {
    state = state.copyWith(locale: Locale(languageCode));
    if (_userId != null) {
      await _repository.saveSetting(userId: _userId, key: 'language_code', value: languageCode);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    if (_userId != null) {
      final modeStr = mode == ThemeMode.light ? 'light' : (mode == ThemeMode.dark ? 'dark' : 'system');
      await _repository.saveSetting(userId: _userId, key: 'theme_mode', value: modeStr);
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    state = state.copyWith(isBiometricEnabled: enabled);
    if (_userId != null) {
      await _repository.saveSetting(userId: _userId, key: 'biometric_enabled', value: enabled ? 'true' : 'false');
    }
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    state = state.copyWith(autoLockMinutes: minutes);
    if (_userId != null) {
      await _repository.saveSetting(userId: _userId, key: 'auto_lock_minutes', value: minutes.toString());
    }
  }
}

final settingsNotifierProvider = StateNotifierProvider<SettingsNotifier, AppSettingsState>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  final activeProfile = ref.watch(activeProfileProvider);
  return SettingsNotifier(repo, activeProfile?.id);
});

