import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ngpocket/core/services/service_providers.dart';
import 'package:ngpocket/features/reader/providers/reader_provider.dart';
import 'package:ngpocket/features/settings/presentation/highlights_screen.dart';
import 'package:ngpocket/features/settings/providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _endpointController;

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController(
      text: ref.read(appSettingsProvider).parserEndpoint,
    );
  }

  @override
  void dispose() {
    _endpointController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final highlightsAsync = ref.watch(allHighlightsProvider);
    final highlightCount = highlightsAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          const _SectionHeading(title: 'Appearance'),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Color Palette',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vintage mode is now fixed across the app with Clay, Beige, Sage, and Mist Blue accents.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _SectionHeading(title: 'Reader'),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    'Highlights',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '$highlightCount saved snippets',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    ref.read(hapticServiceProvider).selection();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const HighlightsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reader Font Scale',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: settings.readerFontScale,
                  min: 0.85,
                  max: 1.5,
                  divisions: 13,
                  label: '${settings.readerFontScale.toStringAsFixed(2)}x',
                  onChanged: (value) {
                    ref.read(hapticServiceProvider).selection();
                    ref
                        .read(appSettingsProvider.notifier)
                        .setReaderFontScale(value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _SectionHeading(title: 'Notifications'),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Morning RSS sync alerts',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'After sync, notify when unread library count reaches your threshold.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: settings.morningSyncNotificationsEnabled,
                  onChanged: (enabled) async {
                    final haptics = ref.read(hapticServiceProvider);
                    haptics.selection();
                    final applied = await ref
                        .read(appSettingsProvider.notifier)
                        .setMorningSyncNotificationsEnabled(enabled);

                    if (!context.mounted) {
                      return;
                    }

                    final message = !enabled
                        ? 'Morning sync notifications disabled.'
                        : applied
                        ? 'Morning sync notifications enabled.'
                        : 'Notification permission is blocked. Enable it in system settings.';

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Unread threshold: ${settings.unreadNotificationThreshold}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Slider(
                  value: settings.unreadNotificationThreshold.toDouble(),
                  min: 3,
                  max: 10,
                  divisions: 7,
                  label: '${settings.unreadNotificationThreshold}',
                  onChanged: settings.morningSyncNotificationsEnabled
                      ? (value) {
                          ref.read(hapticServiceProvider).selection();
                          ref
                              .read(appSettingsProvider.notifier)
                              .setUnreadNotificationThreshold(
                                value.round(),
                                persist: false,
                              );
                        }
                      : null,
                  onChangeEnd: settings.morningSyncNotificationsEnabled
                      ? (value) async {
                          final haptics = ref.read(hapticServiceProvider);
                          haptics.medium();
                          await ref
                              .read(appSettingsProvider.notifier)
                              .setUnreadNotificationThreshold(
                                value.round(),
                                persist: true,
                                showTestNotification: true,
                              );

                          if (!context.mounted) {
                            return;
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Threshold saved to ${value.round()}. Test notification sent.',
                              ),
                            ),
                          );
                        }
                      : null,
                ),
                Text(
                  'Range: 3 to 10 unread saved articles.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _SectionHeading(title: 'Parser'),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parser Backend',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Optional endpoint used for POST /parse. When empty, local parsing is used.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _endpointController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    hintText: 'https://your-parser-api.com',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: () {
                      final haptics = ref.read(hapticServiceProvider);
                      haptics.medium();
                      ref
                          .read(appSettingsProvider.notifier)
                          .setParserEndpoint(_endpointController.text);
                      haptics.selection();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Parser endpoint updated.'),
                        ),
                      );
                    },
                    child: const Text('Save Endpoint'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _SectionHeading(title: 'About'),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ngpocket',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Minimal, swipe-first reading inbox for RSS and shared web articles.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
