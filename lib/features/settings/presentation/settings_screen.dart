import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:reader/core/services/service_providers.dart';
import 'package:reader/features/reader/providers/reader_provider.dart';
import 'package:reader/features/settings/presentation/highlights_screen.dart';
import 'package:reader/features/settings/presentation/premium_screen.dart';
import 'package:reader/features/settings/providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
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
          // 1. Profile Section (Disabled)
          const _SectionHeading(title: 'Profile'),
          const SizedBox(height: 12),
          _SectionCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).disabledColor.withValues(alpha: 0.1),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: Theme.of(context).disabledColor,
                ),
              ),
              title: Text(
                'Guest User',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).disabledColor,
                ),
              ),
              subtitle: Text(
                'Not logged in',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).disabledColor,
                ),
              ),
              enabled: false,
            ),
          ),
          const SizedBox(height: 18),

          // 2. Highlights Section
          const _SectionHeading(title: 'Highlights'),
          const SizedBox(height: 12),
          _SectionCard(
            child: ListTile(
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
                'Saved Snippets',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '$highlightCount highlights',
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
          ),
          const SizedBox(height: 18),

          // 3. Notifications Section
          const _SectionHeading(title: 'Notifications'),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Scheduled RSS sync & alerts',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Daily 1PM Feed drops and recurring unread library reminders.',
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
                  'Library Reminders: ${settings.libraryRemindersPerDay} times a day',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Slider(
                  value: settings.libraryRemindersPerDay.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '${settings.libraryRemindersPerDay}',
                  onChanged: settings.morningSyncNotificationsEnabled
                      ? (value) {
                          ref.read(hapticServiceProvider).selection();
                          ref
                              .read(appSettingsProvider.notifier)
                              .setLibraryRemindersPerDay(
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
                              .setLibraryRemindersPerDay(
                                value.round(),
                                persist: true,
                              );

                          if (!context.mounted) {
                            return;
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Frequency saved to ${value.round()} times a day.',
                              ),
                            ),
                          );
                        }
                      : null,
                ),
                Text(
                  'Range: 1 to 10 daily reminders.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 4. Premium Banner Section
          const _SectionHeading(title: 'Unlock Features'),
          const SizedBox(height: 12),
          _SectionCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
              title: Text(
                'Reader Premium',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Unlock Cloud Sync, Text-to-Speech & more',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                ref.read(hapticServiceProvider).selection();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PremiumScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          // 5. About Section
          const _SectionHeading(title: 'About'),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reader',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Minimal, swipe-first reading inbox for RSS and shared web articles.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.start,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _launchUrl('https://reader.imsarkie.in'),
                      icon: const Icon(Icons.language_rounded, size: 18),
                      label: const Text('Website'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _launchUrl('https://reader.imsarkie.in/docs/contact-us.html'),
                      icon: const Icon(Icons.mail_rounded, size: 18),
                      label: const Text('Contact Us'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _launchUrl('https://reader.imsarkie.in/docs/about-us.html'),
                      icon: const Icon(Icons.info_rounded, size: 18),
                      label: const Text('About Us'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // 6. Footer
          Center(
            child: Column(
              children: [
                Text(
                  '© ${DateTime.now().year} Reader',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Developed by imsarkie',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
