import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ngpocket/core/services/service_providers.dart';
import 'package:ngpocket/features/feed/presentation/read_inbox_screen.dart';
import 'package:ngpocket/features/feed/presentation/swipe_reader_screen.dart';
import 'package:ngpocket/features/feed/providers/feed_provider.dart';
import 'package:ngpocket/features/library/presentation/library_screen.dart';
import 'package:ngpocket/features/settings/presentation/settings_screen.dart';
import 'package:ngpocket/widgets/ng_bottom_nav_bar.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 2;
  int _previousIndex = 2;

  @override
  Widget build(BuildContext context) {
    final unreadCountAsync = ref.watch(unreadCountProvider);
    final unreadCount = unreadCountAsync.valueOrNull ?? 0;
    final hideBottomNav = _currentIndex == 1;
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
          tween: Tween<double>(begin: 1, end: hideBottomNav ? 0 : 1),
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
        body: IndexedStack(
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
    setState(() {
      if (value == 1) {
        _previousIndex = _currentIndex;
      }
      _currentIndex = value;
    });
  }

  void _exitSwipeReader() {
    final nextIndex = _previousIndex == 1 ? 2 : _previousIndex;
    _selectTab(nextIndex);
  }
}
