import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:reader/core/database/app_database.dart';
import 'package:reader/core/services/service_providers.dart';
import 'package:reader/features/library/providers/library_provider.dart';
import 'package:reader/widgets/article_list_row.dart';
import 'package:reader/widgets/loading_skeleton.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  @override
  Widget build(BuildContext context) {
    final articlesAsync = ref.watch(savedArticlesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(savedArticlesProvider),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Column(
          children: [
            Expanded(
              child: articlesAsync.when(
                data: (articles) {
                  if (articles.isEmpty) {
                    return Center(
                      child: Text(
                        'No saved articles yet.\nSwipe right on cards to save them.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(savedArticlesProvider),
                    child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: articles.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                    itemBuilder: (context, index) {
                      final article = articles[index];
                      var deleteWithHighlights = true;

                      return Dismissible(
                        key: ValueKey(article.id),
                        direction: DismissDirection.horizontal,
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.startToEnd) {
                            await ref.read(hapticServiceProvider).selection();
                            await ref
                                .read(libraryActionsProvider)
                                .markUnread(article.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Marked as unread.'),
                                ),
                              );
                            }
                            return false;
                          }

                          final choice = await _showRemoveArticleDialog(
                            context,
                          );
                          if (choice == _ArticleRemovalChoice.cancel ||
                              !context.mounted) {
                            return false;
                          }

                          if (choice == _ArticleRemovalChoice.removeOnly) {
                            ref.read(hapticServiceProvider).selection();
                            await ref
                                .read(libraryActionsProvider)
                                .removeFromLibrary(article.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Removed from library. Highlights retained.',
                                  ),
                                ),
                              );
                            }
                            return false;
                          }

                          deleteWithHighlights = true;
                          return true;
                        },
                        secondaryBackground: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          child: Icon(
                            Icons.mark_email_unread_rounded,
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                        ),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                        onDismissed: (_) {
                          ref.read(hapticServiceProvider).light();
                          ref
                              .read(libraryActionsProvider)
                              .deleteArticle(
                                article.id,
                                removeHighlights: deleteWithHighlights,
                              );
                        },
                        child: GestureDetector(
                          onLongPress: () {
                            ref.read(hapticServiceProvider).medium();
                            _showArticleContextMenu(context, ref, article);
                          },
                          child: ArticleListRow(article: article),
                        ),
                      );
                    },
                  ),
                );  // RefreshIndicator
                },
                loading: () => ListView.separated(
                  itemCount: 7,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) => const ListItemSkeleton(),
                ),
                error: (error, stackTrace) => Center(
                  child: Text(
                    'Unable to load library.\n$error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ArticleRemovalChoice { removeOnly, removeWithHighlights, cancel }

void _showArticleContextMenu(
    BuildContext context, WidgetRef ref, Article article) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ArticleContextSheet(
      article: article,
      ref: ref,
    ),
  );
}

Future<_ArticleRemovalChoice> _showRemoveArticleDialog(
  BuildContext context,
) async {
  final choice = await showDialog<_ArticleRemovalChoice>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Remove article?'),
        content: const Text('Remove the highlight too?'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_ArticleRemovalChoice.removeOnly),
            child: const Text('No, retain highlights'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_ArticleRemovalChoice.cancel),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(
              context,
            ).pop(_ArticleRemovalChoice.removeWithHighlights),
            child: const Text('Yes, remove all'),
          ),
        ],
      );
    },
  );

  return choice ?? _ArticleRemovalChoice.cancel;
}

// ---------------------------------------------------------------------------
// Long-press context sheet
// ---------------------------------------------------------------------------

class _ArticleContextSheet extends StatelessWidget {
  const _ArticleContextSheet({required this.article, required this.ref});

  final Article article;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              article.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.share_rounded),
            title: const Text('Share'),
            onTap: () {
              Navigator.of(context).pop();
              Share.share(
                article.url,
                subject: article.title,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent),
            title: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              Navigator.of(context).pop();
              final choice = await _showRemoveArticleDialog(context);
              if (choice == _ArticleRemovalChoice.cancel) return;
              if (choice == _ArticleRemovalChoice.removeOnly) {
                ref.read(hapticServiceProvider).selection();
                await ref
                    .read(libraryActionsProvider)
                    .removeFromLibrary(article.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Removed from library. Highlights retained.'),
                    ),
                  );
                }
              } else {
                ref.read(hapticServiceProvider).light();
                await ref
                    .read(libraryActionsProvider)
                    .deleteArticle(article.id, removeHighlights: true);
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
