import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:ngpocket/core/models/parsed_article.dart';
import 'package:ngpocket/core/utils/html_cleaner.dart';
import 'package:ngpocket/core/utils/reading_time.dart';

class ArticleParserService {
  const ArticleParserService(this._dio);

  final Dio _dio;

  Future<ParsedArticle> parseFromUrl(
    String url, {
    String parserEndpoint = '',
  }) async {
    final remote = await _tryRemoteParser(url, parserEndpoint);
    if (remote != null) {
      return _normalizeParsed(remote);
    }

    final local = await _parseLocally(url);
    return _normalizeParsed(local);
  }

  Future<ParsedArticle?> _tryRemoteParser(
    String url,
    String parserEndpoint,
  ) async {
    final endpoint = parserEndpoint.trim();
    if (endpoint.isEmpty) {
      return null;
    }

    try {
      final normalized = endpoint.endsWith('/parse')
          ? endpoint
          : '${endpoint.replaceAll(RegExp(r'/$'), '')}/parse';
      final response = await _dio.post<dynamic>(normalized, data: {'url': url});
      final payload = response.data;
      if (payload is Map<String, dynamic>) {
        return ParsedArticle.fromJson(payload, url);
      }
    } catch (_) {
      // Fallback parsing is handled by the local parser.
    }

    return null;
  }

  Future<ParsedArticle> _parseLocally(String url) async {
    final response = await _dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );

    final html = response.data ?? '';
    final document = html_parser.parse(html);
    final readableText = extractReadableArticleText(html, baseUrl: url);
    final plainText = readableText.isEmpty
        ? htmlToPlainText(html)
        : readableText;
    final title =
        document
            .querySelector('meta[property="og:title"]')
            ?.attributes['content']
            ?.trim() ??
        document.querySelector('h1')?.text.trim() ??
        document.querySelector('title')?.text.trim() ??
        url;

    final image =
        document
            .querySelector('meta[property="og:image"]')
            ?.attributes['content']
            ?.trim() ??
        document.querySelector('img')?.attributes['src']?.trim();

    final author =
        document
            .querySelector('meta[name="author"]')
            ?.attributes['content']
            ?.trim() ??
        document
            .querySelector('meta[property="article:author"]')
            ?.attributes['content']
            ?.trim() ??
        document
            .querySelector('meta[name="twitter:creator"]')
            ?.attributes['content']
            ?.trim() ??
        document.querySelector('[itemprop="author"]')?.text.trim() ??
        document.querySelector('[rel="author"]')?.text.trim() ??
        _extractByline(document);

    return ParsedArticle(
      title: title,
      url: url,
      content: plainText,
      image: image,
      author: author,
      readingTime: estimateReadingTimeFromText(plainText),
      description: extractDescription(plainText),
    );
  }

  ParsedArticle _normalizeParsed(ParsedArticle parsed) {
    final normalizedContent = parsed.content.contains('<')
        ? extractReadableArticleText(parsed.content, baseUrl: parsed.url)
        : parsed.content;

    final cleanContent = normalizedContent.trim().isEmpty
        ? htmlToPlainText(parsed.content)
        : normalizedContent.trim();

    return ParsedArticle(
      title: parsed.title,
      url: parsed.url,
      content: cleanContent,
      image: parsed.image,
      author: parsed.author,
      readingTime: estimateReadingTimeFromText(cleanContent),
      description: extractDescription(cleanContent),
    );
  }

  String? _extractByline(Document document) {
    final byline = document
        .querySelector('.byline, .article-byline, .post-author, .author-name')
        ?.text
        .trim();
    if (byline == null || byline.isEmpty) {
      return null;
    }

    return byline.replaceFirst(RegExp(r'^by\s+', caseSensitive: false), '');
  }
}
