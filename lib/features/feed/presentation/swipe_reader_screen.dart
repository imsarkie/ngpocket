import 'dart:async';

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
  const SwipeReaderScreen({super.key});

  @override
  ConsumerState<SwipeReaderScreen> createState() => _SwipeReaderScreenState();
}

class _SwipeReaderScreenState extends ConsumerState<SwipeReaderScreen> {
  final CardSwiperController _controller = CardSwiperController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(swipeQueueProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? const [Color(0xFF184E68), Color(0xFF0F1C24)]
          : const [Color(0xFFE9F3F4), Color(0xFFDCEEF0)],
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Swipe Reader')),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
            child: queueAsync.when(
              data: (articles) {
                if (articles.isEmpty) {
                  return const _EmptySwipeState();
                }

                return Column(
                  children: [
                    Expanded(
                      child: CardSwiper(
                        controller: _controller,
                        cardsCount: articles.length,
                        numberOfCardsDisplayed: articles.length.clamp(1, 2),
                        backCardOffset: const Offset(0, 16),
                        maxAngle: 14,
                        allowedSwipeDirection: const AllowedSwipeDirection.only(
                          left: true,
                          right: true,
                          up: true,
                          down: true,
                        ),
                        onSwipe: (previousIndex, currentIndex, direction) {
                          final article = articles[previousIndex];
                          return _handleSwipe(article, direction);
                        },
                        cardBuilder:
                            (
                              context,
                              index,
                              horizontalThresholdPercentage,
                              verticalThresholdPercentage,
                            ) {
                              final article = articles[index];
                              return ArticleSwipeCard(
                                article: article,
                                onTap: () => _openArticle(article),
                                horizontalSwipePercent:
                                    horizontalThresholdPercentage.toDouble(),
                                verticalSwipePercent:
                                    verticalThresholdPercentage.toDouble(),
                              );
                            },
                      ),
                    ),
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
    );
  }

  bool _handleSwipe(Article article, CardSwiperDirection direction) {
    final actions = ref.read(feedActionsProvider);
    final haptics = ref.read(hapticServiceProvider);

    switch (direction) {
      case CardSwiperDirection.left:
        haptics.light();
        unawaited(actions.markRead(article.id, true));
      case CardSwiperDirection.right:
        haptics.medium();
        unawaited(actions.saveAndScrapeArticle(article));
        unawaited(haptics.success());
      case CardSwiperDirection.bottom:
        haptics.selection();
        _controller.undo();
        return false;
      case CardSwiperDirection.top:
        haptics.selection();
        break;
      case CardSwiperDirection.none:
        break;
    }

    return true;
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
}

class _EmptySwipeState extends StatelessWidget {
  const _EmptySwipeState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              'Your reading queue is empty',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Add an RSS feed or share an article to start swiping.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(
                  alpha: isDark ? 0.82 : 0.72,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
