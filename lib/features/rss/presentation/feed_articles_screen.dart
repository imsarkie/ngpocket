import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ngpocket/core/database/app_database.dart';
import 'package:ngpocket/features/rss/providers/rss_provider.dart';
import 'package:ngpocket/widgets/loading_skeleton.dart';

class FeedArticlesScreen extends ConsumerWidget {
  const FeedArticlesScreen({super.key, required this.feed});

  final Feed feed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articlesAsync = ref.watch(feedArticlesProvider(feed));

    return Scaffold(
      appBar: AppBar(title: Text(feed.name)),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(rssActionsProvider).refreshFeed(feed);
          ref.invalidate(feedArticlesProvider(feed));
        },
        child: articlesAsync.when(
          data: (articles) {
            if (articles.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: const Center(
                      child: Text('No articles available yet.'),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: articles.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final article = articles[index];
                final publishDate = article.publishedAt;

                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 16,
                        color: Color(0x14000000),
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (article.description.isNotEmpty)
                            Text(
                              article.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 6),
                          Text(
                            publishDate == null
                                ? 'Publication date unavailable'
                                : DateFormat.yMMMd().add_Hm().format(
                                    publishDate.toLocal(),
                                  ),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    trailing: IconButton.filledTonal(
                      tooltip: 'Download article',
                      onPressed: () async {
                        await ref
                            .read(rssActionsProvider)
                            .downloadArticle(article);
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Added "${article.title}" to your reading queue.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download_rounded),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: 8,
            itemBuilder: (context, index) => const ListItemSkeleton(),
          ),
          error: (error, stackTrace) => ListView(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: Text(
                    'Unable to load feed items.\n$error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
