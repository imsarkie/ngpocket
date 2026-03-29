import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader/core/models/app_settings.dart';
import 'package:reader/core/services/background_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kSettingsThemeModeKey = 'settings_theme_mode';

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

class AppSettingsController extends Notifier<AppSettings> {
  bool _isHydrating = false;

  @override
  AppSettings build() {
    _hydrateSettings();
    return AppSettings.defaults;
  }

  Future<void> _hydrateSettings() async {
    if (_isHydrating) {
      return;
    }

    _isHydrating = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsEnabled =
          prefs.getBool(kSettingsMorningSyncNotificationsEnabledKey) ??
          AppSettings.defaults.morningSyncNotificationsEnabled;
      final reminders = _sanitizeRemindersPerDay(
        prefs.getInt(kSettingsUnreadNotificationThresholdKey),
      );
      final themeModeIndex = prefs.getInt(kSettingsThemeModeKey);
      final themeMode = themeModeIndex != null
          ? ThemeMode.values[themeModeIndex.clamp(
              0,
              ThemeMode.values.length - 1,
            )]
          : AppSettings.defaults.themeMode;

      state = state.copyWith(
        morningSyncNotificationsEnabled: notificationsEnabled,
        libraryRemindersPerDay: reminders,
        themeMode: themeMode,
      );

      if (notificationsEnabled) {
        await BackgroundSyncService.updateLibraryReminderTask(
          _calculateInterval(reminders),
        );
      }

      final applied = await BackgroundSyncService.setMorningSyncEnabled(
        notificationsEnabled,
        requestPermissionWhenEnabling: false,
      );

      if (notificationsEnabled && !applied) {
        state = state.copyWith(morningSyncNotificationsEnabled: false);
      }
    } catch (_) {
      // Keep settings resilient if local preference I/O fails.
    } finally {
      _isHydrating = false;
    }
  }

  Future<void> ensureHydrated() => _hydrateSettings();

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kSettingsThemeModeKey, mode.index);
    } catch (_) {
      // Ignore write failures; in-memory state is already updated.
    }
  }

  Future<void> setDarkMode(bool isDark) =>
      setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);

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

  Future<bool> setMorningSyncNotificationsEnabled(bool enabled) async {
    state = state.copyWith(morningSyncNotificationsEnabled: enabled);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kSettingsMorningSyncNotificationsEnabledKey, enabled);
    } catch (_) {
      // Ignore local write failures and keep in-memory state updated.
    }

    final applied = await BackgroundSyncService.setMorningSyncEnabled(
      enabled,
      requestPermissionWhenEnabling: enabled,
    );

    if (applied && enabled) {
      await BackgroundSyncService.updateLibraryReminderTask(
        _calculateInterval(state.libraryRemindersPerDay),
      );
    } else {
      await BackgroundSyncService.updateLibraryReminderTask(null);
    }

    if (enabled && !applied) {
      state = state.copyWith(morningSyncNotificationsEnabled: false);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(kSettingsMorningSyncNotificationsEnabledKey, false);
      } catch (_) {
        // Ignore local write failures and keep in-memory state updated.
      }
    }

    return applied;
  }

  Future<void> setLibraryRemindersPerDay(
    int count, {
    bool persist = true,
  }) async {
    final sanitized = _sanitizeRemindersPerDay(count);
    state = state.copyWith(libraryRemindersPerDay: sanitized);

    if (persist) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(kSettingsUnreadNotificationThresholdKey, sanitized);
      } catch (_) {
        // Ignore local write failures and keep in-memory state updated.
      }
    }

    if (state.morningSyncNotificationsEnabled) {
      await BackgroundSyncService.updateLibraryReminderTask(
        _calculateInterval(sanitized),
      );
    }
  }

  int _sanitizeRemindersPerDay(int? count) {
    final source = count ?? AppSettings.defaults.libraryRemindersPerDay;
    return source.clamp(1, 10);
  }

  Duration _calculateInterval(int timesPerDay) {
    // Determine the space in minutes between each notification
    // e.g. 10 times a day = 144 minutes between drops.
    final minutes = (24 * 60) ~/ timesPerDay;
    return Duration(minutes: minutes);
  }
}
