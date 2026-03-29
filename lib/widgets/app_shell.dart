import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader/core/database/database_provider.dart';
import 'package:reader/core/services/service_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reader/features/feed/presentation/read_inbox_screen.dart';
import 'package:reader/features/feed/presentation/swipe_reader_screen.dart';
import 'package:reader/features/feed/providers/feed_provider.dart';
import 'package:reader/features/library/presentation/library_screen.dart';
import 'package:reader/features/library/providers/library_provider.dart';
import 'package:reader/features/rss/providers/rss_provider.dart';
import 'package:reader/features/settings/presentation/settings_screen.dart';
import 'package:reader/widgets/ng_bottom_nav_bar.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_processPendingSharedUrls());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called when the app comes back to the foreground — invalidates every
  /// stream provider so they re-subscribe and pick up DB writes that happened
  /// in a separate activity instance (e.g. the share-receipt flow).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(savedArticlesProvider);
      ref.invalidate(foldersWithFeedsProvider);
      ref.invalidate(feedsProvider);
      ref.invalidate(inboxArticlesProvider);
      ref.invalidate(filteredInboxArticlesProvider);
      ref.invalidate(unreadCountProvider);
      unawaited(_processPendingSharedUrls());
    }
  }

  /// Reads any items queued by [ShareReceiverActivity] from SharedPreferences
  /// and processes them: RSS file content → importFeedFromDocument,
  /// article URLs → ingestSharedUrl (with placeholder shown during fetch).
  Future<void> _processPendingSharedUrls() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Force re-read from disk so native writes from ShareReceiverActivity
      // are visible even when the Flutter singleton has a stale cache.
      await prefs.reload();

      // 1. RSS file queued from file manager
      final rssContent = prefs.getString('pending_rss_content');
      if (rssContent != null && rssContent.isNotEmpty) {
        await prefs.remove('pending_rss_content');
        final rssFilename = prefs.getString('pending_rss_filename') ?? '';
        if (rssFilename.isNotEmpty) await prefs.remove('pending_rss_filename');
        if (mounted) {
          try {
            await ref.read(rssActionsProvider).importFeedFromDocument(
              rssContent,
              sourceNameHint: rssFilename.isNotEmpty ? rssFilename : null,
            );
            if (mounted) {
              ref.invalidate(feedsProvider);
              ref.invalidate(foldersWithFeedsProvider);
            }
          } catch (_) {}
        }
      }

      // 2. Article URLs queued from browser
      final raw = prefs.getString('pending_share_url');
      if (raw == null || raw.isEmpty) return;
      await prefs.remove('pending_share_url');
      final urls = raw
          .split('\n')
          .map((u) => u.trim())
          .where((u) => u.isNotEmpty)
          .toList();
      if (urls.isEmpty || !mounted) return;
      final db = ref.read(appDatabaseProvider);
      final actions = ref.read(feedActionsProvider);
      for (final url in urls) {
        try {
          // 1. Save placeholder so the article appears in the list instantly.
          await db.insertPlaceholderArticle(url);
          if (!mounted) return;
          ref.read(downloadingUrlsProvider.notifier).update((s) => {...s, url});
          ref.invalidate(savedArticlesProvider);
          // 2. Parse & fully populate the article.
          try {
            await actions.ingestSharedUrl(url);
          } finally {
            if (mounted) {
              ref
                  .read(downloadingUrlsProvider.notifier)
                  .update((s) => {...s}..remove(url));
            }
          }
        } catch (_) {}
      }
      if (!mounted) return;
      ref.invalidate(savedArticlesProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final unreadCountAsync = ref.watch(unreadCountProvider);
    final unreadCount = unreadCountAsync.valueOrNull ?? 0;
    final navBarHeight = navBarHeightFor(context);

    final navBar = NgBottomNavBar(
      currentIndex: _currentIndex,
      unreadCount: unreadCount,
      onTabSelected: _selectTab,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex == 1) {
          _exitSwipeReader();
          return;
        }
        _confirmExit(context);
      },
      child: Scaffold(
        extendBody: false,
        bottomNavigationBar: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 1, end: 1),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return SizedBox(
              height: navBarHeight * value,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  heightFactor: value,
                  child: Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 26),
                      child: child,
                    ),
                  ),
                ),
              ),
            );
          },
          child: navBar,
        ),
        body: _FadeIndexedStack(
          index: _currentIndex,
          children: [
            const LibraryScreen(),
            SwipeReaderScreen(onBackPressed: _exitSwipeReader),
            const ReadInboxScreen(),
            const SettingsScreen(),
          ],
        ),
      ),
    );
  }

  void _selectTab(int value) {
    if (_currentIndex == value) {
      return;
    }

    ref.read(hapticServiceProvider).selection();

    final previousBeforeChange = _currentIndex;

    if (value == 1) {
      _previousIndex = previousBeforeChange;
    }

    setState(() {
      _currentIndex = value;
    });
  }

  void _exitSwipeReader() {
    final nextIndex = _previousIndex == 1 ? 0 : _previousIndex;
    _selectTab(nextIndex);
  }

  Future<void> _confirmExit(BuildContext context) async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quit Reader?'),
        content: const Text('Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
    if (quit == true) SystemNavigator.pop();
  }
}

class _FadeIndexedStack extends StatefulWidget {
  const _FadeIndexedStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<_FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1.0,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(_FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: IndexedStack(
        index: widget.index,
        children: widget.children,
      ),
    );
  }
}
