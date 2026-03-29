import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader/core/database/app_database.dart';
import 'package:reader/core/services/service_providers.dart';
import 'package:reader/core/theme/app_theme.dart';
import 'package:reader/features/feed/providers/feed_provider.dart';
import 'package:reader/features/rss/presentation/rss_sources_screen.dart';
import 'package:reader/features/rss/providers/rss_provider.dart';
import 'package:reader/widgets/loading_skeleton.dart';

import 'package:reader/widgets/article_list_row.dart';


class ReadInboxScreen extends ConsumerStatefulWidget {
  const ReadInboxScreen({super.key});

  @override
  ConsumerState<ReadInboxScreen> createState() => _ReadInboxScreenState();
}

class _ReadInboxScreenState extends ConsumerState<ReadInboxScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final filter = ref.watch(feedFilterProvider);
    final inboxAsync = ref.watch(filteredInboxArticlesProvider);
    final foldersAsync = ref.watch(foldersWithFeedsProvider);

    // Derive AppBar title from active filter
    final title = switch (filter) {
      FeedFilterAll() => 'Read',
      FeedFilterFolder(:final folderName) => folderName,
      FeedFilterSource(:final sourceName) => sourceName,
    };

    return Scaffold(
      appBar: AppBar(
        leading: filter is! FeedFilterAll
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => ref
                    .read(feedFilterProvider.notifier)
                    .state = const FeedFilterAll(),
              )
            : null,
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Manage feeds',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RSSSourcesScreen()),
            ),
            icon: const Icon(Icons.rss_feed_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Folder / Source chip bar ─────────────────────────────────────
          _FolderChipBar(foldersAsync: foldersAsync, filter: filter),

          // ── Article list ─────────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.clay,
              onRefresh: () => ref.read(rssActionsProvider).refreshAll(),
              child: inboxAsync.when(
                data: (articles) => articles.isEmpty
                    ? _buildEmpty(context, filter)
                    : _buildList(context, ref, articles),
                loading: () => ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: 8,
                  itemBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: ListItemSkeleton(),
                  ),
                ),
                error: (e, _) => Center(
                  child: Text('Unable to load articles.\n$e',
                      textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Article list
  // ---------------------------------------------------------------------------

  Widget _buildList(
      BuildContext context, WidgetRef ref, List<Article> articles) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: articles.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
      ),
      itemBuilder: (context, index) {
        final article = articles[index];

        return ArticleListRow(
          article: article,
          trailing: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Icon(
              article.saved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded,
              size: 20,
              color: article.saved
                  ? AppTheme.clay
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () {
              final haptics = ref.read(hapticServiceProvider);
              haptics.medium();
              unawaited(haptics.success());
              unawaited(
                ref
                    .read(feedActionsProvider)
                    .saveArticle(article.id, !article.saved),
              );
            },
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  Widget _buildEmpty(BuildContext context, FeedFilter filter) {
    final label = switch (filter) {
      FeedFilterAll() => 'No stories yet',
      FeedFilterFolder(:final folderName) => 'Nothing in $folderName',
      FeedFilterSource(:final sourceName) => 'Nothing from $sourceName',
    };
    final sub = switch (filter) {
      FeedFilterAll() => 'Add RSS feeds to build your reading inbox.',
      FeedFilterFolder() => 'No articles from these sources yet.',
      FeedFilterSource() => 'No articles from this source yet.',
    };

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.14),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppTheme.clay.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.rss_feed_rounded,
                          size: 26, color: AppTheme.clay),
                    ),
                    const SizedBox(height: 14),
                    Text(label,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(sub,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            )),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Horizontal scrollable folder/source chip bar
// ---------------------------------------------------------------------------

class _FolderChipBar extends ConsumerWidget {
  const _FolderChipBar({
    required this.foldersAsync,
    required this.filter,
  });

  final AsyncValue<FoldersWithFeedsState> foldersAsync;
  final FeedFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return foldersAsync.when(
      // Only render chips when data is ready AND there is something to show.
      data: (state) {
        final hasChips =
            state.folders.isNotEmpty || state.uncategorised.isNotEmpty;
        if (!hasChips) return const SizedBox.shrink();

        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  children: [
                    // "All" chip
                    _Chip(
                      label: 'All',
                      icon: null,
                      selected: filter is FeedFilterAll,
                      onTap: () => ref
                          .read(feedFilterProvider.notifier)
                          .state = const FeedFilterAll(),
                    ),

                    // Folder chips
                    for (final fwf in state.folders)
                      _Chip(
                        label: fwf.folder.name,
                        icon: Icons.folder_rounded,
                        selected: filter is FeedFilterFolder &&
                            (filter as FeedFilterFolder).folderId ==
                                fwf.folder.id,
                        onTap: () => ref
                            .read(feedFilterProvider.notifier)
                            .state = FeedFilterFolder(
                          fwf.folder.id,
                          fwf.folder.name,
                        ),
                      ),

                    // Uncategorised source chips
                    for (final feed in state.uncategorised)
                      _Chip(
                        label: feed.name,
                        icon: null,
                        dotColor: getDotColorForSource(feed.name),
                        selected: filter is FeedFilterSource &&
                            (filter as FeedFilterSource).sourceName ==
                                feed.name,
                        onTap: () => ref
                            .read(feedFilterProvider.notifier)
                            .state = FeedFilterSource(feed.name),
                      ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.5),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual chip widget
// ---------------------------------------------------------------------------

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.dotColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.clay
                : AppTheme.clay.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Folder icon OR source dot
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: selected
                      ? Colors.white
                      : AppTheme.clay.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 5),
              ] else if (dotColor != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.9)
                        : dotColor!.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
