import 'package:flutter/material.dart';

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.readerFontScale,
    required this.parserEndpoint,
  });

  final ThemeMode themeMode;
  final double readerFontScale;
  final String parserEndpoint;

  bool get isDarkMode => themeMode == ThemeMode.dark;

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? readerFontScale,
    String? parserEndpoint,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      readerFontScale: readerFontScale ?? this.readerFontScale,
      parserEndpoint: parserEndpoint ?? this.parserEndpoint,
    );
  }

  static const defaults = AppSettings(
    themeMode: ThemeMode.system,
    readerFontScale: 1,
    parserEndpoint: '',
  );
}
