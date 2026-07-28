// lib/widgets/teacher_navbar.dart
//
// Four tabs: Class / Students / Words / Stories.
//
// Settings is gone — its only content was a per-student audio-retention
// toggle, which is student management, and it now lives on the student detail
// screen. That freed the slot for Stories, which was previously a button at the
// bottom of a long dashboard scroll.
//
// Hand-built Row rather than BottomNavigationBar, matching the student nav:
// selection is a filled pill with a hard edge plus an outlined-to-filled icon
// swap, so it survives greyscale and low vision instead of relying on a colour
// change alone. Sizing is a notch tighter than the student bar — this is an
// adult tool, so the oversized targets aren't needed.
//
// Public API (currentIndex, onTap) is unchanged.

import 'package:flutter/material.dart';

import 'package:readright/config/theme.dart';

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color surface;
  final Color ink;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.surface,
    required this.ink,
  });
}

class TeacherNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const TeacherNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const List<_NavItem> _items = [
    _NavItem(
      icon: Icons.insights_outlined,
      activeIcon: Icons.insights_rounded,
      label: 'Class',
      surface: RRColor.mintSurface,
      ink: RRColor.mintInk,
    ),
    _NavItem(
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
      label: 'Students',
      surface: RRColor.skySurface,
      ink: RRColor.skyInk,
    ),
    _NavItem(
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book_rounded,
      label: 'Words',
      surface: RRColor.blossomSurface,
      ink: RRColor.blossomInk,
    ),
    _NavItem(
      icon: Icons.auto_stories_outlined,
      activeIcon: Icons.auto_stories_rounded,
      label: 'Stories',
      surface: RRColor.sunnyGlow,
      ink: RRColor.sunnyInk,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Prevent index overflow.
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
          height: 68,
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
          scale: _pressed ? 0.93 : 1.0,
          duration: Duration(milliseconds: reduceMotion ? 0 : 110),
          curve: Curves.easeOut,
          child: Center(
            child: AnimatedContainer(
              duration: Duration(milliseconds: reduceMotion ? 0 : 160),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? item.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
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
                    size: 24,
                    color: selected ? item.ink : RRColor.inkSoft,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontFamily: RRFont.display,
                      fontSize: 13,
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