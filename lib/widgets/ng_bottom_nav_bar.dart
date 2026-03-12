import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:ngpocket/widgets/unread_badge.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    return BottomAppBar(
      height: 98,
      color: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.surface.withValues(alpha: 0.28),
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                  ],
                ),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.14),
                ),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 22,
                    spreadRadius: -7,
                    offset: Offset(0, 10),
                    color: Color(0x3A000000),
                  ),
                ],
              ),
              child: Row(
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
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            height: 52,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: selected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        selectedColor.withValues(
                          alpha: highlighted ? 0.3 : 0.22,
                        ),
                        selectedColor.withValues(
                          alpha: highlighted ? 0.13 : 0.08,
                        ),
                      ],
                    ),
                    border: Border.all(
                      color: selectedColor.withValues(
                        alpha: highlighted ? 0.32 : 0.22,
                      ),
                    ),
                  )
                : null,
            child: Center(
              child: AnimatedScale(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                scale: selected ? (highlighted ? 1.11 : 1.06) : 0.96,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: selected ? 1 : 0.92,
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
