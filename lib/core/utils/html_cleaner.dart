import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

const _noiseSelectors = [
  'script',
  'style',
  'noscript',
  'iframe',
  'svg',
  'canvas',
  'header',
  'footer',
  'nav',
  'aside',
  'form',
  'button',
  '.share',
  '.social',
  '.newsletter',
  '.donation',
  '.related',
  '.comments',
  '.recommended',
  '.menu',
  '.sidebar',
  '#comments',
  '#sidebar',
  '#footer',
  '#header',
];

const _noiseClassKeywords = [
  'share',
  'social',
  'footer',
  'header',
  'menu',
  'nav',
  'newsletter',
  'donat',
  'related',
  'comment',
  'recommend',
  'cookie',
  'promo',
  'banner',
  'subscription',
  'signup',
];

const _boilerplatePrefixes = [
  'click to share',
  'view full site',
  'print article',
  'email article',
  'filed under',
  'start now',
  'give now',
  'published ',
  '\u2014 published',
  '\u2013 published',
  '-- published',
  '- published',
];

const _menuWords = {
  'home',
  'about',
  'contact',
  'newsletter',
  'facebook',
  'x',
  'twitter',
  'reddit',
  'linkedin',
  'threads',
  'pinterest',
  'whatsapp',
  'pocket',
};

String htmlToPlainText(String html) {
  final document = html_parser.parse(html);
  final text = document.body?.text ?? document.documentElement?.text ?? '';
  return _normalizeWhitespace(text);
}

String extractReadableArticleText(String html, {String? baseUrl}) {
  final document = html_parser.parse(html);
  final root = _bestContentRoot(document);

  _removeNoiseElements(root);

  final blocks = <String>[];
  final nodes = root.querySelectorAll('h2, h3, h4, p, li, blockquote');
  for (final node in nodes) {
    // Skip nodes nested inside a blockquote — the blockquote itself will be
    // extracted as a single block, so its children should not be duplicated.
    if (node.localName != 'blockquote') {
      var ancestor = node.parent;
      var insideBlockquote = false;
      while (ancestor != null && ancestor != root) {
        if (ancestor.localName == 'blockquote') {
          insideBlockquote = true;
          break;
        }
        ancestor = ancestor.parent;
      }
      if (insideBlockquote) {
        continue;
      }
    }

    if (_isLikelyLinkFarm(node)) {
      continue;
    }

    final text = _normalizeWhitespace(_extractNodeText(node, baseUrl: baseUrl));
    final cleaned = _sanitizeExtractedBlock(text);
    if (cleaned == null) {
      continue;
    }

    final isByline = _isBylineLine(cleaned);
    if (isByline) {
      continue;
    }

    final normalizedHeading = _normalizeHeadingCandidate(cleaned);
    if (text.isEmpty || _isBoilerplateLine(text)) {
      continue;
    }

    if (node.localName == 'blockquote') {
      // Extract each child <p> inside the blockquote as a separate quote line
      // so multi-paragraph quotes stay properly separated.
      final innerParagraphs = node.querySelectorAll('p');
      if (innerParagraphs.isNotEmpty) {
        for (final p in innerParagraphs) {
          final pText = _normalizeWhitespace(
            _extractNodeText(p, baseUrl: baseUrl),
          );
          final pCleaned = _sanitizeExtractedBlock(pText);
          if (pCleaned != null && !_isBylineLine(pCleaned)) {
            blocks.add('> $pCleaned');
          }
        }
      } else {
        blocks.add('> $cleaned');
      }
      continue;
    }

    if (node.localName != null && node.localName!.startsWith('h')) {
      if (_isBoilerplateLine(normalizedHeading) ||
          _isBylineLine(normalizedHeading)) {
        continue;
      }
      blocks.add('## $normalizedHeading');
      continue;
    }

    if (node.localName == 'li') {
      blocks.add('- $cleaned');
      continue;
    }

    blocks.add(cleaned);
  }

  if (blocks.isEmpty) {
    final fallbackLines = _normalizeWhitespace(root.text)
        .split(RegExp(r'\n+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !_isBoilerplateLine(line))
        .toList(growable: false);
    return fallbackLines.join('\n\n');
  }

  return blocks.join('\n\n');
}

String extractDescription(String htmlOrText, {int maxLength = 180}) {
  final clean = _normalizeWhitespace(
    htmlOrText.contains('<')
        ? extractReadableArticleText(htmlOrText)
        : htmlOrText,
  );
  if (clean.length <= maxLength) {
    return clean;
  }
  return '${clean.substring(0, maxLength).trim()}...';
}

String _normalizeWhitespace(String text) {
  return text
      .replaceAll(RegExp(r'\u00A0'), ' ')
      .replaceAll(RegExp(r'\r\n?'), '\n')
      .replaceAll(RegExp(r'\n\s+'), '\n')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .trim();
}

Element _bestContentRoot(Document document) {
  final candidates = <Element>[
    ...document.querySelectorAll(
      'article, main, [role="main"], .post-content, .entry-content, .article-content, .story-content, .content, #content',
    ),
  ];

  if (candidates.isEmpty) {
    return document.body ?? document.documentElement!;
  }

  Element best = candidates.first;
  var bestScore = _candidateScore(best);
  for (final candidate in candidates.skip(1)) {
    final score = _candidateScore(candidate);
    if (score > bestScore) {
      best = candidate;
      bestScore = score;
    }
  }

  return best;
}

int _candidateScore(Element element) {
  final textLength = _normalizeWhitespace(element.text).length;
  final paragraphCount = element.querySelectorAll('p').length;
  final linkCount = element.querySelectorAll('a').length;
  return textLength + (paragraphCount * 120) - (linkCount * 45);
}

void _removeNoiseElements(Element root) {
  for (final selector in _noiseSelectors) {
    for (final node in root.querySelectorAll(selector)) {
      node.remove();
    }
  }

  for (final node in root.querySelectorAll('*')) {
    final className = (node.className).toLowerCase();
    final id = (node.id).toLowerCase();
    final marker = '$className $id';

    if (_noiseClassKeywords.any(marker.contains)) {
      node.remove();
    }
  }
}

bool _isBoilerplateLine(String input) {
  final line = input.trim();
  if (line.isEmpty) {
    return true;
  }

  final lower = line.toLowerCase();

  if (_boilerplatePrefixes.any(lower.startsWith)) {
    return true;
  }

  if (RegExp(r'^(https?://|www\.)', caseSensitive: false).hasMatch(lower)) {
    return true;
  }

  if (RegExp(r'^\[[^\]]+\]\(https?://[^\s)]+\)$').hasMatch(line)) {
    return true;
  }

  if (RegExp(r'^[\-\u2013\u2014\s]{1,4}$').hasMatch(line)) {
    return true;
  }

  if (_menuWords.contains(lower)) {
    return true;
  }

  final words = lower.split(RegExp(r'\s+'));
  if (words.length <= 3 && words.every((word) => _menuWords.contains(word))) {
    return true;
  }

  if (words.length <= 2 && lower.length < 20) {
    return true;
  }

  return false;
}

String _extractNodeText(Element node, {String? baseUrl}) {
  final buffer = StringBuffer();

  void walk(Node current) {
    if (current is Text) {
      buffer.write(current.text);
      return;
    }

    if (current is! Element) {
      return;
    }

    if (current.localName == 'br') {
      buffer.write('\n');
      return;
    }

    if (current.localName == 'a') {
      final anchorText = _normalizeWhitespace(current.text);
      final href = current.attributes['href']?.trim();
      final resolved = _resolveHref(href, baseUrl: baseUrl);

      if (resolved != null && resolved.isNotEmpty) {
        if (anchorText.isEmpty) {
          return;
        }

        final label = anchorText;
        buffer.write('[$label]($resolved)');
      } else if (anchorText.isNotEmpty) {
        buffer.write(anchorText);
      }
      return;
    }

    for (final child in current.nodes) {
      walk(child);
    }

    if (current.localName == 'p' ||
        current.localName == 'div' ||
        current.localName == 'li' ||
        current.localName == 'blockquote') {
      buffer.write(' ');
    }
  }

  walk(node);
  return buffer.toString();
}

String? _resolveHref(String? href, {String? baseUrl}) {
  if (href == null || href.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(href);
  if (uri == null) {
    return null;
  }

  if (uri.hasScheme) {
    return _cleanResolvedUrl(uri).toString();
  }

  final base = baseUrl == null ? null : Uri.tryParse(baseUrl);
  if (base == null) {
    return href;
  }

  return _cleanResolvedUrl(base.resolveUri(uri)).toString();
}

Uri _cleanResolvedUrl(Uri uri) {
  final retainedQuery = <String, String>{};
  uri.queryParameters.forEach((key, value) {
    final lower = key.toLowerCase();
    if (lower.startsWith('utm_') ||
        lower == 'fbclid' ||
        lower == 'gclid' ||
        lower == 'ref' ||
        lower == 'source' ||
        lower == 'igshid' ||
        lower == 'mc_cid' ||
        lower == 'mc_eid' ||
        lower == 'tag') {
      return;
    }
    retainedQuery[key] = value;
  });

  return uri.replace(
    queryParameters: retainedQuery.isEmpty ? null : retainedQuery,
  );
}

String? _sanitizeExtractedBlock(String text) {
  final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty) {
    return null;
  }

  if (_isBoilerplateLine(cleaned)) {
    return null;
  }

  if (RegExp(r'^\[[^\]]+\]\(https?://[^\s)]+\)$').hasMatch(cleaned)) {
    return null;
  }

  if (RegExp(r'^(www\.|https?://)', caseSensitive: false).hasMatch(cleaned)) {
    return null;
  }

  // "— Published ... — URL —" style footer metadata.
  final dashStripped = cleaned
      .replaceAll(RegExp(r'[\u2014\u2013\-]+'), '')
      .trim()
      .toLowerCase();
  if (dashStripped.startsWith('published') &&
      RegExp(r'https?://', caseSensitive: false).hasMatch(cleaned)) {
    return null;
  }

  return cleaned;
}

bool _isBylineLine(String text) {
  final lower = text.toLowerCase();
  return lower.startsWith('by ') || lower.startsWith('by:');
}

String _normalizeHeadingCandidate(String input) {
  return input.replaceAll(RegExp(r'^#+\s*'), '').trim();
}

bool _isLikelyLinkFarm(Element node) {
  final totalText = _normalizeWhitespace(node.text);
  if (totalText.length < 70) {
    return false;
  }

  final anchors = node.querySelectorAll('a');
  if (anchors.isEmpty) {
    return false;
  }

  final linkTextLength = anchors.fold<int>(
    0,
    (sum, anchor) => sum + _normalizeWhitespace(anchor.text).length,
  );
  final ratio = linkTextLength / totalText.length;
  return ratio > 0.72;
}
