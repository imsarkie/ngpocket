import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ngpocket/core/database/app_database.dart';
import 'package:ngpocket/core/database/database_provider.dart';
import 'package:ngpocket/features/settings/providers/settings_provider.dart';

final readerFontScaleProvider = Provider<double>((ref) {
  return ref.watch(appSettingsProvider).readerFontScale;
});

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
