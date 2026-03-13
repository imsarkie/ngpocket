import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ngpocket/core/database/app_database.dart';
import 'package:ngpocket/core/database/database_provider.dart';
import 'package:ngpocket/core/models/app_settings.dart';
import 'package:ngpocket/core/utils/html_cleaner.dart';
import 'package:ngpocket/features/settings/providers/settings_provider.dart';

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
      .replaceAll(RegExp(r'(?<!\n)\s##\s+'), '\n\n## ')
      .replaceAll(RegExp(r'(?<!\n)\s>\s+'), '\n\n> ');

  final blocks = repaired
      .split(RegExp(r'\n{2,}'))
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
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  return blocks
      .where((block) {
        if (RegExp(r'^[\-\u2013\u2014\s]{1,4}$').hasMatch(block)) {
          return false;
        }

        if (RegExp(
          r'^(https?://|www\.)',
          caseSensitive: false,
        ).hasMatch(block)) {
          return false;
        }

        if (RegExp(r'^\[[^\]]+\]\(https?://[^\s)]+\)$').hasMatch(block)) {
          return false;
        }

        final lower = block.toLowerCase();
        if (lower.startsWith('by ') || lower.startsWith('published ')) {
          return false;
        }

        final stripped = block
            .replaceAll(RegExp(r'[\u2014\u2013\-]+'), '')
            .trim()
            .toLowerCase();
        if (stripped.startsWith('published') &&
            RegExp(r'https?://', caseSensitive: false).hasMatch(block)) {
          return false;
        }

        final blockNormalized =
            (block.startsWith('## ') ? block.substring(3) : block)
                .toLowerCase()
                .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
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

  final bulletMatch = RegExp(r'^[•●▪◦]\s+').firstMatch(normalizedInput);
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
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
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
