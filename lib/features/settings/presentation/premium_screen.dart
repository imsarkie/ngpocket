import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reader Premium')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          const SizedBox(height: 24),
          Icon(
            Icons.workspace_premium_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Unlock the Ultimate Reading Experience',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Supercharge your workflow natively.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 48),
          _FeatureRow(
            icon: Icons.cloud_sync_rounded,
            title: 'Cloud Sync across Devices',
            description: 'Read seamlessly across your desktop, tablet, and phone.',
            context: context,
          ),
          const SizedBox(height: 24),
          _FeatureRow(
            icon: Icons.record_voice_over_rounded,
            title: 'Text-to-Speech Engine',
            description: 'Listen to articles on your commute via high-quality AI transcription.',
            context: context,
          ),
          const SizedBox(height: 24),
          _FeatureRow(
            icon: Icons.auto_awesome_rounded,
            title: 'AI Summaries',
            description: 'Get deep intelligent breakdowns of long-form articles before reading.',
            context: context,
          ),
          const SizedBox(height: 24),
          _FeatureRow(
            icon: Icons.palette_rounded,
            title: 'Pro Themes & Layouts',
            description: 'Unlock exclusive typography suites and dynamic screen themes.',
            context: context,
          ),
          const SizedBox(height: 48),
          FilledButton.tonalIcon(
            onPressed: null, // Disabled to indicate "Coming soon"
            icon: const Icon(Icons.star_rounded),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'Buy Premium (Coming Soon)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
    required this.context,
  });

  final IconData icon;
  final String title;
  final String description;
  final BuildContext context;

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
