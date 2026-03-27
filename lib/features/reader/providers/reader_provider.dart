import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader/core/database/app_database.dart';
import 'package:reader/core/database/database_provider.dart';
import 'package:reader/core/models/app_settings.dart';
import 'package:reader/core/utils/html_cleaner.dart';
import 'package:reader/features/settings/providers/settings_provider.dart';

final _rxHeadingRepair = RegExp(r'(?<!\n)\s##\s+');
final _rxQuoteRepair = RegExp(r'(?<!\n)\s>\s+');
final _rxDoubleNewline = RegExp(r'\n{2,}');
final _rxNonAlphanumeric = RegExp(r'[^a-z0-9]+');
final _rxSeparator = RegExp(r'^[\-\u2013\u2014\s]{1,4}$');
final _rxHttpOrWww = RegExp(r'^(https?://|www\.)', caseSensitive: false);
final _rxMarkdownLink = RegExp(r'^\[[^\]]+\]\(https?://[^\s)]+\)$');
final _rxDashes = RegExp(r'[\u2014\u2013\-]+');
final _rxHttpOnly = RegExp(r'https?://', caseSensitive: false);
final _rxBulletPoint = RegExp(r'^[•●▪◦]\s+');
final _rxWhitespace = RegExp(r'\s+');

final readerFontScaleProvider = Provider<double>((ref) {
  return ref.watch(appSettingsProvider).readerFontScale;
});

final readerFontFamilyProvider = Provider<ReaderFontFamily>((ref) {
  return ref.watch(appSettingsProvider).readerFontFamily;
});

final readerTextAlignmentProvider = Provider<ReaderTextAlignment>((ref) {
  return ref.watch(appSettingsProvider).readerTextAlignment;
});

enum ReaderParagraphKind { heading, quote, listItem, body }

class ReaderParagraph {
  const ReaderParagraph({required this.kind, required this.text});

  final ReaderParagraphKind kind;
  final String text;
}

class ReaderPreparedContent {
  const ReaderPreparedContent({
    required this.plainText,
    required this.paragraphs,
  });

  final String plainText;
  final List<ReaderParagraph> paragraphs;
}

final readerPreparedContentProvider =
    FutureProvider.family<ReaderPreparedContent, Article>((ref, article) async {
      final content = article.content.isEmpty
          ? (article.description ?? article.title)
          : article.content;

      final result = await compute(_prepareReaderContentInBackground, {
        'content': content,
        'title': article.title,
      });

      final paragraphsRaw = result['paragraphs'] as List<dynamic>? ?? const [];
      final paragraphs = paragraphsRaw
          .whereType<Map<dynamic, dynamic>>()
          .map((item) {
            final kindName = item['kind'] as String? ?? 'body';
            final text = (item['text'] as String? ?? '').trim();
            return ReaderParagraph(
              kind: _paragraphKindFromName(kindName),
              text: text,
            );
          })
          .where((paragraph) => paragraph.text.isNotEmpty)
          .toList(growable: false);

      return ReaderPreparedContent(
        plainText: result['plainText'] as String? ?? '',
        paragraphs: paragraphs,
      );
    });

Map<String, Object> _prepareReaderContentInBackground(
  Map<String, String> data,
) {
  final content = (data['content'] ?? '').trim();
  final title = (data['title'] ?? '').trim();

  final plainText = content.contains('<') ? htmlToPlainText(content) : content;
  final paragraphs = _extractParagraphsForReader(plainText, title)
      .map(
        (paragraph) => {
          'kind': _paragraphKindName(paragraph.kind),
          'text': paragraph.text,
        },
      )
      .toList(growable: false);

  return {'plainText': plainText, 'paragraphs': paragraphs};
}

List<ReaderParagraph> _extractParagraphsForReader(
  String plainText,
  String title,
) {
  final repaired = plainText
      .replaceAll(_rxHeadingRepair, '\n\n## ')
      .replaceAll(_rxQuoteRepair, '\n\n> ');

  final blocks = repaired
      .split(_rxDoubleNewline)
      .map(
        (p) => p
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .join('\n')
            .trim(),
      )
      .where((p) => p.isNotEmpty)
      .toList(growable: false);

  if (blocks.isEmpty) {
    return const [];
  }

  final titleNormalized = title
      .toLowerCase()
      .replaceAll(_rxNonAlphanumeric, ' ')
      .trim();

  return blocks
      .where((block) {
        if (_rxSeparator.hasMatch(block)) {
          return false;
        }

        if (_rxHttpOrWww.hasMatch(block)) {
          return false;
        }

        if (_rxMarkdownLink.hasMatch(block)) {
          return false;
        }

        final lower = block.toLowerCase();
        if (lower.startsWith('by ') || lower.startsWith('published ')) {
          return false;
        }

        final stripped = block
            .replaceAll(_rxDashes, '')
            .trim()
            .toLowerCase();
        if (stripped.startsWith('published') &&
            _rxHttpOnly.hasMatch(block)) {
          return false;
        }

        final blockNormalized =
            (block.startsWith('## ') ? block.substring(3) : block)
                .toLowerCase()
                .replaceAll(_rxNonAlphanumeric, ' ')
                .trim();
        if (blockNormalized == titleNormalized) {
          return false;
        }

        return true;
      })
      .map(_parseReaderParagraph)
      .toList(growable: false);
}

ReaderParagraph _parseReaderParagraph(String input) {
  final normalizedInput = input.trimLeft();

  if (normalizedInput.startsWith('## ')) {
    return ReaderParagraph(
      kind: ReaderParagraphKind.heading,
      text: normalizedInput.substring(3).trim(),
    );
  }

  if (normalizedInput.startsWith('> ')) {
    return ReaderParagraph(
      kind: ReaderParagraphKind.quote,
      text: normalizedInput.substring(2).trim(),
    );
  }

  if (normalizedInput.startsWith('- ')) {
    return ReaderParagraph(
      kind: ReaderParagraphKind.listItem,
      text: normalizedInput.substring(2).trim(),
    );
  }

  final bulletMatch = _rxBulletPoint.firstMatch(normalizedInput);
  if (bulletMatch != null) {
    return ReaderParagraph(
      kind: ReaderParagraphKind.listItem,
      text: normalizedInput.substring(bulletMatch.end).trim(),
    );
  }

  return ReaderParagraph(kind: ReaderParagraphKind.body, text: normalizedInput);
}

String _paragraphKindName(ReaderParagraphKind kind) {
  return switch (kind) {
    ReaderParagraphKind.heading => 'heading',
    ReaderParagraphKind.quote => 'quote',
    ReaderParagraphKind.listItem => 'listItem',
    ReaderParagraphKind.body => 'body',
  };
}

ReaderParagraphKind _paragraphKindFromName(String name) {
  return switch (name) {
    'heading' => ReaderParagraphKind.heading,
    'quote' => ReaderParagraphKind.quote,
    'listItem' => ReaderParagraphKind.listItem,
    _ => ReaderParagraphKind.body,
  };
}

final articleHighlightsProvider = StreamProvider.family<List<Highlight>, int>((
  ref,
  articleId,
) {
  return ref.watch(appDatabaseProvider).watchHighlightsForArticle(articleId);
});

final allHighlightsProvider = StreamProvider<List<ReaderHighlight>>((ref) {
  return ref.watch(appDatabaseProvider).watchAllHighlights();
});

final articleTagsProvider = StreamProvider.family<List<String>, int>((
  ref,
  articleId,
) {
  return ref.watch(appDatabaseProvider).watchTagsForArticle(articleId);
});

final tagSuggestionsProvider = StreamProvider<List<String>>((ref) {
  return ref.watch(appDatabaseProvider).watchTagSuggestions();
});

final readerActionsProvider = Provider<ReaderActions>((ref) {
  return ReaderActions(ref);
});

enum HighlightSaveResult { saved, emptySelection }

class ReaderActions {
  ReaderActions(this._ref);

  final Ref _ref;

  AppDatabase get _db => _ref.read(appDatabaseProvider);

  Future<HighlightSaveResult> saveHighlight({
    required int articleId,
    required String text,
  }) async {
    final normalized = text.replaceAll(_rxWhitespace, ' ').trim();
    if (normalized.length < 6) {
      return HighlightSaveResult.emptySelection;
    }

    await _db.addHighlight(articleId: articleId, text: normalized);
    return HighlightSaveResult.saved;
  }

  Future<void> deleteHighlight(int highlightId) {
    return _db.deleteHighlight(highlightId);
  }

  Future<void> addTag({required int articleId, required String tag}) {
    return _db.addTagToArticle(articleId: articleId, tag: tag);
  }

  Future<void> removeTag({required int articleId, required String tag}) {
    return _db.removeTagFromArticle(articleId: articleId, tag: tag);
  }
}
