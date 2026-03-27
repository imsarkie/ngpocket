import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader/core/services/service_providers.dart';
import 'package:reader/features/feed/presentation/read_inbox_screen.dart';
import 'package:reader/features/feed/presentation/swipe_reader_screen.dart';
import 'package:reader/features/feed/providers/feed_provider.dart';
import 'package:reader/features/library/presentation/library_screen.dart';
import 'package:reader/features/settings/presentation/settings_screen.dart';
import 'package:reader/widgets/ng_bottom_nav_bar.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;
  int _previousIndex = 0;
  PageController? _pageController;

  PageController get _safePageController {
    return _pageController ??= PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
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
      canPop: _currentIndex != 1,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        if (_currentIndex == 1) {
          _exitSwipeReader();
        }
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
        body: PageView(
          controller: _safePageController,
          // Navigation is controlled only by the bottom navbar interactions.
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: _onPageChanged,
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

    if (!_safePageController.hasClients) {
      return;
    }

    // Keep transitions instant after tab selection to avoid drag-time lag.
    _safePageController.jumpToPage(value);
  }

  void _exitSwipeReader() {
    final nextIndex = _previousIndex == 1 ? 0 : _previousIndex;
    _selectTab(nextIndex);
  }

  void _onPageChanged(int index) {
    if (index == _currentIndex) {
      return;
    }

    setState(() {
      if (index == 1) {
        _previousIndex = _currentIndex;
      }
      _currentIndex = index;
    });
  }
}
