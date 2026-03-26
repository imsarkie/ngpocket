import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ngpocket/core/database/app_database.dart';
import 'package:ngpocket/features/reader/presentation/reader_screen.dart';
import 'package:ngpocket/core/services/rss_service.dart';
import 'package:ngpocket/core/utils/reading_time.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const String kMorningRssSyncTask = 'morning-rss-sync-task';
const String _kMorningRssSyncUniqueName = 'morning-rss-sync-unique';
const String kSettingsMorningSyncNotificationsEnabledKey =
    'settings.morning_sync_notifications_enabled';
const String kSettingsUnreadNotificationThresholdKey =
    'settings.unread_notification_threshold';
const int kMinUnreadNotificationThreshold = 3;
const int kMaxUnreadNotificationThreshold = 10;
const int kDefaultUnreadNotificationThreshold = 5;

const String _kReadActionId = 'open_reader_action';
const int _kSyncNotificationId = 1001;

const AndroidNotificationChannel _syncChannel = AndroidNotificationChannel(
  'rss_sync_channel_v2',
  'RSS Sync',
  description: 'Notifications after automatic RSS synchronization.',
  importance: Importance.high,
);

@pragma('vm:entry-point')
void backgroundSyncCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != kMorningRssSyncTask) {
      return true;
    }

    WidgetsFlutterBinding.ensureInitialized();

    final notifications = FlutterLocalNotificationsPlugin();
    await _initializeNotifications(notifications, requestPermission: false);

    final db = AppDatabase();
    try {
      final feeds = await db.select(db.feeds).get();
      if (feeds.isEmpty) {
        return true;
      }

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 12),
          sendTimeout: const Duration(seconds: 12),
          headers: const {'Accept': 'application/json, text/plain, */*'},
        ),
      );
      final rssService = RssService(dio);

      var updatedFeedCount = 0;

      for (final feed in feeds) {
        try {
          final previews = await rssService.fetchArticles(
            sourceName: feed.name,
            feedUrl: feed.rssUrl,
          );

          for (final preview in previews) {
            await db.upsertFeedPreview(
              title: preview.title,
              url: preview.url,
              source: preview.source,
              description: preview.description,
              image: preview.image,
              publishedAt: preview.publishedAt,
              readingTime: estimateReadingTimeFromText(preview.description),
            );
          }

          await db.updateFeedTimestamp(feed.id);
          updatedFeedCount++;
        } catch (_) {
          // Continue syncing other feeds even when one fails.
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final notificationsEnabled =
          prefs.getBool(kSettingsMorningSyncNotificationsEnabledKey) ?? false;
      final threshold = _sanitizeThreshold(
        prefs.getInt(kSettingsUnreadNotificationThresholdKey),
      );

      if (notificationsEnabled) {
        final unreadSavedCount = await db.countUnreadSavedArticles();
        if (unreadSavedCount >= threshold) {
          final sampleArticle = await db.findLatestUnreadSavedArticle();
          if (sampleArticle != null) {
            await _showUnreadLibraryNotification(
              notifications: notifications,
              article: sampleArticle,
              unreadSavedCount: unreadSavedCount,
              threshold: threshold,
              updatedFeedCount: updatedFeedCount,
              isTest: false,
            );
          }
        }
      }

      return true;
    } finally {
      await db.close();
    }
  });
}

class BackgroundSyncService {
  const BackgroundSyncService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static bool _initialized = false;
  static bool _notificationsInitialized = false;

  static int? _lastOpenedArticleId;
  static DateTime? _lastOpenAt;

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await Workmanager().initialize(backgroundSyncCallbackDispatcher);
    _initialized = true;
  }

  static Future<void> initializeNotificationHandling() async {
    final notifications = FlutterLocalNotificationsPlugin();
    await _initializeNotifications(
      notifications,
      requestPermission: false,
      registerResponseHandlers: true,
    );

    if (_notificationsInitialized) {
      return;
    }
    _notificationsInitialized = true;

    final launchDetails = await notifications.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      unawaited(_openReaderFromPayload(launchPayload));
    }
  }

  static Future<bool> setMorningSyncEnabled(
    bool enabled, {
    required bool requestPermissionWhenEnabling,
  }) async {
    await initialize();

    final notifications = FlutterLocalNotificationsPlugin();
    await _initializeNotifications(
      notifications,
      requestPermission: enabled && requestPermissionWhenEnabling,
      registerResponseHandlers: true,
    );

    if (!enabled) {
      await Workmanager().cancelByUniqueName(_kMorningRssSyncUniqueName);
      return false;
    }

    final notificationsAllowed = await _areNotificationsAllowed(notifications);
    if (!notificationsAllowed) {
      await Workmanager().cancelByUniqueName(_kMorningRssSyncUniqueName);
      return false;
    }

    await Workmanager().registerPeriodicTask(
      _kMorningRssSyncUniqueName,
      kMorningRssSyncTask,
      frequency: const Duration(hours: 24),
      initialDelay: _initialDelayUntilMorning(),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 15),
    );

    return true;
  }

  static Future<void> showTestUnreadNotification({
    required int threshold,
  }) async {
    final notifications = FlutterLocalNotificationsPlugin();
    await _initializeNotifications(
      notifications,
      requestPermission: true,
      registerResponseHandlers: true,
    );

    final notificationsAllowed = await _areNotificationsAllowed(notifications);
    if (!notificationsAllowed) {
      return;
    }

    final db = AppDatabase();
    try {
      final unreadSavedCount = await db.countUnreadSavedArticles();
      final sampleArticle =
          await db.findLatestUnreadSavedArticle() ??
          await db.findLatestSavedArticle();

      if (sampleArticle == null) {
        await notifications.show(
          _kSyncNotificationId,
          'Test: Library notification',
          'No saved articles yet. Save an article to preview this alert.',
          NotificationDetails(
            android: AndroidNotificationDetails(
              _syncChannel.id,
              _syncChannel.name,
              channelDescription: _syncChannel.description,
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
          ),
        );
        return;
      }

      await _showUnreadLibraryNotification(
        notifications: notifications,
        article: sampleArticle,
        unreadSavedCount: unreadSavedCount,
        threshold: _sanitizeThreshold(threshold),
        updatedFeedCount: 0,
        isTest: true,
      );
    } finally {
      await db.close();
    }
  }

  static void handleNotificationResponse(NotificationResponse response) {
    unawaited(_openReaderFromPayload(response.payload));
  }

  static Future<void> _openReaderFromPayload(String? payload) async {
    final articleId = _parseArticleIdFromPayload(payload);
    if (articleId == null) {
      return;
    }

    final now = DateTime.now();
    if (_lastOpenedArticleId == articleId &&
        _lastOpenAt != null &&
        now.difference(_lastOpenAt!) < const Duration(seconds: 2)) {
      return;
    }

    final db = AppDatabase();
    try {
      final article = await db.findArticleById(articleId);
      if (article == null) {
        return;
      }

      for (var attempt = 0; attempt < 10; attempt++) {
        final nav = navigatorKey.currentState;
        if (nav != null) {
          _lastOpenedArticleId = articleId;
          _lastOpenAt = now;
          nav.push(
            MaterialPageRoute(builder: (_) => ReaderScreen(article: article)),
          );
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 180));
      }
    } finally {
      await db.close();
    }
  }

  static Duration _initialDelayUntilMorning() {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, 7);

    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }

    return target.difference(now);
  }
}

Future<bool> _areNotificationsAllowed(
  FlutterLocalNotificationsPlugin notifications,
) async {
  final androidPlugin = notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  final enabled = await androidPlugin?.areNotificationsEnabled();
  return enabled ?? true;
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  BackgroundSyncService.handleNotificationResponse(response);
}

Future<void> _showUnreadLibraryNotification({
  required FlutterLocalNotificationsPlugin notifications,
  required Article article,
  required int unreadSavedCount,
  required int threshold,
  required int updatedFeedCount,
  required bool isTest,
}) async {
  final payload = jsonEncode({'articleId': article.id});
  final feedSuffix = updatedFeedCount == 1 ? '' : 's';
  final syncLabel = updatedFeedCount > 0
      ? 'Sync updated $updatedFeedCount feed$feedSuffix. '
      : 'Sync completed. ';
  final testPrefix = isTest ? 'Test: ' : '';
  final body =
      '$syncLabel$unreadSavedCount unread saved articles (threshold $threshold). '
      'Sample: ${article.url}';

  await notifications.show(
    _kSyncNotificationId,
    '$testPrefix${article.title}',
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _syncChannel.id,
        _syncChannel.name,
        channelDescription: _syncChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.recommendation,
        visibility: NotificationVisibility.public,
        styleInformation: BigTextStyleInformation(body),
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            _kReadActionId,
            'Read',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      ),
    ),
    payload: payload,
  );
}

Future<void> _initializeNotifications(
  FlutterLocalNotificationsPlugin notifications, {
  required bool requestPermission,
  bool registerResponseHandlers = false,
}) async {
  const settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );

  await notifications.initialize(
    settings,
    onDidReceiveNotificationResponse: registerResponseHandlers
        ? BackgroundSyncService.handleNotificationResponse
        : null,
    onDidReceiveBackgroundNotificationResponse: registerResponseHandlers
        ? notificationTapBackground
        : null,
  );

  final androidPlugin = notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  await androidPlugin?.createNotificationChannel(_syncChannel);

  if (requestPermission) {
    await androidPlugin?.requestNotificationsPermission();
  }
}

int _sanitizeThreshold(int? value) {
  final source = value ?? kDefaultUnreadNotificationThreshold;
  return source.clamp(
    kMinUnreadNotificationThreshold,
    kMaxUnreadNotificationThreshold,
  );
}

int? _parseArticleIdFromPayload(String? payload) {
  if (payload == null || payload.isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) {
      final id = decoded['articleId'];
      if (id is int) {
        return id;
      }
      if (id is String) {
        return int.tryParse(id);
      }
    }
  } catch (_) {
    // Ignore malformed payloads.
  }

  return null;
}
