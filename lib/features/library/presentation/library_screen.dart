import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ngpocket/core/services/service_providers.dart';
import 'package:ngpocket/features/library/providers/library_provider.dart';
import 'package:ngpocket/features/reader/presentation/reader_screen.dart';
import 'package:ngpocket/widgets/loading_skeleton.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(libraryFilterProvider);
    final articlesAsync = ref.watch(savedArticlesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          children: [
            _LibraryFilterControl(
              filter: filter,
              onChanged: (value) {
                ref.read(hapticServiceProvider).selection();
                ref.read(libraryFilterProvider.notifier).state = value;
              },
            ),
            const SizedBox(height: 12),
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

                  return ListView.separated(
                    itemCount: articles.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
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
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.mark_email_unread_rounded,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                          ),
                        ),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
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
                        child: Material(
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
                                  builder: (_) =>
                                      ReaderScreen(article: article),
                                ),
                              );
                            },
                            title: Text(
                              article.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  _MetaPill(label: article.source ?? 'Web'),
                                  _MetaPill(
                                    label: '${article.readingTime} min',
                                  ),
                                  _MetaPill(
                                    label: article.read ? 'Read' : 'Unread',
                                  ),
                                ],
                              ),
                            ),
                            trailing: IconButton(
                              onPressed: () async {
                                final choice = await _showRemoveArticleDialog(
                                  context,
                                );
                                if (!context.mounted ||
                                    choice == _ArticleRemovalChoice.cancel) {
                                  return;
                                }

                                final haptics = ref.read(hapticServiceProvider);
                                haptics.medium();

                                if (choice ==
                                    _ArticleRemovalChoice.removeOnly) {
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
                                  return;
                                }

                                await ref
                                    .read(libraryActionsProvider)
                                    .deleteArticle(
                                      article.id,
                                      removeHighlights: true,
                                    );
                                unawaited(haptics.success());
                              },
                              icon: const Icon(Icons.bookmark_remove_rounded),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => ListView.builder(
                  itemCount: 7,
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

class _LibraryFilterControl extends StatelessWidget {
  const _LibraryFilterControl({required this.filter, required this.onChanged});

  final LibraryFilter filter;
  final ValueChanged<LibraryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: SegmentedButton<LibraryFilter>(
        key: ValueKey(filter),
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: LibraryFilter.all, label: Text('All')),
          ButtonSegment(value: LibraryFilter.unread, label: Text('Unread')),
          ButtonSegment(value: LibraryFilter.read, label: Text('Read')),
        ],
        selected: {filter},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}

enum _ArticleRemovalChoice { removeOnly, removeWithHighlights, cancel }

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
