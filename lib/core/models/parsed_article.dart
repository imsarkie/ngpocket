class ParsedArticle {
  const ParsedArticle({
    required this.title,
    required this.url,
    required this.content,
    required this.image,
    required this.author,
    required this.readingTime,
    required this.description,
  });

  final String title;
  final String url;
  final String content;
  final String? image;
  final String? author;
  final int readingTime;
  final String description;

  factory ParsedArticle.fromJson(Map<String, dynamic> json, String url) {
    return ParsedArticle(
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : url,
      url: url,
      content:
          (json['content_html'] as String?) ??
          (json['content'] as String?) ??
          '',
      image: (json['image'] as String?)?.trim(),
      author: (json['author'] as String?)?.trim(),
      readingTime: (json['reading_time'] as num?)?.toInt() ?? 4,
      description: (json['description'] as String?)?.trim() ?? '',
    );
  }
}
