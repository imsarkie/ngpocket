import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          _PolicyHeader(
            title: 'Privacy Policy',
            subtitle: 'Last updated: March 29, 2026',
            context: context,
          ),
          const SizedBox(height: 24),
          _PolicySection(
            title: '1. Overview',
            body:
                'Reader ("we", "our", or "the app") is committed to protecting your privacy. '
                'This Privacy Policy explains how Reader handles information when you use our '
                'mobile application.\n\n'
                'The short version: Reader does not collect, store, or transmit any personal '
                'information to us or any third party. Everything stays on your device.',
          ),
          _PolicySection(
            title: '2. Data We Do NOT Collect',
            body:
                'Reader does not collect, process, or transmit any of the following:\n\n'
                '• Your name, email address, phone number, or any other identity information\n'
                '• Your location or IP address\n'
                '• Device identifiers or advertising IDs\n'
                '• Usage analytics or crash reports to external servers\n'
                '• Any browsing history beyond what is stored locally on your device\n'
                '• Payment or billing information (no purchases are processed in the current version)',
          ),
          _PolicySection(
            title: '3. Data Stored Locally on Your Device',
            body:
                'All app data is stored exclusively on your device using a local SQLite database '
                'and system storage. This includes:\n\n'
                '• RSS/Atom feed URLs you subscribe to\n'
                '• Articles fetched from those feeds or shared into the app\n'
                '• Article highlights and saved snippets you create\n'
                '• Your app preferences (theme, notification settings)\n'
                '• Cached article images\n\n'
                'This data is never uploaded to any server. Uninstalling the app permanently '
                'removes all locally stored data from your device.',
          ),
          _PolicySection(
            title: '4. Internet Usage',
            body:
                'Reader requires an internet connection solely to fetch content you have '
                'explicitly requested:\n\n'
                '• Fetching the RSS/Atom feeds you subscribe to, from the URLs you provide\n'
                '• Loading article content and images from those feeds\n'
                '• Fetching articles from URLs you share into the app from other applications\n\n'
                'No data from these network requests is transmitted to us. Traffic goes directly '
                'between your device and the content publishers\' servers, just as it would in a '
                'standard web browser.',
          ),
          _PolicySection(
            title: '5. Web Content & Fair Use',
            body:
                'Reader fetches web articles and RSS content strictly for your personal, '
                'non-commercial reading experience. This feature is equivalent to a personal '
                'browser — you are the requester, and the content is displayed only to you.\n\n'
                'We do not scrape, redistribute, resell, aggregate, or commercially exploit '
                'any third-party content. All content ownership and copyright remain with the '
                'respective publishers. Reader acts only as a personal reading client.',
          ),
          _PolicySection(
            title: '6. Notifications',
            body:
                'Reader uses local notifications only, scheduled and delivered entirely on your '
                'device. These notifications include:\n\n'
                '• Daily feed sync reminders\n'
                '• Unread article reminders (if enabled)\n\n'
                'No notification data is sent to or processed by any external server. You can '
                'disable notifications at any time in the app\'s Settings or in your device\'s '
                'system notification settings.',
          ),
          _PolicySection(
            title: '7. Third-Party Services',
            body:
                'Reader does not integrate any advertising networks, analytics platforms, '
                'social login providers, or data brokers.\n\n'
                'The app connects only to the external RSS/content URLs that you, the user, '
                'have explicitly added. We are not responsible for the privacy practices of '
                'those third-party websites or content publishers.',
          ),
          _PolicySection(
            title: '8. Children\'s Privacy',
            body:
                'Reader is not directed at children under the age of 13 and we do not '
                'knowingly collect personal information from children. Since no personal data '
                'is collected from any user, the app does not pose specific risks to younger '
                'users beyond general internet access.',
          ),
          _PolicySection(
            title: '9. Data Security',
            body:
                'Because all data is stored locally on your device, the security of that data '
                'depends on your device\'s own security controls (screen lock, encryption, etc.). '
                'We do not have access to your data and cannot be held responsible for device-level '
                'security breaches.',
          ),
          _PolicySection(
            title: '10. Changes to This Policy',
            body:
                'We may update this Privacy Policy from time to time. When we do, we will '
                'update the "Last updated" date at the top of this page. We encourage you to '
                'review this policy periodically. Continued use of the app after changes '
                'constitutes your acceptance of the revised policy.',
          ),
          _PolicySection(
            title: '11. Contact Us',
            body:
                'If you have any questions or concerns about this Privacy Policy, please '
                'contact us:\n\n'
                'Website: https://reader.imsarkie.in\n'
                'Contact: https://reader.imsarkie.in/docs/contact-us.html',
          ),
        ],
      ),
    );
  }
}

class _PolicyHeader extends StatelessWidget {
  const _PolicyHeader({
    required this.title,
    required this.subtitle,
    required this.context,
  });

  final String title;
  final String subtitle;
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
