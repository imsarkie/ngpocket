import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ngpocket/core/database/app_database.dart';
import 'package:ngpocket/core/services/rss_service.dart';
import 'package:ngpocket/core/utils/reading_time.dart';
import 'package:workmanager/workmanager.dart';

const String kMorningRssSyncTask = 'morning-rss-sync-task';
const String _kMorningRssSyncUniqueName = 'morning-rss-sync-unique';

const AndroidNotificationChannel _syncChannel = AndroidNotificationChannel(
  'rss_sync_channel',
  'RSS Sync',
  description: 'Notifications after automatic RSS synchronization.',
  importance: Importance.defaultImportance,
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

      if (updatedFeedCount > 0) {
        final feedSuffix = updatedFeedCount == 1 ? '' : 's';
        await notifications.show(
          1001,
          'Morning sync complete',
          'Updated $updatedFeedCount feed$feedSuffix.',
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
      }

      return true;
    } finally {
      await db.close();
    }
  });
}

class BackgroundSyncService {
  const BackgroundSyncService._();

  static Future<void> initializeAndSchedule() async {
    await Workmanager().initialize(backgroundSyncCallbackDispatcher);

    final notifications = FlutterLocalNotificationsPlugin();
    await _initializeNotifications(notifications, requestPermission: true);

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

Future<void> _initializeNotifications(
  FlutterLocalNotificationsPlugin notifications, {
  required bool requestPermission,
}) async {
  const settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );

  await notifications.initialize(settings);

  final androidPlugin = notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  await androidPlugin?.createNotificationChannel(_syncChannel);

  if (requestPermission) {
    await androidPlugin?.requestNotificationsPermission();
  }
}
