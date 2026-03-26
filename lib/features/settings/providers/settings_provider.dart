import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ngpocket/core/models/app_settings.dart';
import 'package:ngpocket/core/services/background_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      final unreadThreshold = _sanitizeThreshold(
        prefs.getInt(kSettingsUnreadNotificationThresholdKey),
      );

      state = state.copyWith(
        morningSyncNotificationsEnabled: notificationsEnabled,
        unreadNotificationThreshold: unreadThreshold,
      );

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

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: ThemeMode.light);
  }

  void setDarkMode(bool isDark) {
    state = state.copyWith(themeMode: ThemeMode.light);
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

  Future<void> setUnreadNotificationThreshold(
    int threshold, {
    bool persist = true,
    bool showTestNotification = false,
  }) async {
    final sanitized = _sanitizeThreshold(threshold);
    state = state.copyWith(unreadNotificationThreshold: sanitized);

    if (persist) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(kSettingsUnreadNotificationThresholdKey, sanitized);
      } catch (_) {
        // Ignore local write failures and keep in-memory state updated.
      }
    }

    if (showTestNotification) {
      await BackgroundSyncService.showTestUnreadNotification(
        threshold: sanitized,
      );
    }
  }

  int _sanitizeThreshold(int? threshold) {
    final source =
        threshold ?? AppSettings.defaults.unreadNotificationThreshold;
    return source.clamp(
      kMinUnreadNotificationThreshold,
      kMaxUnreadNotificationThreshold,
    );
  }
}
