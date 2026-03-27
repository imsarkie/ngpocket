import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:reader/core/database/app_database.dart';
import 'package:reader/core/services/service_providers.dart';
import 'package:reader/core/theme/app_theme.dart';
import 'package:reader/features/library/presentation/tag_articles_screen.dart';
import 'package:reader/features/reader/presentation/reader_screen.dart';
import 'package:reader/features/reader/providers/reader_provider.dart';

String _stripHtml(String text) {
  return text
      .replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

const List<Color> dotColors = [
  AppTheme.clay,
  AppTheme.mistBlue,
  AppTheme.sage,
  Color(0xFF9B7DD4),
  Color(0xFFE07B6A),
  Color(0xFF5BAAA4),
  Color(0xFFD4A843),
  Color(0xFF7C9E6B),
];

Color getDotColorForSource(String name) =>
    dotColors[name.hashCode.abs() % dotColors.length];

class ArticleListRow extends ConsumerWidget {
  const ArticleListRow({
    super.key,
    required this.article,
    this.trailing,
  });

  final Article article;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(articleTagsProvider(article.id));
    final tags = tagsAsync.valueOrNull ?? [];

    String snippet = article.description ?? '';
    if (snippet.isEmpty) {
      snippet = _stripHtml(article.content);
    }
    
    final hasImage = article.image != null && article.image!.isNotEmpty;
    final dotColor = getDotColorForSource(article.source ?? '');

    return InkWell(
      onTap: () {
        ref.read(hapticServiceProvider).selection();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReaderScreen(article: article)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 12),
              child: AnimatedOpacity(
                opacity: article.read ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                      article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                   ),
                   const SizedBox(height: 6),
                   Row(
                     children: [
                       Text(
                         article.source ?? "Web",
                         style: Theme.of(context).textTheme.bodySmall?.copyWith(
                           color: dotColor,
                           fontWeight: FontWeight.w600,
                         ),
                       ),
                       Text(
                         ' • ${article.readingTime} min',
                         style: Theme.of(context).textTheme.bodySmall?.copyWith(
                           color: Theme.of(context).colorScheme.onSurfaceVariant,
                         ),
                       ),
                     ],
                   ),
                   if (snippet.isNotEmpty) ...[
                     const SizedBox(height: 6),
                     Text(
                       snippet,
                       maxLines: 2,
                       overflow: TextOverflow.ellipsis,
                       style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                         color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                         height: 1.4,
                       ),
                     ),
                   ],
                   if (tags.isNotEmpty) ...[
                     const SizedBox(height: 12),
                     Wrap(
                       spacing: 8,
                       runSpacing: 8,
                       children: tags.map((tag) => _TagBubble(tag: tag)).toList(),
                     ),
                   ],
                ],
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 16),
              ClipRRect(
                 borderRadius: BorderRadius.circular(4),
                 child: CachedNetworkImage(
                   imageUrl: article.image!,
                   width: 80,
                   height: 80,
                   fit: BoxFit.cover,
                   errorWidget: (_, __, ___) => const SizedBox(width: 80, height: 80),
                 ),
              ),
            ] else 
              const SizedBox(width: 16),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _TagBubble extends ConsumerWidget {
  const _TagBubble({required this.tag});
  
  final String tag;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(hapticServiceProvider).selection();
        Navigator.of(context).push(
          MaterialPageRoute(
             builder: (_) => TagArticlesScreen(tag: tag),
          ),
        );
      },
      child: Container(
         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
         decoration: BoxDecoration(
           color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
           borderRadius: BorderRadius.circular(16),
           border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
           ),
         ),
         child: Text(
           tag,
           style: Theme.of(context).textTheme.labelSmall?.copyWith(
             fontWeight: FontWeight.w600,
             color: Theme.of(context).colorScheme.onSurfaceVariant,
           ),
         ),
      ),
    );
  }
}
