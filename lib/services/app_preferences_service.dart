import 'package:flutter/material.dart';

class AppPreferencesService {
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);
  static final ValueNotifier<Locale> locale =
      ValueNotifier<Locale>(const Locale('en'));

  static String normalizeLanguageCode(Object? value) {
    return value?.toString().trim().toLowerCase() == 'hi' ? 'hi' : 'en';
  }

  static void syncPreferencesFromData(Map<String, dynamic>? data) {
    final settings = Map<String, dynamic>.from(data?['settings'] ?? {});
    final languageCode = normalizeLanguageCode(settings['languageCode']);
    if (locale.value.languageCode != languageCode) {
      locale.value = Locale(languageCode);
    }
    if (themeMode.value != ThemeMode.light) {
      themeMode.value = ThemeMode.light;
    }
  }

  static void setLanguageCode(String languageCode) {
    final normalized = normalizeLanguageCode(languageCode);
    if (locale.value.languageCode != normalized) {
      locale.value = Locale(normalized);
    }
  }
}
