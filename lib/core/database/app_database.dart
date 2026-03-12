import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

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
  });

  final Highlight highlight;
  final String articleTitle;
  final String articleUrl;
}

@DriftDatabase(tables: [Articles, Feeds, Highlights, ArticleTags])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
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
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await customStatement(_ensureHighlightsTableSql);
      await customStatement(_ensureArticleTagsTableSql);
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
    final normalized = tag.replaceAll(RegExp(r'\s+'), ' ').trim();
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

  Future<void> upsertFeedPreview({
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
      return;
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
    final file = File(p.join(dbDir.path, 'ngpocket.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
