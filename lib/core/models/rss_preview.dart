class RssArticlePreview {
  const RssArticlePreview({
    required this.title,
    required this.url,
    required this.source,
    required this.description,
    required this.publishedAt,
    required this.image,
  });

  final String title;
  final String url;
  final String source;
  final String description;
  final DateTime? publishedAt;
  final String? image;
}
