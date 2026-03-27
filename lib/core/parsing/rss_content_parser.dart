import 'package:dart_rss/dart_rss.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';
import 'package:reader/core/models/rss_preview.dart';
import 'package:reader/core/utils/html_cleaner.dart';

final _rxAtomSelfLink = RegExp(
  '<atom:link[^>]*rel=["\\\']self["\\\'][^>]*href=["\\\']([^"\\\']+)["\\\']',
  caseSensitive: false,
);

final _rxGenericLinks = RegExp(
  '<link>(https?://[^<]+)</link>',
  caseSensitive: false,
);

final _rxExtension = RegExp(r'\.[a-zA-Z0-9]+$');
final _rxWhitespace = RegExp(r'\s+');

final _rxImgSrc = RegExp(
  '<img[^>]+src=["\\\']([^"\\\']+)["\\\']',
  caseSensitive: false,
);

RssFeed? tryParseRssDocument(String document) {
  try {
    return RssFeed.parse(document);
  } catch (_) {
    return null;
  }
}

String? extractFeedUrlFromRssDocument(String document) {
  final atomSelfLink = _rxAtomSelfLink.firstMatch(document)?.group(1);

  final normalizedSelfLink = normalizeHttpUrl(atomSelfLink);
  if (normalizedSelfLink != null) {
    return normalizedSelfLink;
  }

  final genericLinks = _rxGenericLinks.allMatches(document);

  for (final match in genericLinks) {
    final candidate = normalizeHttpUrl(match.group(1));
    if (candidate != null) {
      return candidate;
    }
  }

  return null;
}

String inferImportedRssSourceName(RssFeed feed, {String? sourceNameHint}) {
  final feedTitle = (feed.title ?? '').trim();
  if (feedTitle.isNotEmpty) {
    return feedTitle;
  }

  final hint = (sourceNameHint ?? 'Imported RSS').trim();
  if (hint.isEmpty) {
    return 'Imported RSS';
  }

  return hint.replaceAll(_rxExtension, '').trim();
}

String buildImportedRssSyntheticUrl(String sourceName, {DateTime? now}) {
  final timestamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final slug = sourceName.toLowerCase().replaceAll(_rxWhitespace, '-');
  return 'imported-rss://$timestamp/$slug';
}

RssArticlePreview parseRssPreviewFromItem(
  RssItem item, {
  required String source,
}) {
  final title = item.title?.trim() ?? '';
  final link = item.link?.trim() ?? '';
  // item.content is RssContent — use .value to get the HTML string,
  // NOT .toString() which returns "Instance of 'RssContent'".
  final fallbackContent = item.content?.value ?? '';
  final description = item.description?.trim() ?? '';
  final rawBody = description.isNotEmpty ? description : fallbackContent;

  // Prefer enclosure URL, then images inside the HTML body, then
  // images extracted by dart_rss from content:encoded.
  final contentImage = item.content?.images.isNotEmpty == true
      ? item.content!.images.first
      : null;

  return RssArticlePreview(
    title: title,
    url: link,
    source: source,
    description: extractDescription(rawBody),
    publishedAt: parseRssPublishedAt(item.pubDate?.toString()),
    image: extractRssImage(rawBody, item.enclosure?.url?.toString()) ?? contentImage,
  );
}

DateTime? parseRssPublishedAt(String? input) {
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

String? extractRssImage(String html, String? enclosureUrl) {
  if (enclosureUrl != null && enclosureUrl.trim().isNotEmpty) {
    return enclosureUrl.trim();
  }

  final match = _rxImgSrc.firstMatch(html);
  return match?.group(1);
}

String? discoverFeedUrlFromHtml(String html, String baseUrl) {
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

String? normalizeHttpUrl(String? raw) {
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

bool looksLikeRssDocument(String content) {
  final lower = content.toLowerCase();
  return lower.contains('<rss') ||
      lower.contains('<feed') ||
      lower.contains('<rdf:rdf');
}
