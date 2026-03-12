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

  final _tabs = const [
    LibraryScreen(),
    SwipeReaderScreen(),
    ReadInboxScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final unreadCountAsync = ref.watch(unreadCountProvider);
    final unreadCount = unreadCountAsync.valueOrNull ?? 0;

    final navBar = NgBottomNavBar(
      currentIndex: _currentIndex,
      unreadCount: unreadCount,
      onTabSelected: (value) {
        if (_currentIndex == value) {
          return;
        }

        ref.read(hapticServiceProvider).selection();
        setState(() => _currentIndex = value);
      },
    );

    return Scaffold(
      extendBody: true,
      bottomNavigationBar: navBar,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: _tabs[_currentIndex],
        ),
      ),
    );
  }
}
