import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';

class AuthStore {
  AuthStore(this._prefs);

  static const _sessionKey = 'auth_session';
  static const _themeModeKey = 'theme_mode';
  static const _localeKey = 'locale';
  final SharedPreferences _prefs;

  static Future<AuthStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AuthStore(prefs);
  }

  AuthSession? loadSession() {
    final raw = _prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return null;
    return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSession(AuthSession session) async {
    await _prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    await _prefs.remove(_sessionKey);
  }

  ThemeMode loadThemeMode() {
    final raw = _prefs.getString(_themeModeKey);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.dark,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'dark',
    };
    await _prefs.setString(_themeModeKey, value);
  }

  Locale? loadLocale() {
    final raw = _prefs.getString(_localeKey);
    return switch (raw) {
      'zh' => const Locale('zh'),
      'en' => const Locale('en'),
      _ => null,
    };
  }

  Future<void> saveLocale(Locale? locale) async {
    final languageCode = locale?.languageCode;
    if (languageCode == null || languageCode.isEmpty) {
      await _prefs.remove(_localeKey);
      return;
    }
    await _prefs.setString(_localeKey, languageCode);
  }
}
