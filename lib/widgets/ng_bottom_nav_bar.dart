import 'package:flutter/material.dart';
import 'package:ngpocket/widgets/unread_badge.dart';

double navBarHeightFor(BuildContext context) {
  final media = MediaQuery.of(context);
  final shortestSide = media.size.shortestSide;
  final bottomInset = media.padding.bottom;

  final railHeight = (shortestSide * 0.16).clamp(56.0, 64.0);
  final verticalInset = (shortestSide * 0.02).clamp(4.0, 8.0);

  return railHeight + (verticalInset * 2) + bottomInset;
}

class NgBottomNavBar extends StatelessWidget {
  const NgBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.unreadCount,
    required this.onTabSelected,
  });

  final int currentIndex;
  final int unreadCount;
  final ValueChanged<int> onTabSelected;

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
                  final indicatorWidth =
                      (constraints.maxWidth - (indicatorInset * 2)) / itemCount;

                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeInOutCubicEmphasized,
                        left: indicatorInset + (indicatorWidth * currentIndex),
                        top: indicatorInset,
                        bottom: indicatorInset,
                        width: indicatorWidth,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: colorScheme.primary.withValues(alpha: 0.2),
                            border: Border.all(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _LiquidNavButton(
                            icon: Icons.bookmark_rounded,
                            selected: currentIndex == 0,
                            onTap: () => onTabSelected(0),
                          ),
                          _LiquidNavButton(
                            icon: Icons.auto_stories_rounded,
                            selected: currentIndex == 1,
                            highlighted: true,
                            onTap: () => onTabSelected(1),
                          ),
                          _LiquidNavButton(
                            icon: Icons.format_list_bulleted_rounded,
                            selected: currentIndex == 2,
                            onTap: () => onTabSelected(2),
                            iconBuilder: (icon, color) => UnreadBadge(
                              count: unreadCount,
                              child: Icon(icon, color: color),
                            ),
                          ),
                          _LiquidNavButton(
                            icon: Icons.settings_rounded,
                            selected: currentIndex == 3,
                            onTap: () => onTabSelected(3),
                          ),
                        ],
                      ),
                    ],
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
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                scale: selected ? (highlighted ? 1.07 : 1.04) : 0.96,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
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
