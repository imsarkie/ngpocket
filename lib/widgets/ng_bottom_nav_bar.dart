import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:reader/widgets/unread_badge.dart';

double navBarHeightFor(BuildContext context) {
  final media = MediaQuery.of(context);
  final shortestSide = media.size.shortestSide;
  final bottomInset = media.padding.bottom;

  final railHeight = (shortestSide * 0.16).clamp(56.0, 64.0);
  final verticalInset = (shortestSide * 0.02).clamp(4.0, 8.0);

  return railHeight + (verticalInset * 2) + bottomInset;
}

class NgBottomNavBar extends StatefulWidget {
  const NgBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.unreadCount,
    required this.onTabSelected,
    this.onDragProgress,
    this.onDragRelease,
  });

  final int currentIndex;
  final int unreadCount;
  final ValueChanged<int> onTabSelected;
  final ValueChanged<double>? onDragProgress;
  final void Function(int index, double velocityX)? onDragRelease;

  @override
  State<NgBottomNavBar> createState() => _NgBottomNavBarState();
}

class _NgBottomNavBarState extends State<NgBottomNavBar> {
  static const double _dragIntentThreshold = 10;
  static const double _flingVelocityThreshold = 760;

  bool _isDraggingSelector = false;
  double? _dragLocalDx;
  double? _dragStartDx;

  int _indexFromDx(double localDx, double width, int itemCount) {
    if (width <= 0) {
      return widget.currentIndex;
    }
    final raw = (localDx / width * itemCount).floor();
    return raw.clamp(0, itemCount - 1);
  }

  double _selectorLeftFromDx(
    double localDx,
    double indicatorWidth,
    double maxLeft,
  ) {
    final left = localDx - (indicatorWidth / 2);
    return left.clamp(0, maxLeft);
  }

  double _pageProgressFromDx(double localDx, double width, int itemCount) {
    if (width <= 0) {
      return widget.currentIndex.toDouble();
    }
    final clampedDx = localDx.clamp(0, width);
    final normalized = clampedDx / width;
    return normalized * (itemCount - 1);
  }

  int _releaseIndexWithVelocity({
    required double dragDx,
    required double railWidth,
    required double velocityX,
    required int itemCount,
  }) {
    final nearestIndex = _indexFromDx(dragDx, railWidth, itemCount);
    
    if (velocityX.abs() < _flingVelocityThreshold) {
      return nearestIndex;
    }

    // A deliberate swipe should just move to the next immediate item.
    final flingDirection = velocityX.isNegative ? -1 : 1;
    return (nearestIndex + flingDirection).clamp(0, itemCount - 1);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final shortestSide = media.size.shortestSide;
    final colorScheme = Theme.of(context).colorScheme;

    final horizontalInset = (shortestSide * 0.03).clamp(10.0, 14.0);
    final topInset = (shortestSide * 0.02).clamp(4.0, 8.0);
    final bottomSafeInset = media.padding.bottom;
    final bottomInset = (shortestSide * 0.02).clamp(4.0, 8.0);
    final railHeight = (shortestSide * 0.16).clamp(56.0, 64.0);
    final railBorderRadius = (railHeight * 0.28).clamp(14.0, 18.0);

    return Material(
      color: colorScheme.surface,
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalInset,
          topInset,
          horizontalInset,
          bottomSafeInset + bottomInset,
        ),
        child: SizedBox(
          height: railHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(railBorderRadius),
              color: colorScheme.surface,
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.38),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const itemCount = 4;
                  const indicatorInset = 2.0;
                  final rawRailWidth =
                      constraints.maxWidth - (indicatorInset * 2);
                  final railWidth = math.max(0.0, rawRailWidth);
                  final indicatorWidth = railWidth / itemCount;
                  final maxLeft = math.max(0.0, railWidth - indicatorWidth);

                  final minDragDx = indicatorInset;
                  final maxDragDx = math.max(
                    minDragDx,
                    constraints.maxWidth - indicatorInset,
                  );

                  final dragDx = (_dragLocalDx ?? 0).clamp(
                    minDragDx,
                    maxDragDx,
                  );

                  final pageProgress = _pageProgressFromDx(
                    dragDx - indicatorInset,
                    railWidth,
                    itemCount,
                  );

                  final previewIndex = _isDraggingSelector
                      ? _indexFromDx(
                          dragDx - indicatorInset,
                          railWidth,
                          itemCount,
                        )
                      : widget.currentIndex;

                  final selectorLeft = _isDraggingSelector
                      ? indicatorInset +
                            _selectorLeftFromDx(
                              dragDx - indicatorInset,
                              indicatorWidth,
                              maxLeft,
                            )
                      : indicatorInset + (indicatorWidth * widget.currentIndex);

                  final pageFraction =
                      pageProgress - pageProgress.floorToDouble();
                  final centerAffinity = (1 - ((pageFraction - 0.5).abs() * 2))
                      .clamp(0.0, 1.0);
                  final stretchScale = _isDraggingSelector
                      ? (1 + (0.11 * centerAffinity))
                      : 1.0;
                  final stretchedIndicatorWidth = indicatorWidth * stretchScale;
                  final selectorCenterX = selectorLeft + (indicatorWidth / 2);
                  final stretchedLeft =
                      (selectorCenterX - (stretchedIndicatorWidth / 2))
                          .clamp(indicatorInset, indicatorInset + maxLeft)
                          .toDouble();

                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragStart: (details) {
                      _dragStartDx = details.localPosition.dx;

                      setState(() {
                        _isDraggingSelector = false;
                        _dragLocalDx = null;
                      });
                    },
                    onHorizontalDragUpdate: (details) {
                      final startDx = _dragStartDx ?? details.localPosition.dx;
                      final dragDelta = details.localPosition.dx - startDx;

                      if (!_isDraggingSelector &&
                          dragDelta.abs() < _dragIntentThreshold) {
                        return;
                      }

                      final localDx =
                          (details.localPosition.dx - indicatorInset).clamp(
                            0.0,
                            railWidth,
                          );

                      setState(() {
                        _isDraggingSelector = true;
                        _dragLocalDx = details.localPosition.dx;
                      });

                      widget.onDragProgress?.call(
                        _pageProgressFromDx(localDx, railWidth, itemCount),
                      );
                    },
                    onHorizontalDragEnd: (details) {
                      if (!_isDraggingSelector) {
                        _dragStartDx = null;
                        return;
                      }

                      final velocityX = details.primaryVelocity ?? 0;
                      final targetIndex = _releaseIndexWithVelocity(
                        dragDx: dragDx - indicatorInset,
                        railWidth: railWidth,
                        velocityX: velocityX,
                        itemCount: itemCount,
                      );

                      setState(() {
                        _isDraggingSelector = false;
                        _dragLocalDx = null;
                        _dragStartDx = null;
                      });

                      widget.onDragRelease?.call(targetIndex, velocityX);
                      if (widget.onDragRelease == null) {
                        widget.onTabSelected(targetIndex);
                      }
                    },
                    onHorizontalDragCancel: () {
                      setState(() {
                        _isDraggingSelector = false;
                        _dragLocalDx = null;
                        _dragStartDx = null;
                      });
                      widget.onDragProgress?.call(
                        widget.currentIndex.toDouble(),
                      );
                    },
                    child: Stack(
                      children: [
                          AnimatedPositioned(
                            duration: _isDraggingSelector
                                ? Duration.zero
                                : const Duration(milliseconds: 300),
                            curve: Curves.easeOutQuint,
                            left: stretchedLeft,
                            top: indicatorInset,
                            bottom: indicatorInset,
                            width: stretchedIndicatorWidth,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: colorScheme.primary.withValues(
                                  alpha: 0.2,
                                ),
                                border: Border.all(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            _LiquidNavButton(
                              icon: Icons.bookmark_rounded,
                              selected: previewIndex == 0,
                              onTap: () => widget.onTabSelected(0),
                            ),
                            _LiquidNavButton(
                              icon: Icons.auto_stories_rounded,
                              selected: previewIndex == 1,
                              highlighted: true,
                              onTap: () => widget.onTabSelected(1),
                            ),
                            _LiquidNavButton(
                              icon: Icons.format_list_bulleted_rounded,
                              selected: previewIndex == 2,
                              onTap: () => widget.onTabSelected(2),
                              iconBuilder: (icon, color) => UnreadBadge(
                                count: widget.unreadCount,
                                child: Icon(icon, color: color),
                              ),
                            ),
                            _LiquidNavButton(
                              icon: Icons.settings_rounded,
                              selected: previewIndex == 3,
                              onTap: () => widget.onTabSelected(3),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidNavButton extends StatelessWidget {
  const _LiquidNavButton({
    required this.icon,
    required this.selected,
    required this.onTap,
    this.highlighted = false,
    this.iconBuilder,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool highlighted;
  final Widget Function(IconData icon, Color color)? iconBuilder;

  @override
  Widget build(BuildContext context) {
    final selectedColor = Theme.of(context).colorScheme.primary;
    final defaultColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final baseIcon =
        iconBuilder?.call(icon, selected ? selectedColor : defaultColor) ??
        Icon(icon, size: 22, color: selected ? selectedColor : defaultColor);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Center(
          child: SizedBox(
            height: 48,
            child: Center(
              child: AnimatedScale(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutQuint,
                scale: selected ? (highlighted ? 1.07 : 1.04) : 0.96,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: selected ? 1 : 0.82,
                  child: baseIcon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
