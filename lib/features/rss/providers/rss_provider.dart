import 'package:dart_rss/dart_rss.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ngpocket/core/database/app_database.dart';
import 'package:ngpocket/core/database/database_provider.dart';
import 'package:ngpocket/core/models/rss_preview.dart';
import 'package:ngpocket/core/services/service_providers.dart';
import 'package:ngpocket/core/utils/html_cleaner.dart';
import 'package:ngpocket/core/utils/reading_time.dart';
import 'package:ngpocket/features/settings/providers/settings_provider.dart';

final feedsProvider = StreamProvider<List<Feed>>((ref) {
  return ref.watch(appDatabaseProvider).watchFeeds();
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
    final parsedFeed = _tryParseFeed(trimmed);
    if (parsedFeed != null) {
      await _importParsedFeed(parsedFeed, sourceNameHint: sourceNameHint);
      return true;
    }

    final feedUrl = _extractFeedUrlFromDocument(trimmed);
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

  Future<void> _importParsedFeed(
    RssFeed feed, {
    String? sourceNameHint,
  }) async {

    final feedTitle = (feed.title ?? '').trim();
    final sourceName = feedTitle.isNotEmpty
        ? feedTitle
        : ((sourceNameHint ?? 'Imported RSS')
              .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
              .trim());
    final syntheticUrl =
        'imported-rss://${DateTime.now().millisecondsSinceEpoch}/${sourceName.toLowerCase().replaceAll(RegExp(r'\s+'), '-')}';

    final id = await _db.insertFeed(
      FeedsCompanion.insert(name: sourceName, rssUrl: syntheticUrl),
    );

    for (final item in feed.items) {
      final link = item.link?.trim() ?? '';
      final title = item.title?.trim() ?? '';
      if (link.isEmpty || title.isEmpty) {
        continue;
      }

      final description =
          item.description?.toString() ?? item.content?.toString() ?? '';
      final normalizedDescription = extractDescription(description);
      await _db.upsertFeedPreview(
        title: title,
        url: link,
        source: sourceName,
        description: normalizedDescription,
        image: _extractImage(description, item.enclosure?.url?.toString()),
        publishedAt: DateTime.tryParse(item.pubDate?.toString() ?? ''),
        readingTime: estimateReadingTimeFromText(normalizedDescription),
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

  String? _extractFeedUrlFromDocument(String document) {
    final atomSelfLink = RegExp(
      '<atom:link[^>]*rel=["\\\']self["\\\'][^>]*href=["\\\']([^"\\\']+)["\\\']',
      caseSensitive: false,
    ).firstMatch(document)?.group(1);

    final normalizedSelfLink = _normalizeHttpUrl(atomSelfLink);
    if (normalizedSelfLink != null) {
      return normalizedSelfLink;
    }

    final genericLinks = RegExp(
      '<link>(https?://[^<]+)</link>',
      caseSensitive: false,
    ).allMatches(document);
    for (final match in genericLinks) {
      final candidate = _normalizeHttpUrl(match.group(1));
      if (candidate != null) {
        return candidate;
      }
    }

    return null;
  }

  String? _normalizeHttpUrl(String? raw) {
    if (raw == null) {
      return null;
    }

    final candidate = raw.trim();
    if (candidate.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(candidate);
    if (uri == null) {
      return null;
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }

    return candidate;
  }

  RssFeed? _tryParseFeed(String document) {
    try {
      return RssFeed.parse(document);
    } catch (_) {
      return null;
    }
  }

  String? _extractImage(String html, String? enclosureUrl) {
    if (enclosureUrl != null && enclosureUrl.trim().isNotEmpty) {
      return enclosureUrl.trim();
    }

    final match = RegExp(
      '<img[^>]+src=["\\\']([^"\\\']+)["\\\']',
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(1);
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
  final rows = await (db.select(db.articles)
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
