import 'package:flutter/material.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          _PolicyHeader(
            title: 'Terms & Conditions',
            subtitle: 'Last updated: March 29, 2026',
            context: context,
          ),
          const SizedBox(height: 24),
          _PolicySection(
            title: '1. Acceptance of Terms',
            body:
                'By downloading, installing, or using the Reader application ("the App"), '
                'you agree to be bound by these Terms & Conditions ("Terms"). If you do not '
                'agree to these Terms, please do not use the App.\n\n'
                'These Terms apply to all visitors, users, and others who access or use the App.',
          ),
          _PolicySection(
            title: '2. Description of Service',
            body:
                'Reader is a personal, non-commercial read-later and RSS reader application. '
                'It allows you to:\n\n'
                '• Subscribe to publicly available RSS and Atom feeds\n'
                '• Save web articles for offline or later reading by sharing them from other apps\n'
                '• Highlight and save text snippets from articles\n'
                '• Organise articles with tags and folders\n'
                '• Receive local reminders about your unread reading queue\n\n'
                'The App is provided free of charge. Certain premium features may be offered '
                'in future releases.',
          ),
          _PolicySection(
            title: '3. Personal Use Only',
            body:
                'Reader is intended exclusively for your personal, non-commercial use. '
                'You agree not to:\n\n'
                '• Use the App to reproduce, redistribute, sell, or commercially exploit '
                'third-party content retrieved through the App\n'
                '• Automate the retrieval of content in a manner that violates the terms of '
                'service of the content publishers\n'
                '• Use the App to infringe the intellectual property rights of any third party\n'
                '• Use the App for any unlawful purpose or in violation of any applicable laws\n\n'
                'All content fetched through the App (articles, images, feed data) is owned by '
                'the respective content publishers and is subject to their own terms of use.',
          ),
          _PolicySection(
            title: '4. Web Content & Third-Party Sources',
            body:
                'The App fetches content from external RSS feeds and web URLs that you, the user, '
                'explicitly provide or share. We do not host, endorse, or control any third-party '
                'content.\n\n'
                'We are not responsible for:\n\n'
                '• The accuracy, completeness, or legality of third-party content\n'
                '• The availability of external feeds or websites\n'
                '• Changes to feed formats or content that may cause display issues in the App\n'
                '• Any harm arising from content you retrieve through third-party sources\n\n'
                'Web article retrieval is performed solely as a convenience for your personal '
                'reading experience and is functionally equivalent to visiting a website in a '
                'browser.',
          ),
          _PolicySection(
            title: '5. Intellectual Property',
            body:
                'The Reader application, including its design, code, branding, and original '
                'content, is owned by imsarkie and is protected by applicable intellectual '
                'property laws.\n\n'
                'You may not copy, modify, distribute, sell, or lease any part of the App '
                'itself, nor may you reverse-engineer or attempt to extract the source code '
                'of the App, unless applicable laws prohibit these restrictions.',
          ),
          _PolicySection(
            title: '6. User-Generated Content',
            body:
                'Highlights, tags, and any annotations you create within the App are stored '
                'locally on your device. You retain full ownership of your own notes and '
                'highlights.\n\n'
                'You are solely responsible for the content of feeds you subscribe to and '
                'articles you save. We reserve the right to update or restrict App functionality '
                'if it is found to be used in ways that violate these Terms.',
          ),
          _PolicySection(
            title: '7. No Warranty',
            body:
                'The App is provided "as is" and "as available", without any warranty of any '
                'kind, express or implied, including but not limited to warranties of '
                'merchantability, fitness for a particular purpose, accuracy, or '
                'non-infringement.\n\n'
                'We do not warrant that:\n\n'
                '• The App will be uninterrupted, error-free, or free of viruses\n'
                '• Third-party feeds and content will be available or accurate\n'
                '• Any defects in the App will be corrected\n\n'
                'Your use of the App is at your own risk.',
          ),
          _PolicySection(
            title: '8. Limitation of Liability',
            body:
                'To the maximum extent permitted by applicable law, imsarkie and the '
                'Reader development team shall not be liable for any indirect, incidental, '
                'special, consequential, or punitive damages, including but not limited to '
                'loss of data, loss of revenue, or loss of business, arising out of or in '
                'connection with your use of the App, even if we have been advised of the '
                'possibility of such damages.',
          ),
          _PolicySection(
            title: '9. Notifications & Background Activity',
            body:
                'The App may run background tasks to sync RSS feeds and deliver local '
                'notifications. These tasks consume a small amount of battery and network '
                'data on your device.\n\n'
                'You can disable background sync and notifications at any time through the '
                'App\'s Settings screen or through your device\'s system settings. We are not '
                'responsible for any battery usage or data costs associated with background sync.',
          ),
          _PolicySection(
            title: '10. Premium Features',
            body:
                'Certain features listed in the App (such as Cloud Sync, Text-to-Speech, and '
                'AI Summaries) are marked as "Coming Soon" and are not yet available. No '
                'payment is currently collected for any feature.\n\n'
                'When premium features are introduced, separate pricing terms will be provided '
                'and you will not be charged without your explicit consent.',
          ),
          _PolicySection(
            title: '11. Changes to These Terms',
            body:
                'We reserve the right to modify these Terms at any time. Changes will be '
                'reflected by updating the "Last updated" date at the top of this document. '
                'Your continued use of the App after any changes constitutes your acceptance '
                'of the new Terms.',
          ),
          _PolicySection(
            title: '12. Termination',
            body:
                'You may stop using the App at any time. Uninstalling the App will remove all '
                'locally stored data from your device.\n\n'
                'We reserve the right to discontinue the App or restrict access to it at any '
                'time, for any reason, without prior notice.',
          ),
          _PolicySection(
            title: '13. Governing Law',
            body:
                'These Terms shall be governed by and construed in accordance with applicable '
                'laws. Any disputes arising from these Terms or your use of the App shall be '
                'subject to the exclusive jurisdiction of the competent courts.',
          ),
          _PolicySection(
            title: '14. Contact Us',
            body:
                'If you have any questions about these Terms & Conditions, please contact us:\n\n'
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
