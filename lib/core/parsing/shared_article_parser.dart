import 'package:reader/core/models/parsed_article.dart';

class SharedArticleSavePayload {
  const SharedArticleSavePayload({
    required this.title,
    required this.url,
    required this.content,
    required this.description,
    required this.readingTime,
    required this.markSaved,
    this.image,
    this.source,
    this.author,
  });

  final String title;
  final String url;
  final String content;
  final String description;
  final int readingTime;
  final String? image;
  final String? source;
  final String? author;
  final bool markSaved;
}

SharedArticleSavePayload parseSharedArticleFromLink(
  ParsedArticle parsed, {
  required String requestedUrl,
  bool markSaved = true,
  String? sourceHint,
}) {
  final preferredSource = sourceHint?.trim();
  final parsedSource = Uri.tryParse(parsed.url)?.host;
  final requestedSource = Uri.tryParse(requestedUrl)?.host;

  return SharedArticleSavePayload(
    title: parsed.title,
    url: parsed.url,
    content: parsed.content,
    description: parsed.description,
    readingTime: parsed.readingTime,
    image: parsed.image,
    source: preferredSource?.isNotEmpty == true
        ? preferredSource
        : (parsedSource?.isNotEmpty == true ? parsedSource : requestedSource),
    author: parsed.author,
    markSaved: markSaved,
  );
}
