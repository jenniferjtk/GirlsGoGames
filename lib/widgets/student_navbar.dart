import 'package:flutter/material.dart';

import 'package:readright/config/theme.dart';

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String emoji;
  final Color surface;
  final Color ink;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.emoji,
    required this.surface,
    required this.ink,
  });
}

class StudentNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const StudentNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  // Ordered by how often a child needs them, left to right. Games sits in the
  // middle, under the thumb's natural resting arc.
  static const List<_NavItem> _items = [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
      emoji: '🏡',
      surface: RRColor.mintSurface,
      ink: RRColor.mintInk,
    ),
    _NavItem(
      icon: Icons.sports_esports_outlined,
      activeIcon: Icons.sports_esports_rounded,
      label: 'Games',
      emoji: '🎮',
      surface: RRColor.blossomSurface,
      ink: RRColor.blossomInk,
    ),
    _NavItem(
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book_rounded,
      label: 'Words',
      emoji: '📖',
      surface: RRColor.skySurface,
      ink: RRColor.skyInk,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Any stale index — including the old Progress tab at 3 — lands on Home.
    final safeIndex =
        (currentIndex >= 0 && currentIndex < _items.length) ? currentIndex : 0;

    return Container(
      decoration: BoxDecoration(
        color: RRColor.card,
        border: const Border(
          top: BorderSide(color: RRColor.lilac, width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: RRColor.lilac.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Row(
            children: List.generate(
              _items.length,
              (i) => Expanded(
                child: _NavButton(
                  item: _items[i],
                  selected: i == safeIndex,
                  onTap: () => onTap(i),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final selected = widget.selected;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: Duration(milliseconds: reduceMotion ? 0 : 110),
          curve: Curves.easeOut,
          child: Center(
            child: AnimatedContainer(
              duration: Duration(milliseconds: reduceMotion ? 0 : 160),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                // The selected state is a filled pill with a hard edge, so it
                // survives greyscale and low vision.
                color: selected ? item.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected ? item.ink : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? item.activeIcon : item.icon,
                    size: 28,
                    color: selected ? item.ink : RRColor.inkSoft,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontFamily: RRFont.display,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? item.ink : RRColor.inkSoft,
                    ),
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