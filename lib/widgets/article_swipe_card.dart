import 'dart:math' as math;
import 'dart:ui';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageUrl = article.image;
    final description = (article.description ?? '').trim();
    final horizontal = horizontalSwipePercent.clamp(-1.0, 1.0).toDouble();
    final vertical = verticalSwipePercent.clamp(-1.0, 1.0).toDouble();
    final swipeStrength = math.max(horizontal.abs(), vertical.abs());
    final actionOpacity = (horizontal.abs() * 1.4).clamp(0.0, 1.0).toDouble();

    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: isDark ? 20 : 8,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl != null && imageUrl.isNotEmpty
                ? Hero(
                    tag: 'article-image-${article.id}',
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      memCacheHeight: 1400,
                    ),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? const [Color(0xFF0F766E), Color(0xFF155E75)]
                            : const [Color(0xFF89D6D1), Color(0xFFB8E4DF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: isDark ? 0.16 : 0.03),
                    Colors.black.withValues(alpha: isDark ? 0.36 : 0.1),
                    Colors.black.withValues(alpha: isDark ? 0.88 : 0.36),
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.0,
                  colors: [
                    Colors.white.withValues(alpha: isDark ? 0.14 : 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              top: 18,
              left: 18,
              child: _ChipLabel(text: article.source ?? 'Web', isDark: isDark),
            ),
            Positioned(
              top: 18,
              right: 18,
              child: _ChipLabel(
                text: '${article.readingTime} min',
                isDark: isDark,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              child: Column(
                children: [
                  const Spacer(),
                  AnimatedScale(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    scale: 1 - (swipeStrength * 0.016),
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.18)
                              : colorScheme.outline.withValues(alpha: 0.22),
                        ),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 24,
                            spreadRadius: -6,
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.45 : 0.14,
                            ),
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: imageUrl != null && imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      memCacheHeight: 1000,
                                    )
                                  : const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF1A7675),
                                            Color(0xFF114F63),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                    ),
                            ),
                            Positioned.fill(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 14,
                                  sigmaY: 14,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        isDark
                                            ? Colors.black.withValues(
                                                alpha: 0.48,
                                              )
                                            : Colors.white.withValues(
                                                alpha: 0.7,
                                              ),
                                        isDark
                                            ? Colors.black.withValues(
                                                alpha: 0.72,
                                              )
                                            : Colors.white.withValues(
                                                alpha: 0.82,
                                              ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                22,
                                20,
                                20,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    article.title,
                                    style: GoogleFonts.playfairDisplay(
                                      textStyle: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            color: isDark
                                                ? Colors.white
                                                : colorScheme.onSurface,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 28,
                                            height: 1.18,
                                            shadows: isDark
                                                ? const [
                                                    Shadow(
                                                      blurRadius: 12,
                                                      color: Color(0x66000000),
                                                      offset: Offset(0, 2),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                    ),
                                  ),
                                  if (description.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      description,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.dmSans(
                                        textStyle: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: isDark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.88,
                                                    )
                                                  : colorScheme.onSurface
                                                        .withValues(alpha: 0.7),
                                              fontSize: 15,
                                              fontWeight: FontWeight.w400,
                                              height: 1.45,
                                            ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (horizontal > 0)
              _SwipeActionOverlay(
                label: 'SAVE',
                alignment: Alignment.topLeft,
                color: const Color(0xFF22C55E),
                opacity: actionOpacity,
                isDark: isDark,
              ),
            if (horizontal < 0)
              _SwipeActionOverlay(
                label: 'READ',
                alignment: Alignment.topRight,
                color: const Color(0xFFF97316),
                opacity: actionOpacity,
                isDark: isDark,
              ),
            if (swipeStrength > 0)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    width: 2,
                    color: (isDark ? Colors.white : colorScheme.primary)
                        .withValues(
                          alpha: (0.06 + (swipeStrength * 0.1))
                              .clamp(0.0, 0.16)
                              .toDouble(),
                        ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SwipeActionOverlay extends StatelessWidget {
  const _SwipeActionOverlay({
    required this.label,
    required this.alignment,
    required this.color,
    required this.opacity,
    required this.isDark,
  });

  final String label;
  final Alignment alignment;
  final Color color;
  final double opacity;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Opacity(
            opacity: opacity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.22 : 0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.78)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isDark ? Colors.white : color,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w800,
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

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.text, required this.isDark});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.28)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.24)
              : colorScheme.outline.withValues(alpha: 0.26),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          text,
          style: GoogleFonts.dmSans(
            textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isDark ? Colors.white : colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
