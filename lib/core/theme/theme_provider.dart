import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

const String _kThemePresetKey = 'user_theme_preset_id';
const String _kThemeModeKey = 'user_theme_mode_id';

/// State representing user theme preferences
class ThemeState {
  final AppColorPreset preset;
  final ThemeMode mode;

  const ThemeState({
    required this.preset,
    required this.mode,
  });

  ThemeData get lightTheme => AppTheme.buildLightTheme(preset);
  ThemeData get darkTheme => AppTheme.buildDarkTheme(preset);

  ThemeState copyWith({
    AppColorPreset? preset,
    ThemeMode? mode,
  }) {
    return ThemeState(
      preset: preset ?? this.preset,
      mode: mode ?? this.mode,
    );
  }
}

class ThemeNotifier extends Notifier<ThemeState> {
  @override
  ThemeState build() {
    _loadFromPreferences();
    return const ThemeState(
      preset: AppColorPreset.classicIndigo,
      mode: ThemeMode.dark,
    );
  }

  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final presetId = prefs.getString(_kThemePresetKey);
      final modeName = prefs.getString(_kThemeModeKey);

      final loadedPreset = AppColorPreset.fromId(presetId);
      ThemeMode loadedMode = ThemeMode.dark;
      if (modeName == 'light') {
        loadedMode = ThemeMode.light;
      } else if (modeName == 'system') {
        loadedMode = ThemeMode.system;
      }

      state = ThemeState(
        preset: loadedPreset,
        mode: loadedMode,
      );
    } catch (e) {
      debugPrint('Error loading theme preferences: $e');
    }
  }

  Future<void> setPreset(AppColorPreset preset) async {
    state = state.copyWith(preset: preset);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemePresetKey, preset.id);
    } catch (e) {
      debugPrint('Error saving theme preset: $e');
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = mode == ThemeMode.light
          ? 'light'
          : (mode == ThemeMode.system ? 'system' : 'dark');
      await prefs.setString(_kThemeModeKey, modeStr);
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);
