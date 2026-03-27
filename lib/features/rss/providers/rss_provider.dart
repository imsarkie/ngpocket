import 'dart:async';

import 'package:dart_rss/dart_rss.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader/core/database/app_database.dart';
import 'package:reader/core/database/database_provider.dart';
import 'package:reader/core/models/rss_preview.dart';
import 'package:reader/core/parsing/rss_content_parser.dart';
import 'package:reader/core/services/service_providers.dart';
import 'package:reader/core/utils/reading_time.dart';
import 'package:reader/features/settings/providers/settings_provider.dart';

final feedsProvider = StreamProvider<List<Feed>>((ref) {
  return ref.watch(appDatabaseProvider).watchFeeds();
});

/// Groups folders with their assigned feeds, plus an uncategorised bucket.
/// Merges [watchFolders] and [watchFeeds] so it reacts to EITHER change.
final foldersWithFeedsProvider =
    StreamProvider<FoldersWithFeedsState>((ref) {
  final db = ref.watch(appDatabaseProvider);

  // We use a broadcast StreamController so we can feed it from two sources.
  final sc = StreamController<FoldersWithFeedsState>.broadcast();

  var _folders = <FolderRow>[];
  var _feeds = <Feed>[];
  var _ready = 0; // counts how many streams have emitted at least once

  void _recompute() {
    if (_ready < 2) return; // wait until both streams have initialised
    final grouped = <int, List<Feed>>{};
    final uncategorised = <Feed>[];
    for (final feed in _feeds) {
      final fid = feed.folderId;
      if (fid == null) {
        uncategorised.add(feed);
      } else {
        grouped.putIfAbsent(fid, () => []).add(feed);
      }
    }
    final folderItems = _folders
        .map((f) => FolderWithFeeds(folder: f, feeds: grouped[f.id] ?? const []))
        .toList(growable: false);
    if (!sc.isClosed) {
      sc.add(FoldersWithFeedsState(
        folders: folderItems,
        uncategorised: uncategorised,
      ));
    }
  }

  var _folderFirst = true;
  final folderSub = db.watchFolders().listen(
    (folders) {
      _folders = folders;
      if (_folderFirst) {
        _folderFirst = false;
        _ready++;
      }
      _recompute();
    },
    onError: sc.addError,
  );

  var _feedFirst = true;
  final feedSub = db.watchFeeds().listen(
    (feeds) {
      _feeds = feeds;
      if (_feedFirst) {
        _feedFirst = false;
        _ready++;
      }
      _recompute();
    },
    onError: sc.addError,
  );

  ref.onDispose(() {
    folderSub.cancel();
    feedSub.cancel();
    sc.close();
  });

  return sc.stream;
});

final feedArticlesProvider =
    FutureProvider.family<List<RssArticlePreview>, Feed>((ref, feed) {
      if (_isImportedFeedUrl(feed.rssUrl)) {
        return _loadImportedFeedArticles(ref, feed.name);
      }
      return ref
          .watch(rssServiceProvider)
          .fetchArticles(sourceName: feed.name, feedUrl: feed.rssUrl);
    });

final rssActionsProvider = Provider<RssActions>((ref) {
  return RssActions(ref);
});

// ---------------------------------------------------------------------------
// Value objects
// ---------------------------------------------------------------------------

class FolderWithFeeds {
  const FolderWithFeeds({required this.folder, required this.feeds});
  final FolderRow folder;
  final List<Feed> feeds;
}

class FoldersWithFeedsState {
  const FoldersWithFeedsState({
    required this.folders,
    required this.uncategorised,
  });
  final List<FolderWithFeeds> folders;
  final List<Feed> uncategorised;

  bool get isEmpty => folders.isEmpty && uncategorised.isEmpty;
}

class RssActions {
  RssActions(this._ref);

  final Ref _ref;

  AppDatabase get _db => _ref.read(appDatabaseProvider);

  Future<void> addFeed(String rssUrl) async {
    final cleanUrl = rssUrl.trim();
    if (cleanUrl.isEmpty) {
      return;
    }

    final rssService = _ref.read(rssServiceProvider);
    final previews = await rssService.fetchArticles(
      sourceName: cleanUrl,
      feedUrl: cleanUrl,
    );

    final inferredName = previews.isNotEmpty
        ? previews.first.source
        : await rssService.inferFeedName(cleanUrl);

    final id = await _db.insertFeed(
      FeedsCompanion.insert(name: inferredName, rssUrl: cleanUrl),
    );

    final feedId = id > 0 ? id : await _findFeedIdByUrl(cleanUrl);
    if (feedId == null) {
      return;
    }

    await _storePreviews(previews);
    await _db.updateFeedTimestamp(feedId);
  }

  Future<bool> importFeedFromDocument(
    String document, {
    String? sourceNameHint,
  }) async {
    final trimmed = document.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    // Prefer importing the local RSS/XML content directly. This avoids using
    // website homepage links (<link>) as feed URLs.
    final parsedFeed = tryParseRssDocument(trimmed);
    if (parsedFeed != null) {
      await _importParsedFeed(parsedFeed, sourceNameHint: sourceNameHint);
      return true;
    }

    final feedUrl = extractFeedUrlFromRssDocument(trimmed);
    if (feedUrl != null) {
      try {
        await addFeed(feedUrl);
        return true;
      } catch (_) {
        return false;
      }
    }

    return false;
  }

  Future<void> _importParsedFeed(RssFeed feed, {String? sourceNameHint}) async {
    final sourceName = inferImportedRssSourceName(
      feed,
      sourceNameHint: sourceNameHint,
    );
    final syntheticUrl = buildImportedRssSyntheticUrl(sourceName);

    final id = await _db.insertFeed(
      FeedsCompanion.insert(name: sourceName, rssUrl: syntheticUrl),
    );

    for (final item in feed.items) {
      final link = item.link?.trim() ?? '';
      final title = item.title?.trim() ?? '';
      if (link.isEmpty || title.isEmpty) {
        continue;
      }

      final preview = parseRssPreviewFromItem(item, source: sourceName);
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

    final feedId = id > 0 ? id : await _findFeedIdByUrl(syntheticUrl);
    if (feedId != null) {
      await _db.updateFeedTimestamp(feedId);
    }
  }

  Future<void> removeFeed(int id) async {
    await _db.removeFeed(id);
  }

  // ---------------------------------------------------------------------------
  // Folder actions
  // ---------------------------------------------------------------------------

  Future<void> createFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _db.insertFolder(trimmed);
  }

  Future<void> renameFolder(int id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    await _db.renameFolder(id, trimmed);
  }

  Future<void> deleteFolder(int id) async {
    // Feeds with this folder_id are set to NULL by the ON DELETE SET NULL FK.
    await _db.deleteFolder(id);
  }

  Future<void> moveFeedToFolder(int feedId, int? folderId) async {
    await _db.moveFeedToFolder(feedId, folderId);
  }

  Future<void> refreshFeed(Feed feed) async {
    if (_isImportedFeedUrl(feed.rssUrl)) {
      return;
    }

    final previews = await _ref
        .read(rssServiceProvider)
        .fetchArticles(sourceName: feed.name, feedUrl: feed.rssUrl);

    await _storePreviews(previews);

    await _db.updateFeedTimestamp(feed.id);
  }

  Future<void> refreshAll() async {
    final allFeeds = await _db.select(_db.feeds).get();
    for (final feed in allFeeds) {
      if (_isImportedFeedUrl(feed.rssUrl)) {
        continue;
      }
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

  Future<void> _storePreviews(List<RssArticlePreview> previews) async {
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
  }

  Future<int?> _findFeedIdByUrl(String rssUrl) async {
    final existing = await (_db.select(
      _db.feeds,
    )..where((tbl) => tbl.rssUrl.equals(rssUrl))).getSingleOrNull();
    return existing?.id;
  }
}

bool _isImportedFeedUrl(String url) {
  return url.startsWith('imported-rss://');
}

Future<List<RssArticlePreview>> _loadImportedFeedArticles(
  Ref ref,
  String sourceName,
) async {
  final db = ref.read(appDatabaseProvider);
  final rows =
      await (db.select(db.articles)
            ..where((tbl) => tbl.source.equals(sourceName))
            ..orderBy([
              (tbl) => OrderingTerm(
                expression: tbl.publishedAt,
                mode: OrderingMode.desc,
              ),
              (tbl) => OrderingTerm(
                expression: tbl.createdAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .get();

  return rows
      .where((row) => row.url.trim().isNotEmpty && row.title.trim().isNotEmpty)
      .map(
        (row) => RssArticlePreview(
          title: row.title,
          url: row.url,
          source: row.source ?? sourceName,
          description: row.description ?? '',
          image: row.image,
          publishedAt: row.publishedAt,
        ),
      )
      .toList(growable: false);
}
