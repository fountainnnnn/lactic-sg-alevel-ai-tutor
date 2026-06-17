import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/chat_service.dart';
import '../data/memory_store.dart';

/// Overridden in main() once async init is done.
final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError());
final memoryStoreProvider = Provider<MemoryStore>((_) => throw UnimplementedError());

final chatServiceProvider = Provider<ChatService>((_) => ChatService());

/// Stable per-install id (for anonymous rate limiting on the backend).
final deviceIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(prefsProvider);
  var id = prefs.getString('device_id');
  if (id == null) {
    final r = Random();
    id = 'd_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
        '${List.generate(8, (_) => r.nextInt(36).toRadixString(36)).join()}';
    prefs.setString('device_id', id);
  }
  return id;
});

final onboardingDoneProvider = StateProvider<bool>((ref) {
  return ref.watch(prefsProvider).getBool('onboarding_done') ?? false;
});

class Settings {
  final ThemeMode themeMode;
  final String answerStyle; // 'coach' | 'direct'
  const Settings({this.themeMode = ThemeMode.system, this.answerStyle = 'direct'});

  Settings copyWith({ThemeMode? themeMode, String? answerStyle}) => Settings(
        themeMode: themeMode ?? this.themeMode,
        answerStyle: answerStyle ?? this.answerStyle,
      );
}

class SettingsNotifier extends StateNotifier<Settings> {
  final SharedPreferences _prefs;
  SettingsNotifier(this._prefs)
      : super(Settings(
          themeMode: _modeFrom(_prefs.getString('theme_mode')),
          answerStyle: _prefs.getString('answer_style') ?? 'direct',
        ));

  static ThemeMode _modeFrom(String? s) => switch (s) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light, // default to light when unset
      };

  void setThemeMode(ThemeMode m) {
    state = state.copyWith(themeMode: m);
    _prefs.setString('theme_mode', m.name);
  }

  void setAnswerStyle(String s) {
    state = state.copyWith(answerStyle: s);
    _prefs.setString('answer_style', s);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, Settings>((ref) {
  return SettingsNotifier(ref.watch(prefsProvider));
});
