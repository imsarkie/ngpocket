import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ngpocket/core/database/app_database.dart';
import 'package:ngpocket/core/database/database_provider.dart';
import 'package:ngpocket/core/models/rss_preview.dart';
import 'package:ngpocket/core/services/service_providers.dart';
import 'package:ngpocket/core/utils/reading_time.dart';
import 'package:ngpocket/features/settings/providers/settings_provider.dart';

final feedsProvider = StreamProvider<List<Feed>>((ref) {
  return ref.watch(appDatabaseProvider).watchFeeds();
});

final feedArticlesProvider =
    FutureProvider.family<List<RssArticlePreview>, Feed>((ref, feed) {
      return ref
          .watch(rssServiceProvider)
          .fetchArticles(sourceName: feed.name, feedUrl: feed.rssUrl);
    });

final rssActionsProvider = Provider<RssActions>((ref) {
  return RssActions(ref);
});

class RssActions {
  RssActions(this._ref);

  final Ref _ref;

  AppDatabase get _db => _ref.read(appDatabaseProvider);

  Future<void> addFeed(String rssUrl) async {
    final cleanUrl = rssUrl.trim();
    if (cleanUrl.isEmpty) {
      return;
    }

    final name = await _ref.read(rssServiceProvider).inferFeedName(cleanUrl);
    final id = await _db.insertFeed(
      FeedsCompanion.insert(name: name, rssUrl: cleanUrl),
    );

    if (id > 0) {
      final feed = Feed(
        id: id,
        name: name,
        rssUrl: cleanUrl,
        lastUpdated: null,
        createdAt: DateTime.now(),
      );
      await refreshFeed(feed);
    }
  }

  Future<void> removeFeed(int id) async {
    await _db.removeFeed(id);
  }

  Future<void> refreshFeed(Feed feed) async {
    final previews = await _ref
        .read(rssServiceProvider)
        .fetchArticles(sourceName: feed.name, feedUrl: feed.rssUrl);

    for (final preview in previews) {
      await _db.upsertFeedPreview(
        title: preview.title,
        url: preview.url,
        source: preview.source,
        description: preview.description,
        image: preview.image,
        publishedAt: preview.publishedAt,
        readingTime: estimateReadingTimeFromText(preview.description),
      );
    }

    await _db.updateFeedTimestamp(feed.id);
  }

  Future<void> refreshAll() async {
    final allFeeds = await _db.select(_db.feeds).get();
    for (final feed in allFeeds) {
      await refreshFeed(feed);
    }
  }

  Future<void> downloadArticle(RssArticlePreview preview) async {
    await _db.upsertFeedPreview(
      title: preview.title,
      url: preview.url,
      source: preview.source,
      description: preview.description,
      image: preview.image,
      publishedAt: preview.publishedAt,
      readingTime: estimateReadingTimeFromText(preview.description),
    );

    final parser = _ref.read(articleParserServiceProvider);
    final settings = _ref.read(appSettingsProvider);
    final parsed = await parser.parseFromUrl(
      preview.url,
      parserEndpoint: settings.parserEndpoint,
    );

    await _db.saveParsedArticle(
      title: parsed.title,
      url: parsed.url,
      content: parsed.content,
      description: parsed.description,
      image: parsed.image,
      author: parsed.author,
      source: preview.source,
      readingTime: parsed.readingTime,
    );
  }
}
