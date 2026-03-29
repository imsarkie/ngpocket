import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

final _rxWhitespace = RegExp(r'\s+');

class Articles extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text()();

  TextColumn get url => text().unique()();

  TextColumn get content => text().withDefault(const Constant(''))();

  TextColumn get description => text().nullable()();

  TextColumn get image => text().nullable()();

  TextColumn get source => text().nullable()();

  TextColumn get author => text().nullable()();

  IntColumn get readingTime => integer().withDefault(const Constant(3))();

  BoolColumn get saved => boolean().withDefault(const Constant(false))();

  BoolColumn get read => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get publishedAt => dateTime().nullable()();
}

class Feeds extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get rssUrl => text().unique()();

  /// Nullable FK to feed_folders — null means "Uncategorised".
  IntColumn get folderId => integer().nullable()();

  DateTimeColumn get lastUpdated => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Highlights extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get articleId => integer().references(Articles, #id)();

  TextColumn get snippet => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class ArticleTags extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get articleId => integer().references(Articles, #id)();

  TextColumn get tag => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {articleId, tag},
  ];
}

class ReaderHighlight {
  const ReaderHighlight({
    required this.highlight,
    required this.articleTitle,
    required this.articleUrl,
    this.articleAuthor,
    this.articleSource,
    this.articleImage,
  });

  final Highlight highlight;
  final String articleTitle;
  final String articleUrl;
  final String? articleAuthor;
  final String? articleSource;
  final String? articleImage;
}

@DriftDatabase(tables: [Articles, Feeds, Highlights, ArticleTags])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Broadcast bus notified by every folder mutation so [watchFolders]
  /// can re-query the raw `feed_folders` table reactively.
  final _folderBus = StreamController<void>.broadcast();

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await customStatement(_ensureFeedFoldersTableSql);
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(highlights);
      }

      if (from < 3) {
        await customStatement(_ensureHighlightsTableSql);
      }

      if (from < 4) {
        await m.createTable(articleTags);
      }

      if (from < 5) {
        // Create feed_folders table.
        await customStatement(_ensureFeedFoldersTableSql);
        // Add folder_id column to feeds (ignore error if already exists).
        try {
          await customStatement(
            'ALTER TABLE feeds ADD COLUMN folder_id INTEGER REFERENCES feed_folders(id) ON DELETE SET NULL;',
          );
        } catch (_) {
          // Column may already exist on fresh installs.
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await customStatement(_ensureHighlightsTableSql);
      await customStatement(_ensureArticleTagsTableSql);
      await customStatement(_ensureFeedFoldersTableSql);
    },
  );

  Stream<List<Article>> watchSwipeQueue() {
    return (select(articles)
          ..where((tbl) => tbl.read.equals(false))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  Stream<List<Article>> watchInboxArticles() {
    return (select(articles)..orderBy([
          (tbl) =>
              OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  /// Filters inbox articles to a single [source] (feed name).
  Stream<List<Article>> watchInboxArticlesBySource(String source) {
    return (select(articles)
          ..where((tbl) => tbl.source.equals(source))
          ..orderBy([
            (tbl) => OrderingTerm(
                  expression: tbl.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Filters inbox articles to all feeds belonging to [folderId].
  /// Uses a Drift typed join so the result is reactive.
  Stream<List<Article>> watchInboxArticlesByFolder(int folderId) {
    final query = select(articles).join([
      innerJoin(feeds, feeds.name.equalsExp(articles.source)),
    ])
      ..where(feeds.folderId.equals(folderId))
      ..orderBy([
        OrderingTerm(expression: articles.createdAt, mode: OrderingMode.desc),
      ]);
    return query
        .watch()
        .map((rows) => rows.map((r) => r.readTable(articles)).toList());
  }


  Stream<List<Article>> watchSavedArticles() {
    return (select(articles)
          ..where((tbl) => tbl.saved.equals(true))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  Stream<int> watchUnreadCount() {
    final countExpression = articles.id.count();
    final query = selectOnly(articles)
      ..addColumns([countExpression])
      ..where(articles.read.equals(false));

    return query.watchSingle().map((row) => row.read(countExpression) ?? 0);
  }

  Stream<List<Feed>> watchFeeds() {
    return (select(feeds)..orderBy([
          (tbl) =>
              OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.asc),
        ]))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // Feed Folders
  // ---------------------------------------------------------------------------

  /// Fetches all folders once (non-reactive).
  Future<List<FolderRow>> fetchFolders() async {
    final rows = await customSelect(
      'SELECT * FROM feed_folders ORDER BY sort_order ASC, created_at ASC',
    ).get();
    return rows
        .map(
          (row) => FolderRow(
            id: row.read<int>('id'),
            name: row.read<String>('name'),
            sortOrder: row.read<int>('sort_order'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('created_at'),
            ),
          ),
        )
        .toList(growable: false);
  }

  /// Reactive stream: emits immediately, then re-emits whenever any folder
  /// mutation calls [_folderBus.add].
  Stream<List<FolderRow>> watchFolders() async* {
    yield await fetchFolders();
    await for (final _ in _folderBus.stream) {
      yield await fetchFolders();
    }
  }

  Future<int> insertFolder(String name) async {
    final maxOrder = await customSelect(
      'SELECT COALESCE(MAX(sort_order), 0) AS m FROM feed_folders',
    ).getSingle().then((r) => r.read<int>('m') + 1);

    await customStatement(
      'INSERT INTO feed_folders (name, sort_order) VALUES (?, ?)',
      [name, maxOrder],
    );

    final result = await customSelect(
      'SELECT last_insert_rowid() AS id',
    ).getSingle();
    final id = result.read<int>('id');
    _folderBus.add(null); // notify watchFolders
    return id;
  }

  Future<void> renameFolder(int id, String newName) async {
    await customStatement(
      'UPDATE feed_folders SET name = ? WHERE id = ?',
      [newName, id],
    );
    _folderBus.add(null);
  }

  Future<void> deleteFolder(int id) async {
    await customStatement(
      'DELETE FROM feed_folders WHERE id = ?',
      [id],
    );
    _folderBus.add(null);
  }

  /// Moves a feed to a folder (or null = uncategorised).
  /// Uses Drift's typed update so [watchFeeds()] picks up the change.
  Future<void> moveFeedToFolder(int feedId, int? folderId) {
    return (update(feeds)..where((tbl) => tbl.id.equals(feedId))).write(
      FeedsCompanion(folderId: Value(folderId)),
    );
  }

  Stream<List<Highlight>> watchHighlightsForArticle(int articleId) {
    return (select(highlights)
          ..where((tbl) => tbl.articleId.equals(articleId))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  Stream<List<ReaderHighlight>> watchAllHighlights() {
    final query =
        select(highlights).join([
          innerJoin(articles, articles.id.equalsExp(highlights.articleId)),
        ])..orderBy([
          OrderingTerm(
            expression: highlights.createdAt,
            mode: OrderingMode.desc,
          ),
        ]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ReaderHighlight(
              highlight: row.readTable(highlights),
              articleTitle: row.readTable(articles).title,
              articleUrl: row.readTable(articles).url,
              articleAuthor: row.readTable(articles).author,
              articleSource: row.readTable(articles).source,
              articleImage: row.readTable(articles).image,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<int> countHighlightsForArticle(int articleId) async {
    final countExpression = highlights.id.count();
    final query = selectOnly(highlights)
      ..addColumns([countExpression])
      ..where(highlights.articleId.equals(articleId));

    final result = await query.getSingle();
    return result.read(countExpression) ?? 0;
  }

  Stream<int> watchHighlightCountForArticle(int articleId) {
    final countExpression = highlights.id.count();
    final query = selectOnly(highlights)
      ..addColumns([countExpression])
      ..where(highlights.articleId.equals(articleId));

    return query.watchSingle().map((row) => row.read(countExpression) ?? 0);
  }

  Future<void> addHighlight({required int articleId, required String text}) {
    return into(
      highlights,
    ).insert(HighlightsCompanion.insert(articleId: articleId, snippet: text));
  }

  Future<void> deleteHighlight(int highlightId) {
    return (delete(
      highlights,
    )..where((tbl) => tbl.id.equals(highlightId))).go();
  }

  Stream<List<Article>> watchArticlesByTag(String tag) {
    final query = select(articles).join([
      innerJoin(articleTags, articleTags.articleId.equalsExp(articles.id)),
    ])
      ..where(articleTags.tag.equals(tag))
      ..orderBy([
        OrderingTerm(expression: articles.createdAt, mode: OrderingMode.desc),
      ]);
    return query
        .watch()
        .map((rows) => rows.map((r) => r.readTable(articles)).toList());
  }

  Stream<List<String>> watchTagsForArticle(int articleId) {
    return (select(articleTags)
          ..where((tbl) => tbl.articleId.equals(articleId))
          ..orderBy([
            (tbl) =>
                OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.asc),
          ]))
        .watch()
        .map((rows) => rows.map((row) => row.tag).toList(growable: false));
  }

  Stream<List<String>> watchTagSuggestions({int limit = 30}) {
    final countExpression = articleTags.id.count();
    final query = selectOnly(articleTags)
      ..addColumns([articleTags.tag, countExpression])
      ..groupBy([articleTags.tag])
      ..orderBy([
        OrderingTerm(expression: countExpression, mode: OrderingMode.desc),
        OrderingTerm(expression: articleTags.tag, mode: OrderingMode.asc),
      ])
      ..limit(limit);

    return query.watch().map(
      (rows) => rows
          .map((row) => row.read(articleTags.tag))
          .whereType<String>()
          .toList(growable: false),
    );
  }

  Future<void> addTagToArticle({required int articleId, required String tag}) {
    final normalized = tag.replaceAll(_rxWhitespace, ' ').trim();
    if (normalized.isEmpty) {
      return Future.value();
    }

    return into(articleTags).insert(
      ArticleTagsCompanion.insert(articleId: articleId, tag: normalized),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> removeTagFromArticle({
    required int articleId,
    required String tag,
  }) {
    return (delete(articleTags)..where(
          (tbl) => tbl.articleId.equals(articleId) & tbl.tag.equals(tag),
        ))
        .go();
  }

  Future<void> deleteTagsForArticle(int articleId) {
    return (delete(
      articleTags,
    )..where((tbl) => tbl.articleId.equals(articleId))).go();
  }

  Future<int> insertFeed(FeedsCompanion companion) {
    return into(feeds).insert(companion, mode: InsertMode.insertOrIgnore);
  }

  Future<void> removeFeed(int id) {
    return (delete(feeds)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// Deletes all articles (plus their highlights and tags) whose [source]
  /// matches [source].  Used when a feed is removed and the user wants to
  /// purge its articles from the inbox / library too.
  Future<void> deleteArticlesBySource(String source) {
    return transaction(() async {
      final ids = await (selectOnly(articles)
            ..addColumns([articles.id])
            ..where(articles.source.equals(source)))
          .map((row) => row.read(articles.id)!)
          .get();

      for (final id in ids) {
        await deleteTagsForArticle(id);
        await (delete(highlights)..where((tbl) => tbl.articleId.equals(id)))
            .go();
      }
      await (delete(articles)..where((tbl) => tbl.source.equals(source))).go();
    });
  }

  Future<void> updateFeedTimestamp(int feedId) {
    return (update(feeds)..where((tbl) => tbl.id.equals(feedId))).write(
      FeedsCompanion(lastUpdated: Value(DateTime.now())),
    );
  }

  Future<Article?> findArticleByUrl(String url) {
    return (select(
      articles,
    )..where((tbl) => tbl.url.equals(url))).getSingleOrNull();
  }

  Future<Article?> findArticleById(int articleId) {
    return (select(
      articles,
    )..where((tbl) => tbl.id.equals(articleId))).getSingleOrNull();
  }

  Future<int> countUnreadSavedArticles() async {
    final countExpression = articles.id.count();
    final query = selectOnly(articles)
      ..addColumns([countExpression])
      ..where(articles.saved.equals(true) & articles.read.equals(false));

    final result = await query.getSingle();
    return result.read(countExpression) ?? 0;
  }

  Future<Article?> findLatestUnreadSavedArticle() {
    return (select(articles)
          ..where((tbl) => tbl.saved.equals(true) & tbl.read.equals(false))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<Article?> findLatestSavedArticle() {
    return (select(articles)
          ..where((tbl) => tbl.saved.equals(true))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.createdAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<bool> upsertFeedPreview({
    required String title,
    required String url,
    required String source,
    required String description,
    required int readingTime,
    String? image,
    DateTime? publishedAt,
  }) async {
    final existing = await findArticleByUrl(url);
    if (existing == null) {
      await into(articles).insert(
        ArticlesCompanion.insert(
          title: title,
          url: url,
          source: Value(source),
          description: Value(description),
          image: Value(image),
          readingTime: Value(readingTime),
          publishedAt: Value(publishedAt),
        ),
      );
      return true;
    }

    await (update(articles)..where((tbl) => tbl.id.equals(existing.id))).write(
      ArticlesCompanion(
        title: Value(title),
        source: Value(source),
        description: Value(description),
        image: Value(image),
        readingTime: Value(readingTime),
        publishedAt: Value(publishedAt),
      ),
    );
    return false;
  }

  /// Inserts a lightweight placeholder so the article appears in the list
  /// immediately while its content is still being fetched.
  /// Skips silently if the URL already exists.
  Future<void> insertPlaceholderArticle(String url) async {
    final existing = await findArticleByUrl(url);
    if (existing != null) return;
    final host =
        Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? '';
    await into(articles).insert(
      ArticlesCompanion.insert(
        title: host.isNotEmpty ? host : url,
        url: url,
        content: const Value(''),
        source: Value(host.isNotEmpty ? host : null),
        saved: const Value(true),
      ),
    );
  }

  Future<void> saveParsedArticle({
    required String title,
    required String url,
    required String content,
    required String description,
    required int readingTime,
    String? image,
    String? source,
    String? author,
    bool markSaved = false,
  }) async {
    final existing = await findArticleByUrl(url);
    if (existing == null) {
      await into(articles).insert(
        ArticlesCompanion.insert(
          title: title,
          url: url,
          content: Value(content),
          description: Value(description),
          image: Value(image),
          source: Value(source),
          author: Value(author),
          readingTime: Value(readingTime),
          saved: Value(markSaved),
        ),
      );
      return;
    }

    await (update(articles)..where((tbl) => tbl.id.equals(existing.id))).write(
      ArticlesCompanion(
        title: Value(title),
        content: Value(content),
        description: Value(description),
        image: Value(image),
        source: Value(source ?? existing.source),
        author: Value(author),
        readingTime: Value(readingTime),
        saved: Value(markSaved || existing.saved),
      ),
    );
  }

  Future<void> markSaved(int articleId, bool isSaved) {
    return (update(articles)..where((tbl) => tbl.id.equals(articleId))).write(
      ArticlesCompanion(saved: Value(isSaved)),
    );
  }

  Future<void> markRead(int articleId, bool isRead) {
    return (update(articles)..where((tbl) => tbl.id.equals(articleId))).write(
      ArticlesCompanion(read: Value(isRead)),
    );
  }

  Future<void> deleteArticle(int articleId, {bool deleteHighlights = true}) {
    return transaction(() async {
      await deleteTagsForArticle(articleId);

      if (deleteHighlights) {
        await (delete(
          highlights,
        )..where((tbl) => tbl.articleId.equals(articleId))).go();
      }

      await (delete(articles)..where((tbl) => tbl.id.equals(articleId))).go();
    });
  }
}

// ---------------------------------------------------------------------------
// Plain data class for folder rows (avoids Drift codegen for the new table).
// ---------------------------------------------------------------------------

class FolderRow {
  const FolderRow({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
  });

  final int id;
  final String name;
  final int sortOrder;
  final DateTime createdAt;
}

const _ensureFeedFoldersTableSql = '''
CREATE TABLE IF NOT EXISTS feed_folders (
  id         INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name       TEXT    NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);
''';

const _ensureHighlightsTableSql = '''
CREATE TABLE IF NOT EXISTS highlights (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  article_id INTEGER NOT NULL,
  snippet TEXT NOT NULL,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
  FOREIGN KEY (article_id) REFERENCES articles (id)
);
''';

const _ensureArticleTagsTableSql = '''
CREATE TABLE IF NOT EXISTS article_tags (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  article_id INTEGER NOT NULL,
  tag TEXT NOT NULL,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
  FOREIGN KEY (article_id) REFERENCES articles (id),
  UNIQUE(article_id, tag)
);
''';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbDir.path, 'reader.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
