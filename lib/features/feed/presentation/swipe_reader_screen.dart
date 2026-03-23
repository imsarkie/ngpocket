import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ngpocket/core/database/app_database.dart';
import 'package:ngpocket/core/services/service_providers.dart';
import 'package:ngpocket/features/feed/providers/feed_provider.dart';
import 'package:ngpocket/features/reader/presentation/reader_screen.dart';
import 'package:ngpocket/widgets/article_swipe_card.dart';
import 'package:ngpocket/widgets/loading_skeleton.dart';

class SwipeReaderScreen extends ConsumerStatefulWidget {
  const SwipeReaderScreen({super.key, this.onBackPressed});

  final VoidCallback? onBackPressed;

  @override
  ConsumerState<SwipeReaderScreen> createState() => _SwipeReaderScreenState();
}

class _SwipeReaderScreenState extends ConsumerState<SwipeReaderScreen> {
  final CardSwiperController _controller = CardSwiperController();

  int _frontCardIndex = 0;
  bool _isDragging = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(swipeQueueProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0xFFF8F0E3), Color(0xFFE7DDCC)],
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Swipe Reader'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed:
              widget.onBackPressed ?? () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(gradient: backgroundGradient),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
                child: queueAsync.when(
                  data: (articles) {
                    if (_frontCardIndex >= articles.length &&
                        articles.isNotEmpty) {
                      _frontCardIndex = 0;
                    }

                    if (articles.isNotEmpty) {
                      _precacheUpcomingImages(articles);
                    }

                    if (articles.isEmpty) {
                      return _EmptySwipeState(
                        onCtaPressed:
                            widget.onBackPressed ??
                            () => Navigator.of(context).maybePop(),
                      );
                    }

                    return Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
                            child: CardSwiper(
                              controller: _controller,
                              padding: EdgeInsets.zero,
                              cardsCount: articles.length,
                              numberOfCardsDisplayed: articles.length.clamp(
                                1,
                                2,
                              ),
                              backCardOffset: const Offset(0, 14),
                              maxAngle: 8,
                              threshold: 62,
                              duration: const Duration(milliseconds: 260),
                              scale: 0.95,
                              allowedSwipeDirection:
                                  const AllowedSwipeDirection.only(
                                    left: true,
                                    right: true,
                                    up: true,
                                    down: false,
                                  ),
                              onSwipeDirectionChange:
                                  (horizontalDirection, verticalDirection) {
                                    final isInteracting =
                                        horizontalDirection !=
                                            CardSwiperDirection.none ||
                                        verticalDirection !=
                                            CardSwiperDirection.none;

                                    if (!_isDragging && isInteracting) {
                                      ref.read(hapticServiceProvider).light();
                                    }

                                    if (_isDragging != isInteracting &&
                                        mounted) {
                                      setState(() {
                                        _isDragging = isInteracting;
                                      });
                                    }
                                  },
                              onSwipe:
                                  (previousIndex, currentIndex, direction) {
                                    if (previousIndex < 0 ||
                                        previousIndex >= articles.length) {
                                      return false;
                                    }

                                    final article = articles[previousIndex];
                                    final didSwipe = _handleSwipe(
                                      article,
                                      direction,
                                    );
                                    if (!didSwipe) {
                                      return false;
                                    }

                                    ref.read(hapticServiceProvider).medium();

                                    if (currentIndex != null) {
                                      _frontCardIndex = currentIndex;
                                      _precacheUpcomingImages(articles);
                                    }

                                    if (_isDragging && mounted) {
                                      setState(() {
                                        _isDragging = false;
                                      });
                                    }

                                    return true;
                                  },
                              cardBuilder:
                                  (
                                    context,
                                    index,
                                    horizontalThresholdPercentage,
                                    verticalThresholdPercentage,
                                  ) {
                                    if (index < 0 || index >= articles.length) {
                                      return const SizedBox.shrink();
                                    }

                                    final article = articles[index];
                                    return ArticleSwipeCard(
                                      article: article,
                                      onTap: () => _openArticle(article),
                                      horizontalSwipePercent:
                                          horizontalThresholdPercentage
                                              .toDouble(),
                                      verticalSwipePercent:
                                          verticalThresholdPercentage
                                              .toDouble(),
                                    );
                                  },
                            ),
                          ),
                        ),
                        if (articles.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _SwipeActionBar(
                            onRead: () =>
                                _controller.swipe(CardSwiperDirection.left),
                            onSave: () =>
                                _controller.swipe(CardSwiperDirection.right),
                            onNext: () =>
                                _controller.swipe(CardSwiperDirection.top),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => const SwipeCardSkeleton(),
                  error: (error, stackTrace) => Center(
                    child: Text(
                      'Unable to load articles.\n$error',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              opacity: _isDragging ? 0.14 : 0,
              child: const ColoredBox(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  bool _handleSwipe(Article article, CardSwiperDirection direction) {
    final actions = ref.read(feedActionsProvider);
    final haptics = ref.read(hapticServiceProvider);

    switch (direction) {
      case CardSwiperDirection.left:
        unawaited(actions.markRead(article.id, true));
        unawaited(haptics.success());
        return true;
      case CardSwiperDirection.right:
        unawaited(actions.saveAndScrapeArticle(article));
        unawaited(haptics.success());
        return true;
      case CardSwiperDirection.top:
        unawaited(haptics.success());
        return true;
      case CardSwiperDirection.bottom:
        return false;
      case CardSwiperDirection.none:
        return false;
    }

    return false;
  }

  Future<void> _openArticle(Article article) async {
    ref.read(hapticServiceProvider).selection();
    await ref.read(feedActionsProvider).markRead(article.id, true);
    if (!mounted) {
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ReaderScreen(article: article)));
  }

  void _precacheUpcomingImages(List<Article> articles) {
    if (!mounted || articles.isEmpty) {
      return;
    }

    final candidates = <int>{_frontCardIndex, _frontCardIndex + 1};
    for (final index in candidates) {
      final safeIndex = index % articles.length;
      final imageUrl = articles[safeIndex].image;
      if (imageUrl == null || imageUrl.isEmpty) {
        continue;
      }

      precacheImage(CachedNetworkImageProvider(imageUrl), context);
    }
  }
}

class _SwipeActionBar extends StatelessWidget {
  const _SwipeActionBar({
    required this.onRead,
    required this.onSave,
    required this.onNext,
  });

  final VoidCallback onRead;
  final VoidCallback onSave;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.38)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: _ActionButton(
                onPressed: onRead,
                icon: Icons.done_rounded,
                label: 'Read',
                tooltip: 'Mark as read',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                onPressed: onSave,
                icon: Icons.bookmark_add_rounded,
                label: 'Save',
                tooltip: 'Save article',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                onPressed: onNext,
                icon: Icons.skip_next_rounded,
                label: 'Next',
                tooltip: 'Skip to next article',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.tooltip,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurfaceVariant,
          side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(42),
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _EmptySwipeState extends StatelessWidget {
  const _EmptySwipeState({required this.onCtaPressed});

  final VoidCallback onCtaPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_rounded,
              size: 52,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing to catch up',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Add an RSS feed or share an article to start swiping.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCtaPressed,
              icon: const Icon(Icons.rss_feed_rounded),
              label: const Text('Add Feed'),
            ),
          ],
        ),
      ),
    );
  }
}
