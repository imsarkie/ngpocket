import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ngpocket/core/database/app_database.dart';
import 'package:ngpocket/core/database/database_provider.dart';
import 'package:ngpocket/core/services/service_providers.dart';
import 'package:ngpocket/features/settings/providers/settings_provider.dart';

final inboxArticlesProvider = StreamProvider<List<Article>>((ref) {
  return ref.watch(appDatabaseProvider).watchInboxArticles();
});

final swipeQueueProvider = StreamProvider<List<Article>>((ref) {
  return ref.watch(appDatabaseProvider).watchSwipeQueue();
});

final unreadCountProvider = StreamProvider<int>((ref) {
  return ref.watch(appDatabaseProvider).watchUnreadCount();
});

final sharedUrlStreamProvider = StreamProvider<String>((ref) {
  return ref.watch(shareIntentServiceProvider).sharedUrlStream();
});

final feedActionsProvider = Provider<FeedActions>((ref) => FeedActions(ref));

class FeedActions {
  FeedActions(this._ref);

  final Ref _ref;

  AppDatabase get _db => _ref.read(appDatabaseProvider);

  Future<void> saveArticle(int articleId, bool saved) {
    return _db.markSaved(articleId, saved);
  }

  Future<void> saveAndScrapeArticle(Article article) async {
    await _db.markSaved(article.id, true);

    try {
      final parser = _ref.read(articleParserServiceProvider);
      final settings = _ref.read(appSettingsProvider);
      final parsed = await parser.parseFromUrl(
        article.url,
        parserEndpoint: settings.parserEndpoint,
      );

      await _db.saveParsedArticle(
        title: parsed.title,
        url: parsed.url,
        content: parsed.content,
        description: parsed.description,
        readingTime: parsed.readingTime,
        image: parsed.image,
        author: parsed.author,
        markSaved: true,
        source:
            article.source ??
            Uri.tryParse(parsed.url)?.host ??
            Uri.tryParse(article.url)?.host,
      );
    } catch (error, stackTrace) {
      debugPrint('saveAndScrapeArticle failed for ${article.url}: $error');
      debugPrintStack(stackTrace: stackTrace);
      // Keep swipe interaction fast even if scraping fails.
    }
  }

  Future<void> markRead(int articleId, bool read) {
    return _db.markRead(articleId, read);
  }

  Future<void> ingestSharedUrl(String url, {bool markSaved = true}) async {
    final parser = _ref.read(articleParserServiceProvider);
    final settings = _ref.read(appSettingsProvider);

    final parsed = await parser.parseFromUrl(
      url,
      parserEndpoint: settings.parserEndpoint,
    );

    await _db.saveParsedArticle(
      title: parsed.title,
      url: parsed.url,
      content: parsed.content,
      description: parsed.description,
      readingTime: parsed.readingTime,
      image: parsed.image,
      author: parsed.author,
      markSaved: markSaved,
      source: Uri.tryParse(parsed.url)?.host,
    );
  }
}
