import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ngpocket/core/models/app_settings.dart';

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

class AppSettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => AppSettings.defaults;

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  void setDarkMode(bool isDark) {
    state = state.copyWith(
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
    );
  }

  void setReaderFontScale(double scale) {
    state = state.copyWith(readerFontScale: scale.clamp(0.85, 1.5));
  }

  void setReaderFontFamily(ReaderFontFamily fontFamily) {
    state = state.copyWith(readerFontFamily: fontFamily);
  }

  void setReaderTextAlignment(ReaderTextAlignment alignment) {
    state = state.copyWith(readerTextAlignment: alignment);
  }

  void setParserEndpoint(String endpoint) {
    state = state.copyWith(parserEndpoint: endpoint.trim());
  }
}
