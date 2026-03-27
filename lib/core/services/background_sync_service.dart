import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:reader/core/database/app_database.dart';
import 'package:reader/features/feed/presentation/swipe_reader_screen.dart';
import 'package:reader/features/reader/presentation/reader_screen.dart';
import 'package:reader/core/services/rss_service.dart';
import 'package:reader/core/utils/reading_time.dart';
import 'package:workmanager/workmanager.dart';

const String kMorningRssSyncTask = 'morning-rss-sync-task';
const String _kMorningRssSyncUniqueName = 'reader.sync.morning';

const String kLibraryReminderTask = 'library-reminder-task';
const String _kLibraryReminderUniqueName = 'reader.sync.reminders';
const String kSettingsMorningSyncNotificationsEnabledKey =
    'settings.morning_sync_notifications_enabled';
const String kSettingsUnreadNotificationThresholdKey =
    'settings.unread_notification_threshold';
const int kMinUnreadNotificationThreshold = 3;
const int kMaxUnreadNotificationThreshold = 10;
const int kDefaultUnreadNotificationThreshold = 5;

const AndroidNotificationChannel _syncChannel = AndroidNotificationChannel(
  'rss_sync_channel_v2',
  'RSS Sync',
  description: 'Notifications after automatic RSS synchronization.',
  importance: Importance.high,
);

@pragma('vm:entry-point')
void backgroundSyncCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    
    if (task == kMorningRssSyncTask) {
      await BackgroundSyncService.syncFeedsAndNotify(notifyUser: true);
    } else if (task == kLibraryReminderTask) {
      await BackgroundSyncService.checkLibraryReminders();
    }
    
    return true;
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

  static Future<void> syncFeedsAndNotify({bool notifyUser = true}) async {
    final notifications = FlutterLocalNotificationsPlugin();
    await _initializeNotifications(notifications, requestPermission: false);

    final db = AppDatabase();
    try {
      final feeds = await db.select(db.feeds).get();
      if (feeds.isEmpty) {
        return;
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
      var newArticlesFound = 0;

      for (final feed in feeds) {
        try {
          final previews = await rssService.fetchArticles(
            sourceName: feed.name,
            feedUrl: feed.rssUrl,
          );

          for (final preview in previews) {
            final isNew = await db.upsertFeedPreview(
              title: preview.title,
              url: preview.url,
              source: preview.source,
              description: preview.description,
              image: preview.image,
              publishedAt: preview.publishedAt,
              readingTime: estimateReadingTimeFromText(preview.description),
            );
            if (isNew) {
              newArticlesFound++;
            }
          }

          await db.updateFeedTimestamp(feed.id);
          updatedFeedCount++;
        } catch (_) {
          // Continue syncing other feeds even when one fails.
        }
      }

      if (notifyUser && newArticlesFound > 0) {
        await _showSwipeReadingNotification(
          notifications: notifications,
          updatedFeedCount: updatedFeedCount,
          newArticlesFound: newArticlesFound,
        );
      }
    } finally {
      await db.close();
    }
  }

  static Future<void> checkLibraryReminders() async {
    final db = AppDatabase();
    try {
      final unreadSavedCount = await db.countUnreadSavedArticles();
      if (unreadSavedCount > 0) {
        final topUnread = await db.findLatestUnreadSavedArticle();
        if (topUnread != null) {
          final notifications = FlutterLocalNotificationsPlugin();
          await _initializeNotifications(
            notifications,
            requestPermission: false,
          );
          
          await _showLibraryUnreadNotification(
            notifications: notifications,
            unreadSavedCount: unreadSavedCount,
            article: topUnread,
          );
        }
      }
    } finally {
      await db.close();
    }
  }

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
      unawaited(_routeFromPayload(launchPayload));
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
      initialDelay: _initialDelayUntilOnePM(),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 15),
    );

    return true;
  }

  static Future<void> updateLibraryReminderTask(Duration? interval) async {
    await initialize();

    if (interval == null) {
      await Workmanager().cancelByUniqueName(_kLibraryReminderUniqueName);
      return;
    }

    await Workmanager().registerPeriodicTask(
      _kLibraryReminderUniqueName,
      kLibraryReminderTask,
      frequency: interval,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  static Future<void> showTestUnreadNotification({
    required int threshold, // Leaving signature intact to not break settings_provider yet
  }) async {
    await checkLibraryReminders();
  }

  static void handleNotificationResponse(NotificationResponse response) {
    unawaited(_routeFromPayload(response.payload));
  }

  static Future<void> _routeFromPayload(String? payload) async {
    if (payload == null || payload.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final type = decoded['type'];
      final now = DateTime.now();

      for (var attempt = 0; attempt < 10; attempt++) {
        final nav = navigatorKey.currentState;
        if (nav != null) {
          if (type == 'swipe') {
            if (_lastOpenAt != null &&
                now.difference(_lastOpenAt!) < const Duration(seconds: 2)) {
              return;
            }
            _lastOpenAt = now;
            nav.push(MaterialPageRoute(builder: (_) => const SwipeReaderScreen()));
            return;
          } else if (type == 'read') {
            final articleId = decoded['articleId'];
            if (articleId is! int) return;

            if (_lastOpenedArticleId == articleId &&
                _lastOpenAt != null &&
                now.difference(_lastOpenAt!) < const Duration(seconds: 2)) {
              return;
            }

            final db = AppDatabase();
            try {
              final article = await db.findArticleById(articleId);
              if (article != null) {
                _lastOpenedArticleId = articleId;
                _lastOpenAt = now;
                nav.push(
                  MaterialPageRoute(builder: (_) => ReaderScreen(article: article)),
                );
              }
            } finally {
              await db.close();
            }
            return;
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 180));
      }
    } catch (_) {
      // Ignore malformed payloads natively.
    }
  }

  static Duration _initialDelayUntilOnePM() {
  final now = DateTime.now();
  var scheduled = DateTime(now.year, now.month, now.day, 13);

  if (now.isAfter(scheduled) || now.isAtSameMomentAs(scheduled)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled.difference(now);
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

const int _kSwipeNotificationId = 1001;
const int _kLibraryNotificationId = 1002;

Future<void> _showSwipeReadingNotification({
  required FlutterLocalNotificationsPlugin notifications,
  required int updatedFeedCount,
  required int newArticlesFound,
}) async {
  final payload = jsonEncode({'type': 'swipe'});
  final feedSuffix = updatedFeedCount == 1 ? '' : 's';
  final articleSuffix = newArticlesFound == 1 ? '' : 's';

  await notifications.show(
    _kSwipeNotificationId,
    'Feeds Updated',
    'We successfully synced $updatedFeedCount feed$feedSuffix and found $newArticlesFound new article$articleSuffix to swipe!',
    NotificationDetails(
      android: AndroidNotificationDetails(
        _syncChannel.id,
        _syncChannel.name,
        channelDescription: _syncChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.recommendation,
        visibility: NotificationVisibility.public,
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            'swipe_action',
            'Swipe Reader',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      ),
    ),
    payload: payload,
  );
}

Future<void> _showLibraryUnreadNotification({
  required FlutterLocalNotificationsPlugin notifications,
  required int unreadSavedCount,
  required Article article,
}) async {
  final payload = jsonEncode({'type': 'read', 'articleId': article.id});
  final suffix = unreadSavedCount == 1 ? '' : 's';

  await notifications.show(
    _kLibraryNotificationId,
    'Unread in Library',
    'You have $unreadSavedCount unread saved article$suffix. Dive back into: ${article.title}',
    NotificationDetails(
      android: AndroidNotificationDetails(
        _syncChannel.id,
        _syncChannel.name,
        channelDescription: _syncChannel.description,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            'read_action',
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
    android: AndroidInitializationSettings('@mipmap/launcher_icon'),
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

