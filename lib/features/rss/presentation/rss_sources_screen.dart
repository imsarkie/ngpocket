import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reader/core/database/app_database.dart';
import 'package:reader/core/theme/app_theme.dart';
import 'package:reader/features/rss/presentation/add_feed_screen.dart';
import 'package:reader/features/rss/presentation/feed_articles_screen.dart';
import 'package:reader/features/rss/presentation/feed_folder_sheet.dart';
import 'package:reader/features/rss/providers/rss_provider.dart';
import 'package:reader/widgets/loading_skeleton.dart';

class RSSSourcesScreen extends ConsumerStatefulWidget {
  const RSSSourcesScreen({super.key});

  @override
  ConsumerState<RSSSourcesScreen> createState() => _RSSSourcesScreenState();
}

class _RSSSourcesScreenState extends ConsumerState<RSSSourcesScreen> {
  static const List<Color> _dotColors = [
    AppTheme.clay,
    AppTheme.mistBlue,
    AppTheme.sage,
    Color(0xFF9B7DD4),
    Color(0xFFE07B6A),
    Color(0xFF5BAAA4),
    Color(0xFFD4A843),
    Color(0xFF7C9E6B),
  ];

  Color _dotFor(String name) =>
      _dotColors[name.hashCode.abs() % _dotColors.length];

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(foldersWithFeedsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feeds'),
        actions: [
          IconButton(
            tooltip: 'Add',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddSheet(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.clay,
        onRefresh: () => ref.read(rssActionsProvider).refreshAll(),
        child: foldersAsync.when(
          data: (state) {
            if (state.isEmpty &&
                ref.read(feedsProvider).valueOrNull?.isEmpty != false) {
              return _buildEmpty(context);
            }
            return _buildGroupedList(context, state, scheme);
          },
          loading: () => ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: 5,
            itemBuilder: (_, __) => const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: ListItemSkeleton(),
            ),
          ),
          error: (e, _) => Center(
            child:
                Text('Unable to load feeds.\n$e', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Grouped list: folders first, then uncategorised
  // ---------------------------------------------------------------------------

  Widget _buildGroupedList(
    BuildContext context,
    FoldersWithFeedsState state,
    ColorScheme scheme,
  ) {
    if (state.isEmpty) return _buildEmpty(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Folders with their feeds inside
        for (final fwf in state.folders) ...[
          _FolderHeader(
            fwf: fwf,
            onRename: () => showRenameFolderSheet(context, ref, fwf.folder),
            onDelete: () => _confirmDeleteFolder(context, fwf.folder),
          ),
          const SizedBox(height: 4),
          for (final feed in fwf.feeds) ...[
            _FeedTile(
              feed: feed,
              dotColor: _dotFor(feed.name),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => FeedArticlesScreen(feed: feed)),
              ),
              onMove: () => showMoveFeedToFolderSheet(context, ref, feed),
              onRefresh: () =>
                  ref.read(rssActionsProvider).refreshFeed(feed),
              onRemove: () => _confirmDeleteFeed(context, feed),
            ),
            const SizedBox(height: 6),
          ],
          if (fwf.feeds.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 52, bottom: 8),
              child: Text(
                'No sources in this folder yet',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
          const SizedBox(height: 10),
        ],

        // Uncategorised section
        if (state.uncategorised.isNotEmpty) ...[
          if (state.folders.isNotEmpty) ...[
            _SectionDivider(label: 'Uncategorised'),
            const SizedBox(height: 8),
          ],
          for (final feed in state.uncategorised) ...[
            _FeedTile(
              feed: feed,
              dotColor: _dotFor(feed.name),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => FeedArticlesScreen(feed: feed)),
              ),
              onMove: () => showMoveFeedToFolderSheet(context, ref, feed),
              onRefresh: () =>
                  ref.read(rssActionsProvider).refreshFeed(feed),
              onRemove: () => _confirmDeleteFeed(context, feed),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Add sheet — new feed OR new folder
  // ---------------------------------------------------------------------------

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddChoiceSheet(
        onAddFeed: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddFeedScreen()),
          );
        },
        onNewFolder: () {
          Navigator.of(context).pop();
          showNewFolderSheet(context, ref);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Delete feed confirmation (two-step: delete feed, then optionally articles)
  // ---------------------------------------------------------------------------

  Future<void> _confirmDeleteFeed(BuildContext context, Feed feed) async {
    final choice = await showDialog<_FeedDeleteChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Source'),
        content: Text(
          'Remove "${feed.name}"?\n\nDo you also want to delete all articles from this source in your Read page?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_FeedDeleteChoice.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_FeedDeleteChoice.sourceOnly),
            child: const Text('Source only'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB93A2E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () =>
                Navigator.of(ctx).pop(_FeedDeleteChoice.sourceAndArticles),
            child: const Text('Source & articles'),
          ),
        ],
      ),
    );
    if (choice == null || choice == _FeedDeleteChoice.cancel) return;
    await ref.read(rssActionsProvider).removeFeedAndArticles(
          feed.id,
          feed.name,
          deleteArticles: choice == _FeedDeleteChoice.sourceAndArticles,
        );
  }

  // ---------------------------------------------------------------------------
  // Delete folder confirmation
  // ---------------------------------------------------------------------------

  Future<void> _confirmDeleteFolder(
      BuildContext context, FolderRow folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Folder'),
        content: Text(
          'Delete "${folder.name}"?\nSources inside will move to Uncategorised.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB93A2E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(rssActionsProvider).deleteFolder(folder.id);
    }
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  Widget _buildEmpty(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.28),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.clay.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.rss_feed_rounded,
                size: 32, color: AppTheme.clay),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'No feeds yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Tap + to add your first RSS source\nor create a folder to organise them.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Folder header row
// ---------------------------------------------------------------------------

class _FolderHeader extends StatelessWidget {
  const _FolderHeader({
    required this.fwf,
    required this.onRename,
    required this.onDelete,
  });

  final FolderWithFeeds fwf;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.clay.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.folder_rounded,
                size: 16, color: AppTheme.clay),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fwf.folder.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${fwf.feeds.length}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz_rounded,
                color: scheme.onSurfaceVariant, size: 20),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'rename',
                child: Row(children: [
                  Icon(Icons.drive_file_rename_outline_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Rename folder'),
                ]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 18, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Delete folder',
                      style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
            onSelected: (val) {
              if (val == 'rename') onRename();
              if (val == 'delete') onDelete();
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feed tile
// ---------------------------------------------------------------------------

class _FeedTile extends StatelessWidget {
  const _FeedTile({
    required this.feed,
    required this.dotColor,
    required this.onTap,
    required this.onMove,
    required this.onRefresh,
    required this.onRemove,
  });

  final Feed feed;
  final Color dotColor;
  final VoidCallback onTap;
  final VoidCallback onMove;
  final VoidCallback onRefresh;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final updatedLabel = feed.lastUpdated == null
        ? 'Not synced yet'
        : 'Updated ${DateFormat.yMMMd().format(feed.lastUpdated!.toLocal())}';

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Colour dot
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: dotColor, shape: BoxShape.circle),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feed.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      updatedLabel,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded,
                    color: scheme.onSurfaceVariant, size: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                onSelected: (val) {
                  if (val == 'move') onMove();
                  if (val == 'refresh') onRefresh();
                  if (val == 'remove') onRemove();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'move',
                    child: Row(children: [
                      Icon(Icons.folder_open_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Move to folder'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'refresh',
                    child: Row(children: [
                      Icon(Icons.refresh_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Refresh'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 18, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Remove', style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section divider (Uncategorised label)
// ---------------------------------------------------------------------------

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: scheme.outlineVariant, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 1.1,
                ),
          ),
        ),
        Expanded(child: Divider(color: scheme.outlineVariant, height: 1)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Add choice bottom sheet (Feed or Folder)
// ---------------------------------------------------------------------------

class _AddChoiceSheet extends StatelessWidget {
  const _AddChoiceSheet({
    required this.onAddFeed,
    required this.onNewFolder,
  });

  final VoidCallback onAddFeed;
  final VoidCallback onNewFolder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ChoiceTile(
            icon: Icons.rss_feed_rounded,
            iconColor: AppTheme.mistBlue,
            title: 'Add RSS Source',
            subtitle: 'Paste a feed URL to subscribe',
            onTap: onAddFeed,
          ),
          _ChoiceTile(
            icon: Icons.create_new_folder_rounded,
            iconColor: AppTheme.clay,
            title: 'New Folder',
            subtitle: 'Group sources into a collection',
            onTap: onNewFolder,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

enum _FeedDeleteChoice { cancel, sourceOnly, sourceAndArticles }

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
    );
  }
}
