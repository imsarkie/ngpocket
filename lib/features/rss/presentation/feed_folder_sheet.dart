import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader/core/database/app_database.dart';
import 'package:reader/core/theme/app_theme.dart';
import 'package:reader/features/rss/providers/rss_provider.dart';

// ---------------------------------------------------------------------------
// New Folder Sheet
// ---------------------------------------------------------------------------

Future<void> showNewFolderSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _NewFolderSheet(),
  );
}

class _NewFolderSheet extends ConsumerStatefulWidget {
  const _NewFolderSheet();

  @override
  ConsumerState<_NewFolderSheet> createState() => _NewFolderSheetState();
}

class _NewFolderSheetState extends ConsumerState<_NewFolderSheet> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(rssActionsProvider).createFolder(name);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.clay.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.create_new_folder_rounded,
                  color: AppTheme.clay,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'New Folder',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'e.g. Tech, Finance, Design…',
              filled: true,
              fillColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            onSubmitted: (_) => _create(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _create,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.clay,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rename Folder Sheet
// ---------------------------------------------------------------------------

Future<void> showRenameFolderSheet(
  BuildContext context,
  WidgetRef ref,
  FolderRow folder,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RenameFolderSheet(folder: folder),
  );
}

class _RenameFolderSheet extends ConsumerStatefulWidget {
  const _RenameFolderSheet({required this.folder});
  final FolderRow folder;

  @override
  ConsumerState<_RenameFolderSheet> createState() => _RenameFolderSheetState();
}

class _RenameFolderSheetState extends ConsumerState<_RenameFolderSheet> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.folder.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _rename() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(rssActionsProvider).renameFolder(widget.folder.id, name);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rename Folder', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              filled: true,
              fillColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            onSubmitted: (_) => _rename(),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _saving ? null : _rename,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.clay,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Rename'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Move Feed to Folder Sheet
// ---------------------------------------------------------------------------

Future<void> showMoveFeedToFolderSheet(
  BuildContext context,
  WidgetRef ref,
  Feed feed,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MoveFeedToFolderSheet(feed: feed),
  );
}

class _MoveFeedToFolderSheet extends ConsumerStatefulWidget {
  const _MoveFeedToFolderSheet({required this.feed});
  final Feed feed;

  @override
  ConsumerState<_MoveFeedToFolderSheet> createState() =>
      _MoveFeedToFolderSheetState();
}

class _MoveFeedToFolderSheetState
    extends ConsumerState<_MoveFeedToFolderSheet> {
  bool _moving = false;

  Future<void> _moveTo(int? folderId) async {
    if (_moving) return;
    setState(() => _moving = true);
    try {
      await ref
          .read(rssActionsProvider)
          .moveFeedToFolder(widget.feed.id, folderId);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _moving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(foldersWithFeedsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Move to Folder',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.feed.name,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          foldersAsync.when(
            data: (state) {
              final folders = state.folders;
              final currentFolderId = widget.feed.folderId;

              return ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Uncategorised option
                  _FolderChoiceTile(
                    icon: Icons.inbox_rounded,
                    label: 'Uncategorised',
                    isSelected: currentFolderId == null,
                    onTap: () => _moveTo(null),
                  ),
                  if (folders.isNotEmpty) ...[
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ...folders.map(
                      (fwf) => _FolderChoiceTile(
                        icon: Icons.folder_rounded,
                        label: fwf.folder.name,
                        isSelected: currentFolderId == fwf.folder.id,
                        onTap: () => _moveTo(fwf.folder.id),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error: $e'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderChoiceTile extends StatelessWidget {
  const _FolderChoiceTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.clay : scheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight:
                  isSelected ? FontWeight.w700 : FontWeight.normal,
              color: isSelected ? AppTheme.clay : null,
            ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: AppTheme.clay)
          : null,
      onTap: onTap,
    );
  }
}
