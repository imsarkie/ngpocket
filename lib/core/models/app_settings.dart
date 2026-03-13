import 'package:flutter/material.dart';

enum ReaderFontFamily { sourceSerif, dmSans, playfair }

enum ReaderTextAlignment { left, justified }

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.readerFontScale,
    required this.readerFontFamily,
    required this.readerTextAlignment,
    required this.parserEndpoint,
  });

  final ThemeMode themeMode;
  final double readerFontScale;
  final ReaderFontFamily readerFontFamily;
  final ReaderTextAlignment readerTextAlignment;
  final String parserEndpoint;

  bool get isDarkMode => themeMode == ThemeMode.dark;

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? readerFontScale,
    ReaderFontFamily? readerFontFamily,
    ReaderTextAlignment? readerTextAlignment,
    String? parserEndpoint,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      readerFontScale: readerFontScale ?? this.readerFontScale,
      readerFontFamily: readerFontFamily ?? this.readerFontFamily,
      readerTextAlignment: readerTextAlignment ?? this.readerTextAlignment,
      parserEndpoint: parserEndpoint ?? this.parserEndpoint,
    );
  }

  static const defaults = AppSettings(
    themeMode: ThemeMode.system,
    readerFontScale: 1,
    readerFontFamily: ReaderFontFamily.sourceSerif,
    readerTextAlignment: ReaderTextAlignment.left,
    parserEndpoint: '',
  );
}
