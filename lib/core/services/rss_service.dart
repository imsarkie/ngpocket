import 'package:dio/dio.dart';
import 'package:dart_rss/dart_rss.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';
import 'package:ngpocket/core/models/rss_preview.dart';
import 'package:ngpocket/core/utils/html_cleaner.dart';

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
          final title = item.title?.trim() ?? '';
          final link = item.link?.trim() ?? '';
          final fallbackContent = item.content?.toString() ?? '';
          final description = item.description?.toString() ?? '';
          final rawBody = description.isNotEmpty
              ? description
              : fallbackContent;

          return RssArticlePreview(
            title: title,
            url: link,
            source: source,
            description: extractDescription(rawBody),
            publishedAt: _parsePublishedAt(item.pubDate?.toString()),
            image: _extractImage(rawBody, item.enclosure?.url?.toString()),
          );
        })
        .toList(growable: false);
  }

  DateTime? _parsePublishedAt(String? input) {
    if (input == null || input.trim().isEmpty) {
      return null;
    }

    final normalized = input.trim();

    final iso = DateTime.tryParse(normalized);
    if (iso != null) {
      return iso;
    }

    for (final pattern in const [
      'EEE, dd MMM yyyy HH:mm:ss zzz',
      'EEE, dd MMM yyyy HH:mm zzz',
      'dd MMM yyyy HH:mm:ss zzz',
      'EEE, dd MMM yyyy HH:mm:ss',
    ]) {
      try {
        return DateFormat(pattern, 'en_US').parseUtc(normalized).toLocal();
      } catch (_) {
        // Try next supported RSS date format.
      }
    }

    return null;
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
      final discovered = _discoverFeedUrlFromHtml(body, sourceUrl);
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

  String? _discoverFeedUrlFromHtml(String html, String baseUrl) {
    final doc = html_parser.parse(html);
    final links = doc.getElementsByTagName('link');

    for (final link in links) {
      final rel = (link.attributes['rel'] ?? '').toLowerCase();
      final type = (link.attributes['type'] ?? '').toLowerCase();
      final href = (link.attributes['href'] ?? '').trim();
      if (href.isEmpty) {
        continue;
      }

      final isAlternate = rel.contains('alternate');
      final isFeedType =
          type.contains('rss') || type.contains('atom') || type.contains('xml');
      if (!isAlternate || !isFeedType) {
        continue;
      }

      final resolved = Uri.tryParse(baseUrl)?.resolve(href).toString();
      if (resolved != null && resolved.isNotEmpty) {
        return resolved;
      }
    }

    return null;
  }
}
