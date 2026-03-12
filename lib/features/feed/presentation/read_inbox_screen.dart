import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ngpocket/core/services/service_providers.dart';
import 'package:ngpocket/features/feed/providers/feed_provider.dart';
import 'package:ngpocket/features/reader/presentation/reader_screen.dart';
import 'package:ngpocket/features/rss/presentation/rss_sources_screen.dart';
import 'package:ngpocket/widgets/loading_skeleton.dart';

class ReadInboxScreen extends ConsumerWidget {
  const ReadInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxAsync = ref.watch(inboxArticlesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Read'),
        actions: [
          IconButton(
            tooltip: 'Feeds',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RSSSourcesScreen()),
              );
            },
            icon: const Icon(Icons.rss_feed_rounded),
          ),
        ],
      ),
      body: inboxAsync.when(
        data: (articles) {
          if (articles.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 26,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.rss_feed_rounded,
                          size: 44,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No stories yet',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add RSS feeds to build your reading inbox.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: articles.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final article = articles[index];

              return Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  onTap: () {
                    ref.read(hapticServiceProvider).selection();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReaderScreen(article: article),
                      ),
                    );
                  },
                  title: Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        if (!article.read)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            '${article.source ?? 'Web'} • ${article.readingTime} min • ${DateFormat.yMMMd().format(article.createdAt.toLocal())}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      article.saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
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
                ),
              );
            },
          );
        },
        loading: () => ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: 8,
          itemBuilder: (context, index) => const ListItemSkeleton(),
        ),
        error: (error, stackTrace) => Center(
          child: Text(
            'Unable to load reading queue.\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
