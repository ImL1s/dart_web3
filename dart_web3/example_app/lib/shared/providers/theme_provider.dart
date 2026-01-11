import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_provider.g.dart';

@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    // Load initial state
    _loadState();
    return ThemeMode.system;
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_key);
    if (savedMode != null) {
      state = ThemeMode.values.firstWhere(
        (e) => e.toString() == savedMode,
        orElse: () => ThemeMode.system,
      );
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.toString());
  }
  
  bool get isDarkMode {
    if (state == ThemeMode.system) {
       // We can't know context here easily without BuildContext, 
       // but typically this getter is used for toggles.
       // For proper system check, use MediaQuery in UI.
       return false; 
    }
    return state == ThemeMode.dark;
  }
}
