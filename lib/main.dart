import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ngpocket/core/services/service_providers.dart';
import 'package:ngpocket/core/theme/app_theme.dart';
import 'package:ngpocket/features/feed/providers/feed_provider.dart';
import 'package:ngpocket/features/settings/providers/settings_provider.dart';
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
  StreamSubscription<String>? _shareSubscription;

  @override
  void initState() {
    super.initState();
    _listenToIncomingShares();
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp(
      title: 'ngpocket',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      home: const AppShell(),
    );
  }

  Future<void> _listenToIncomingShares() async {
    final shareService = ref.read(shareIntentServiceProvider);
    final feedActions = ref.read(feedActionsProvider);

    _shareSubscription = shareService.sharedUrlStream().listen((url) async {
      await feedActions.ingestSharedUrl(url);
    });

    final initialUrl = await shareService.getInitialSharedUrl();
    if (initialUrl != null) {
      await feedActions.ingestSharedUrl(initialUrl);
    }
  }
}
