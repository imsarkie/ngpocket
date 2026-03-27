import 'package:reader/core/database/app_database.dart';

class SwipeCardParsedData {
  const SwipeCardParsedData({
    required this.description,
    required this.sourceLabel,
    required this.readingTimeMinutes,
  });

  final String description;
  final String sourceLabel;
  final int readingTimeMinutes;
}

SwipeCardParsedData parseSwipeCardData(Article article) {
  return SwipeCardParsedData(
    description: compactSwipeCardDescription(article.description ?? ''),
    sourceLabel: _normalizeSwipeCardSource(article.source),
    readingTimeMinutes: article.readingTime,
  );
}

String compactSwipeCardDescription(String input) {
  final text = input.trim();
  if (text.isEmpty) {
    return text;
  }

  final withoutMarkdownLinks = text.replaceAllMapped(
    RegExp("\\[([^\\]]+)\\]\\(([^\\)]+)\\)"),
    (match) => match.group(1) ?? '',
  );

  return withoutMarkdownLinks.replaceAll(RegExp('\\s+'), ' ').trim();
}

String _normalizeSwipeCardSource(String? source) {
  final cleaned = source?.trim();
  if (cleaned == null || cleaned.isEmpty) {
    return 'Web';
  }
  return cleaned;
}
