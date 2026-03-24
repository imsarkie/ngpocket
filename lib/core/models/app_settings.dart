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
    required this.morningSyncNotificationsEnabled,
    required this.unreadNotificationThreshold,
  });

  final ThemeMode themeMode;
  final double readerFontScale;
  final ReaderFontFamily readerFontFamily;
  final ReaderTextAlignment readerTextAlignment;
  final String parserEndpoint;
  final bool morningSyncNotificationsEnabled;
  final int unreadNotificationThreshold;

  bool get isDarkMode => themeMode == ThemeMode.dark;

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? readerFontScale,
    ReaderFontFamily? readerFontFamily,
    ReaderTextAlignment? readerTextAlignment,
    String? parserEndpoint,
    bool? morningSyncNotificationsEnabled,
    int? unreadNotificationThreshold,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      readerFontScale: readerFontScale ?? this.readerFontScale,
      readerFontFamily: readerFontFamily ?? this.readerFontFamily,
      readerTextAlignment: readerTextAlignment ?? this.readerTextAlignment,
      parserEndpoint: parserEndpoint ?? this.parserEndpoint,
      morningSyncNotificationsEnabled:
          morningSyncNotificationsEnabled ??
          this.morningSyncNotificationsEnabled,
      unreadNotificationThreshold:
          unreadNotificationThreshold ?? this.unreadNotificationThreshold,
    );
  }

  static const defaults = AppSettings(
    themeMode: ThemeMode.light,
    readerFontScale: 1,
    readerFontFamily: ReaderFontFamily.sourceSerif,
    readerTextAlignment: ReaderTextAlignment.left,
    parserEndpoint: '',
    morningSyncNotificationsEnabled: true,
    unreadNotificationThreshold: 5,
  );
}
