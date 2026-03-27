import 'package:dio/dio.dart';
import 'package:dart_rss/dart_rss.dart';
import 'package:reader/core/models/rss_preview.dart';
import 'package:reader/core/parsing/rss_content_parser.dart';

class RssService {
  const RssService(this._dio);

  final Dio _dio;

  Future<String> inferFeedName(String rssUrl) async {
    try {
      final feed = await _loadFeed(rssUrl);
      final feedTitle = (feed.title ?? '').trim();
      if (feedTitle.isNotEmpty) {
        return feedTitle;
      }
    } catch (_) {
      // Fall back to host name when RSS metadata cannot be fetched.
    }

    final parsed = Uri.tryParse(rssUrl);
    if (parsed != null) {
      final host = parsed.host.replaceFirst('www.', '');
      if (host.isNotEmpty) {
        return host;
      }
    }

    return rssUrl;
  }

  Future<List<RssArticlePreview>> fetchArticles({
    required String sourceName,
    required String feedUrl,
  }) async {
    final feed = await _loadFeed(feedUrl);
    final feedTitle = (feed.title ?? '').trim();
    final source = feedTitle.isNotEmpty ? feedTitle : sourceName;

    return feed.items
        .where((item) {
          final link = item.link?.trim() ?? '';
          final title = item.title?.trim() ?? '';
          return link.isNotEmpty && title.isNotEmpty;
        })
        .map((item) {
          return parseRssPreviewFromItem(item, source: source);
        })
        .toList(growable: false);
  }

  Future<RssFeed> _loadFeed(String sourceUrl) async {
    final response = await _dio.get<String>(
      sourceUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final body = (response.data ?? '').trim();

    try {
      return RssFeed.parse(body);
    } catch (_) {
      // If URL points to a website page, discover feed URL and retry.
      final discovered = discoverFeedUrlFromHtml(body, sourceUrl);
      if (discovered == null) {
        rethrow;
      }

      final discoveredResponse = await _dio.get<String>(
        discovered,
        options: Options(responseType: ResponseType.plain),
      );

      return RssFeed.parse((discoveredResponse.data ?? '').trim());
    }
  }
}
