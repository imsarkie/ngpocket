import 'package:flutter/material.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About App')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 110),
        children: [
          // App logo
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/branding/reader_icon.png',
                width: 88,
                height: 88,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Reader',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your minimal, swipe-first reading inbox.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 48),

          // Feature list
          _FeatureRow(
            icon: Icons.rss_feed_rounded,
            title: 'RSS & Atom Feed Support',
            description:
                'Subscribe to any RSS or Atom feed and read all your favourite sources in one place.',
          ),
          const SizedBox(height: 24),
          _FeatureRow(
            icon: Icons.share_rounded,
            title: 'Save Articles from Anywhere',
            description:
                'Share web articles directly into Reader from any app on your device.',
          ),
          const SizedBox(height: 24),
          _FeatureRow(
            icon: Icons.auto_awesome_rounded,
            title: 'Highlights & Snippets',
            description:
                'Select and save key passages while reading to build your personal knowledge library.',
          ),
          const SizedBox(height: 24),
          _FeatureRow(
            icon: Icons.swipe_rounded,
            title: 'Swipe-First Navigation',
            description:
                'Intuitive gesture controls let you breeze through your reading queue effortlessly.',
          ),
          const SizedBox(height: 24),
          _FeatureRow(
            icon: Icons.dark_mode_rounded,
            title: 'Dark Mode',
            description:
                'Beautiful adaptive themes keep your eyes comfortable day and night.',
          ),

          const SizedBox(height: 48),

          // Version / footer
          Center(
            child: Text(
              'Version 1.0.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '© ${DateTime.now().year} Reader · Developed by imsarkie',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
