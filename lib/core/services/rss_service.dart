import 'package:dio/dio.dart';
import 'package:dart_rss/dart_rss.dart';
import 'package:ngpocket/core/models/rss_preview.dart';
import 'package:ngpocket/core/utils/html_cleaner.dart';

class RssService {
  const RssService(this._dio);

  final Dio _dio;

  Future<String> inferFeedName(String rssUrl) async {
    try {
      final response = await _dio.get<String>(
        rssUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final feed = RssFeed.parse(response.data ?? '');
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
    final response = await _dio.get<String>(
      feedUrl,
      options: Options(responseType: ResponseType.plain),
    );

    final feed = RssFeed.parse(response.data ?? '');
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

    return DateTime.tryParse(input);
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
