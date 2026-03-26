import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ngpocket/core/services/background_sync_service.dart';
import 'package:ngpocket/core/services/service_providers.dart';
import 'package:ngpocket/core/services/share_intent_service.dart';
import 'package:ngpocket/core/theme/app_theme.dart';
import 'package:ngpocket/features/feed/providers/feed_provider.dart';
import 'package:ngpocket/features/rss/presentation/rss_sources_screen.dart';
import 'package:ngpocket/features/rss/providers/rss_provider.dart';
import 'package:ngpocket/features/settings/providers/settings_provider.dart';
import 'package:ngpocket/features/splash/presentation/reader_splash_gate.dart';
import 'package:ngpocket/widgets/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: NgPocketApp()));
}

class NgPocketApp extends ConsumerStatefulWidget {
  const NgPocketApp({super.key});

  @override
  ConsumerState<NgPocketApp> createState() => _NgPocketAppState();
}

class _NgPocketAppState extends ConsumerState<NgPocketApp> {
  StreamSubscription<SharedImport>? _shareSubscription;
  DateTime? _lastFeedsOpenAt;

  @override
  void initState() {
    super.initState();
    _listenToIncomingShares();
    unawaited(BackgroundSyncService.initializeNotificationHandling());
    unawaited(_initializeBackgroundSync());
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reader',
      debugShowCheckedModeBanner: false,
      navigatorKey: BackgroundSyncService.navigatorKey,
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      home: const ReaderSplashGate(child: AppShell()),
    );
  }

  Future<void> _listenToIncomingShares() async {
    final shareService = ref.read(shareIntentServiceProvider);
    final feedActions = ref.read(feedActionsProvider);
    final rssActions = ref.read(rssActionsProvider);

    _shareSubscription = shareService.sharedImportStream().listen((shared) async {
      try {
        if (shared.articleUrl != null) {
          await feedActions.ingestSharedUrl(shared.articleUrl!);
        }
        if (shared.rssDocument != null) {
          final imported = await rssActions.importFeedFromDocument(
            shared.rssDocument!,
            sourceNameHint: shared.fileName,
          );
          if (imported) {
            _openFeedsScreen();
          }
        }
      } catch (_) {
        // Ignore malformed shared payloads and keep app startup stable.
      }
    });

    final initialShare = await shareService.getInitialSharedImport();
    try {
      if (initialShare?.articleUrl != null) {
        await feedActions.ingestSharedUrl(initialShare!.articleUrl!);
      }
      if (initialShare?.rssDocument != null) {
        final imported = await rssActions.importFeedFromDocument(
          initialShare!.rssDocument!,
          sourceNameHint: initialShare.fileName,
        );
        if (imported) {
          _openFeedsScreen();
        }
      }
    } catch (_) {
      // Ignore malformed shared payloads and keep app startup stable.
    }
  }

  void _openFeedsScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final nav = BackgroundSyncService.navigatorKey.currentState;
      if (nav == null) {
        return;
      }

      final now = DateTime.now();
      if (_lastFeedsOpenAt != null &&
          now.difference(_lastFeedsOpenAt!) < const Duration(seconds: 1)) {
        return;
      }
      _lastFeedsOpenAt = now;

      nav.push(
        MaterialPageRoute(builder: (_) => const RSSSourcesScreen()),
      );
    });
  }

  Future<void> _initializeBackgroundSync() async {
    try {
      await ref.read(appSettingsProvider.notifier).ensureHydrated();
    } catch (_) {
      // Keep app startup resilient if background scheduling fails.
    }
  }
}
