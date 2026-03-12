import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ngpocket/core/database/app_database.dart';
import 'package:ngpocket/core/database/database_provider.dart';

enum LibraryFilter { all, unread, read }

final libraryFilterProvider = StateProvider<LibraryFilter>(
  (_) => LibraryFilter.all,
);

final savedArticlesProvider = StreamProvider<List<Article>>((ref) {
  final filter = ref.watch(libraryFilterProvider);

  return ref.watch(appDatabaseProvider).watchSavedArticles().map((articles) {
    switch (filter) {
      case LibraryFilter.unread:
        return articles
            .where((article) => !article.read)
            .toList(growable: false);
      case LibraryFilter.read:
        return articles
            .where((article) => article.read)
            .toList(growable: false);
      case LibraryFilter.all:
        return articles;
    }
  });
});

final libraryActionsProvider = Provider<LibraryActions>(
  (ref) => LibraryActions(ref),
);

class LibraryActions {
  LibraryActions(this._ref);

  final Ref _ref;

  AppDatabase get _db => _ref.read(appDatabaseProvider);

  Future<void> deleteArticle(int articleId, {bool removeHighlights = true}) {
    return _db.deleteArticle(articleId, deleteHighlights: removeHighlights);
  }

  Future<void> removeFromLibrary(int articleId) {
    return _db.markSaved(articleId, false);
  }

  Future<void> toggleSaved(Article article) {
    return _db.markSaved(article.id, !article.saved);
  }

  Future<void> toggleRead(Article article) {
    return _db.markRead(article.id, !article.read);
  }

  Future<void> markUnread(int articleId) {
    return _db.markRead(articleId, false);
  }
}
