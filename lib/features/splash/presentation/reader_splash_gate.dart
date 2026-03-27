import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:reader/features/splash/presentation/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kPermissionsRequestedKey = 'onboarding.permissions_requested_v1';

/// Gate widget — shows onboarding on first launch, then passes through to
/// [child] on every subsequent launch. Also requests notification permission
/// exactly once without blocking the UI.
class ReaderSplashGate extends StatefulWidget {
  const ReaderSplashGate({required this.child, super.key});

  final Widget child;

  @override
  State<ReaderSplashGate> createState() => _ReaderSplashGateState();
}

class _ReaderSplashGateState extends State<ReaderSplashGate> {
  // null = still checking, true = show onboarding, false = skip straight to app
  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final needed = await isOnboardingNeeded();
    if (!mounted) return;
    setState(() => _showOnboarding = needed);

    // Request notification permission once — independently of onboarding.
    unawaited(_requestPermissionsIfFirstLaunch());
  }

  Future<void> _requestPermissionsIfFirstLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyRequested =
          prefs.getBool(_kPermissionsRequestedKey) ?? false;
      if (alreadyRequested) return;
      await prefs.setBool(_kPermissionsRequestedKey, true);

      final notifications = FlutterLocalNotificationsPlugin();
      final androidPlugin = notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
    } catch (_) {
      // Never block app startup due to permission errors.
    }
  }

  void _onOnboardingDone() {
    if (mounted) setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    // Still checking prefs — show nothing (the native splash is still visible).
    if (_showOnboarding == null) return const SizedBox.shrink();

    if (_showOnboarding!) {
      return OnboardingScreen(onDone: _onOnboardingDone);
    }

    return widget.child;
  }
}
