import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader/core/services/background_sync_service.dart';
import 'package:reader/core/theme/app_theme.dart';
import 'package:reader/features/settings/providers/settings_provider.dart';
import 'package:reader/features/splash/presentation/reader_splash_gate.dart';
import 'package:reader/widgets/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ReaderApp()));
}

class ReaderApp extends ConsumerStatefulWidget {
  const ReaderApp({super.key});

  @override
  ConsumerState<ReaderApp> createState() => _ReaderAppState();
}

class _ReaderAppState extends ConsumerState<ReaderApp> {
  @override
  void initState() {
    super.initState();
    unawaited(BackgroundSyncService.initializeNotificationHandling());
    unawaited(_initializeBackgroundSync());
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(
      appSettingsProvider.select((s) => s.themeMode),
    );
    return MaterialApp(
      title: 'Reader',
      debugShowCheckedModeBanner: false,
      navigatorKey: BackgroundSyncService.navigatorKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const ReaderSplashGate(child: AppShell()),
    );
  }

  Future<void> _initializeBackgroundSync() async {
    try {
      await ref.read(appSettingsProvider.notifier).ensureHydrated();

      // On app open: automatically fetch in background silently so you
      // aren't peppered with notifications directly on launch.
      unawaited(
        BackgroundSyncService.syncFeedsAndNotify(notifyUser: false),
      );
    } catch (_) {
      // Keep app startup resilient if background scheduling fails.
    }
  }
}


