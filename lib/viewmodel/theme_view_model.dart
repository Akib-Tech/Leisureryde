// lib/core/viewmodels/theme_viewmodel.dart
import 'package:flutter/material.dart';
import 'package:leisureryde/app/service_locator.dart';

import '../services/local_storage_service.dart';

class ThemeViewModel extends ChangeNotifier {
  static const String _themeModeKey = 'themeMode';
  final LocalStorageService _localStorageService = locator<LocalStorageService>();

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  // Initialize the theme from saved preferences
  Future<void> init() async {
    final prefs = _localStorageService.getPreferences(); // We'll add this to the service
    final themeString = prefs.getString(_themeModeKey) ?? 'dark';

    if (themeString == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themeString == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    final prefs = _localStorageService.getPreferences();

    String themeString = 'system';
    if (mode == ThemeMode.light) themeString = 'light';
    if (mode == ThemeMode.dark) themeString = 'dark';

    await prefs.setString(_themeModeKey, themeString);
    notifyListeners();
  }
}