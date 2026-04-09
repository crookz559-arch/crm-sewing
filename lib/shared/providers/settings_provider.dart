import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';

// Theme mode
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final box = Hive.box(AppConstants.hiveBoxSettings);
    final saved = box.get(AppConstants.keyThemeMode, defaultValue: 'system') as String;
    switch (saved) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void setTheme(ThemeMode mode) {
    final box = Hive.box(AppConstants.hiveBoxSettings);
    String value;
    switch (mode) {
      case ThemeMode.light:
        value = 'light';
        break;
      case ThemeMode.dark:
        value = 'dark';
        break;
      default:
        value = 'system';
    }
    box.put(AppConstants.keyThemeMode, value);
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

// Locale
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final box = Hive.box(AppConstants.hiveBoxSettings);
    final saved = box.get(AppConstants.keyLanguage, defaultValue: 'ru') as String;
    return Locale(saved);
  }

  void setLocale(String languageCode) {
    final box = Hive.box(AppConstants.hiveBoxSettings);
    box.put(AppConstants.keyLanguage, languageCode);
    state = Locale(languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);
