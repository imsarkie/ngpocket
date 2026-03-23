import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ngpocket/features/rss/presentation/add_feed_screen.dart';
import 'package:ngpocket/features/rss/presentation/feed_articles_screen.dart';
import 'package:ngpocket/features/rss/providers/rss_provider.dart';
import 'package:ngpocket/widgets/loading_skeleton.dart';

class RSSSourcesScreen extends ConsumerWidget {
  const RSSSourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedsAsync = ref.watch(feedsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feeds'),
        actions: [
          IconButton(
            tooltip: 'Add feed',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AddFeedScreen()));
            },
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF0B1318), Color(0xFF0E1C25)]
                : const [Color(0xFFFFFCF5), Color(0xFFF2EEE5)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = _RssLayoutMetrics.from(
              constraints: constraints,
              mediaQuery: MediaQuery.of(context),
            );

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: metrics.maxContentWidth),
                child: RefreshIndicator(
                  onRefresh: () => ref.read(rssActionsProvider).refreshAll(),
                  child: feedsAsync.when(
                    data: (feeds) {
                      if (feeds.isEmpty) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: metrics.listPadding,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight * 0.56,
                              ),
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.all(
                                    metrics.horizontalInset,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.rss_feed_rounded,
                                        size: 54,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      SizedBox(height: metrics.itemGap * 1.6),
                                      Text(
                                        'No feeds yet',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      SizedBox(height: metrics.itemGap * 0.8),
                                      Text(
                                        'Add your first source to build your feed reader.',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                      SizedBox(height: metrics.itemGap * 1.6),
                                      FilledButton.tonalIcon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const AddFeedScreen(),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.add),
                                        label: const Text('Add Source'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      return ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: metrics.listPadding,
                        itemCount: feeds.length,
                        separatorBuilder: (_, index) =>
                            SizedBox(height: metrics.itemGap),
                        itemBuilder: (context, index) {
                          final feed = feeds[index];
                          final updatedLabel = feed.lastUpdated == null
                              ? 'Not refreshed yet'
                              : 'Updated ${DateFormat.yMMMd().add_Hm().format(feed.lastUpdated!.toLocal())}';

                          return Material(
                            color: isDark
                                ? colorScheme.surfaceContainerLow
                                : colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            elevation: isDark ? 0 : 2,
                            shadowColor: Colors.black.withValues(alpha: 0.08),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        FeedArticlesScreen(feed: feed),
                                  ),
                                );
                              },
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: metrics.cardHorizontalPadding,
                                  vertical: metrics.cardVerticalPadding,
                                ),
                                leading: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: colorScheme.primaryContainer,
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  child: Icon(
                                    Icons.rss_feed_rounded,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                title: Text(
                                  feed.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        feed.rssUrl,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                      Text(
                                        updatedLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'refresh') {
                                      await ref
                                          .read(rssActionsProvider)
                                          .refreshFeed(feed);
                                    }
                                    if (value == 'remove') {
                                      await ref
                                          .read(rssActionsProvider)
                                          .removeFeed(feed.id);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'refresh',
                                      child: Text('Refresh'),
                                    ),
                                    PopupMenuItem(
                                      value: 'remove',
                                      child: Text('Remove source'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: metrics.listPadding,
                      itemCount: 6,
                      itemBuilder: (_, index) => const ListItemSkeleton(),
                    ),
                    error: (error, stackTrace) => ListView(
                      padding: metrics.listPadding,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight * 0.56,
                          ),
                          child: Center(
                            child: Text(
                              'Unable to load feeds.\n$error',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RssLayoutMetrics {
  const _RssLayoutMetrics({
    required this.horizontalInset,
    required this.topInset,
    required this.bottomInset,
    required this.maxContentWidth,
    required this.itemGap,
    required this.cardHorizontalPadding,
    required this.cardVerticalPadding,
  });

  final double horizontalInset;
  final double topInset;
  final double bottomInset;
  final double maxContentWidth;
  final double itemGap;
  final double cardHorizontalPadding;
  final double cardVerticalPadding;

  EdgeInsets get listPadding => EdgeInsets.fromLTRB(
    horizontalInset,
    topInset,
    horizontalInset,
    bottomInset,
  );

  factory _RssLayoutMetrics.from({
    required BoxConstraints constraints,
    required MediaQueryData mediaQuery,
  }) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final shortest = mediaQuery.size.shortestSide;

    final horizontalInset = width * 0.04;
    final topInset = height * 0.014;
    final bottomInset = mediaQuery.padding.bottom + (height * 0.02);
    final itemGap = shortest * 0.02;

    return _RssLayoutMetrics(
      horizontalInset: horizontalInset,
      topInset: topInset,
      bottomInset: bottomInset,
      maxContentWidth: width,
      itemGap: itemGap,
      cardHorizontalPadding: width * 0.04,
      cardVerticalPadding: height * 0.014,
    );
  }
}
