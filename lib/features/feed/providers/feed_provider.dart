import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader/core/database/app_database.dart';
import 'package:reader/core/database/database_provider.dart';
import 'package:reader/core/parsing/shared_article_parser.dart';
import 'package:reader/core/services/service_providers.dart';
import 'package:reader/features/settings/providers/settings_provider.dart';

final inboxArticlesProvider = StreamProvider<List<Article>>((ref) {
  return ref.watch(appDatabaseProvider).watchInboxArticles();
});

// ---------------------------------------------------------------------------
// Feed filter — drives the chip bar on the Read page
// ---------------------------------------------------------------------------

sealed class FeedFilter {
  const FeedFilter();
}

class FeedFilterAll extends FeedFilter {
  const FeedFilterAll();
}

class FeedFilterFolder extends FeedFilter {
  const FeedFilterFolder(this.folderId, this.folderName);
  final int folderId;
  final String folderName;
}

class FeedFilterSource extends FeedFilter {
  const FeedFilterSource(this.sourceName);
  final String sourceName;
}

final feedFilterProvider =
    StateProvider<FeedFilter>((ref) => const FeedFilterAll());

/// Articles filtered by the active [feedFilterProvider] selection.
final filteredInboxArticlesProvider = StreamProvider<List<Article>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final filter = ref.watch(feedFilterProvider);
  return switch (filter) {
    FeedFilterAll() => db.watchInboxArticles(),
    FeedFilterFolder(:final folderId) =>
      db.watchInboxArticlesByFolder(folderId),
    FeedFilterSource(:final sourceName) =>
      db.watchInboxArticlesBySource(sourceName),
  };
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

/// URLs currently being fetched/parsed in the background.
/// Watched by [ArticleListRow] to show a "Downloading…" indicator.
final downloadingUrlsProvider = StateProvider<Set<String>>((ref) => const {});

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
      final payload = parseSharedArticleFromLink(
        parsed,
        requestedUrl: article.url,
        markSaved: true,
        sourceHint: article.source,
      );

      await _db.saveParsedArticle(
        title: payload.title,
        url: payload.url,
        content: payload.content,
        description: payload.description,
        readingTime: payload.readingTime,
        image: payload.image,
        author: payload.author,
        markSaved: payload.markSaved,
        source: payload.source,
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
    final payload = parseSharedArticleFromLink(
      parsed,
      requestedUrl: url,
      markSaved: markSaved,
    );

    await _db.saveParsedArticle(
      title: payload.title,
      url: payload.url,
      content: payload.content,
      description: payload.description,
      readingTime: payload.readingTime,
      image: payload.image,
      author: payload.author,
      markSaved: payload.markSaved,
      source: payload.source,
    );
  }
}
