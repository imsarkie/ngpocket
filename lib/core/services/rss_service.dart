import 'package:dio/dio.dart';
import 'package:ngpocket/core/models/rss_preview.dart';
import 'package:ngpocket/core/utils/html_cleaner.dart';
import 'package:webfeed/domain/rss_feed.dart';

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
      final feedTitle = feed.title?.trim();
      if (feedTitle != null && feedTitle.isNotEmpty) {
        return feedTitle;
      }
    } catch (_) {
      // Fall back to host name when RSS metadata cannot be fetched.
    }

    return Uri.tryParse(rssUrl)?.host.replaceFirst('www.', '') ?? rssUrl;
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
    final source = feed.title?.trim().isNotEmpty == true
        ? feed.title!.trim()
        : sourceName;

    return (feed.items ?? const [])
        .where(
          (item) =>
              (item.link ?? '').isNotEmpty && (item.title ?? '').isNotEmpty,
        )
        .map(
          (item) => RssArticlePreview(
            title: item.title!.trim(),
            url: item.link!.trim(),
            source: source,
            description: extractDescription(
              item.description ?? item.content?.value ?? '',
            ),
            publishedAt: item.pubDate,
            image: _extractImage(
              item.description ?? item.content?.value ?? '',
              item.enclosure?.url,
            ),
          ),
        )
        .toList(growable: false);
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
