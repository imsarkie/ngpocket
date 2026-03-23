import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ngpocket/core/database/app_database.dart';

class ArticleSwipeCard extends StatelessWidget {
  const ArticleSwipeCard({
    super.key,
    required this.article,
    required this.onTap,
    this.horizontalSwipePercent = 0,
    this.verticalSwipePercent = 0,
  });

  final Article article;
  final VoidCallback onTap;
  final double horizontalSwipePercent;
  final double verticalSwipePercent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontal = (horizontalSwipePercent / 100)
        .clamp(-1.0, 1.0)
        .toDouble();
    final vertical = (verticalSwipePercent / 100).clamp(-1.0, 1.0).toDouble();
    final swipeStrength = math.max(horizontal.abs(), vertical.abs());
    final tilt = horizontal * 0.02;

    // Visual friction: slightly counter-shift content so drag feels less twitchy.
    final frictionOffset = Offset(-horizontal * 6, -vertical * 4);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        scale: 1 + (swipeStrength * 0.02),
        child: Transform.translate(
          offset: frictionOffset,
          child: Transform.rotate(
            angle: tilt,
            child: Center(
              child: AspectRatio(
                aspectRatio: 0.9,
                child: Card(
                  margin: EdgeInsets.zero,
                  elevation: 5,
                  shadowColor: Colors.black.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 4,
                            child: _CardImage(
                              imageUrl: article.image,
                              heroTag: 'article-image-${article.id}',
                            ),
                          ),
                          Expanded(
                            flex: 7,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFFFFCF6),
                                    Color(0xFFF7EFE2),
                                  ],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  14,
                                  18,
                                  16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              article.title,
                                              style:
                                                  GoogleFonts.playfairDisplay(
                                                    textStyle: Theme.of(context)
                                                        .textTheme
                                                        .headlineMedium
                                                        ?.copyWith(
                                                          color: colorScheme
                                                              .onSurface,
                                                          height: 1.08,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _compactDescription(
                                                article.description ?? '',
                                              ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.copyWith(
                                                    color: colorScheme.onSurface
                                                        .withValues(
                                                          alpha: 0.75,
                                                        ),
                                                    height: 1.35,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _MetaRow(
                                      source: article.source ?? 'Web',
                                      readingTime: article.readingTime,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      _SwipeOverlay(
                        horizontal: horizontal,
                        vertical: vertical,
                        colorScheme: colorScheme,
                      ),
                      if (swipeStrength > 0)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  width: 1.6,
                                  color: colorScheme.primary.withValues(
                                    alpha: (0.08 + (swipeStrength * 0.14))
                                        .clamp(0.0, 0.24)
                                        .toDouble(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _compactDescription(String input) {
    final text = input.trim();
    if (text.isEmpty) {
      return text;
    }

    final withoutMarkdownLinks = text.replaceAllMapped(
      RegExp("\\[([^\\]]+)\\]\\(([^\\)]+)\\)"),
      (match) => match.group(1) ?? '',
    );
    return withoutMarkdownLinks.replaceAll(RegExp('\\s+'), ' ').trim();
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({required this.imageUrl, required this.heroTag});

  final String? imageUrl;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final image = imageUrl;

    return SizedBox.expand(
      child: image != null && image.isNotEmpty
          ? Hero(
              tag: heroTag,
              child: CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                memCacheHeight: 680,
                fadeInDuration: const Duration(milliseconds: 220),
              ),
            )
          : const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFC3D1BA), Color(0xFF7DB0B9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.article_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.source, required this.readingTime});

  final String source;
  final int readingTime;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetaChip(icon: Icons.language_rounded, text: source),
        _MetaChip(icon: Icons.schedule_rounded, text: '$readingTime min'),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeOverlay extends StatelessWidget {
  const _SwipeOverlay({
    required this.horizontal,
    required this.vertical,
    required this.colorScheme,
  });

  final double horizontal;
  final double vertical;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final dominantHorizontal = horizontal.abs() >= vertical.abs();
    final progress = dominantHorizontal ? horizontal.abs() : vertical.abs();
    if (progress <= 0.04) {
      return const SizedBox.shrink();
    }

    late final String label;
    late final IconData icon;
    late final Color tint;

    if (dominantHorizontal && horizontal < 0) {
      label = 'Mark as Read';
      icon = Icons.done_rounded;
      tint = const Color(0xFFD16C3E);
    } else if (dominantHorizontal && horizontal > 0) {
      label = 'Save';
      icon = Icons.bookmark_add_rounded;
      tint = const Color(0xFF18865C);
    } else if (vertical < 0) {
      label = 'Next';
      icon = Icons.keyboard_double_arrow_up_rounded;
      tint = const Color(0xFF3A7D91);
    } else {
      return const SizedBox.shrink();
    }

    final opacity = ((progress - 0.06) / 0.94).clamp(0.0, 1.0).toDouble();
    final badgeScale = 0.94 + (progress * 0.06);

    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.18 * opacity),
            border: Border.all(
              color: tint.withValues(alpha: 0.6 * opacity),
              width: 1,
            ),
          ),
          child: Center(
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: badgeScale,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: tint.withValues(alpha: 0.7)),
                    boxShadow: [
                      BoxShadow(
                        color: tint.withValues(alpha: 0.2),
                        blurRadius: 16,
                        spreadRadius: -8,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 18, color: tint),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: tint,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
