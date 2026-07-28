import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:readright/config/theme.dart';
import 'package:readright/widgets/bloom_mascot.dart';
import 'package:readright/widgets/student_base_scaffold.dart';

/// A single playable activity shown on the Games hub.
class _GameEntry {
  final String emoji;
  final String title;
  final String description;
  final Color surface;
  final Color edge;
  final Color ink;

  /// Null means the card is a placeholder: it still presses and buzzes, it
  /// just doesn't go anywhere yet.
  final VoidCallback? onTap;

  const _GameEntry({
    required this.emoji,
    required this.title,
    required this.description,
    required this.surface,
    required this.edge,
    required this.ink,
    this.onTap,
  });
}

/// Hub screen shown from the "Games" tab in the bottom nav. Lists every
/// playable activity — pronunciation Practice, Tap the Word, and any
/// future games — as a tappable card.
class GamesHubPage extends StatelessWidget {
  const GamesHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final games = <_GameEntry>[
      _GameEntry(
        emoji: '🎤',
        title: 'Practice',
        description: 'Say your words out loud.',
        surface: RRColor.mintSurface,
        edge: RRColor.mint,
        ink: RRColor.mintInk,
        onTap: () => Navigator.pushNamed(context, '/practice'),
      ),
      _GameEntry(
        // Fun name for the "Tap the Word" game — easy to rename, this
        // string is the only place it appears.
        emoji: '🎯',
        title: 'Sound Pop!',
        description: 'Listen, then tap the word.',
        surface: RRColor.skySurface,
        edge: RRColor.sky,
        ink: RRColor.skyInk,
        onTap: () => Navigator.pushNamed(context, '/tapTheWord'),
      ),
      const _GameEntry(
        emoji: '📖',
        title: 'Stories',
        description: 'Read a story with Bloom.',
        surface: RRColor.blossomSurface,
        edge: RRColor.blossom,
        ink: RRColor.blossomInk,
        // TODO: wire up when the story generator lands.
        // onTap: () => Navigator.pushNamed(context, '/stories'),
        onTap: null,
      ),
      // Add future games here, e.g.:
      // _GameEntry(
      //   emoji: '📝',
      //   title: 'Fill in the Blank',
      //   description: 'Pick the word that finishes the sentence.',
      //   surface: RRColor.lilacSurface,
      //   edge: RRColor.lilac,
      //   ink: RRColor.lilacInk,
      //   onTap: () => Navigator.pushNamed(context, '/fillInTheBlank'),
      // ),
    ];

    return StudentBaseScaffold(
      currentIndex: 1,
      pageTitle: 'Games',
      pageIcon: Icons.sports_esports_rounded,
      body: Container(
        color: RRColor.canvas,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            children: [
              const _PlayHeader(),
              const SizedBox(height: 24),
              for (final game in games) ...[
                _GameCard(game: game),
                const SizedBox(height: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header — Bloom mid-game.
//
// Bloom sits behind a controller with sparks coming off it, which is the
// clearest way to say 'this is the play screen' to someone who can't read the
// word Games in the app bar.
// ---------------------------------------------------------------------------
class _PlayHeader extends StatelessWidget {
  const _PlayHeader();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Pick a game to play',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        decoration: BoxDecoration(
          color: RRColor.card,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: RRColor.lilac, width: 3),
          boxShadow: RRShape.lift(RRColor.lilac),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 132,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const BloomMascot(size: 116, mood: BloomMood.cheer),

                  // The controller Bloom is playing with.
                  Positioned(
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: RRColor.blossom,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: RRShape.lift(RRColor.blossom),
                      ),
                      child: const Icon(Icons.sports_esports_rounded,
                          size: 28, color: Colors.white),
                    ),
                  ),

                  // Sparks. Small, off-centre, and unmatched so the moment
                  // reads as motion rather than decoration.
                  const Positioned(
                    left: 24,
                    top: 14,
                    child: Icon(Icons.star_rounded,
                        size: 22, color: RRColor.sunny),
                  ),
                  const Positioned(
                    right: 18,
                    top: 34,
                    child: Icon(Icons.star_rounded,
                        size: 16, color: RRColor.skyGlow),
                  ),
                  const Positioned(
                    right: 46,
                    top: 4,
                    child: Icon(Icons.star_rounded,
                        size: 12, color: RRColor.mint),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'What do you want to play?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: RRFont.display,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.15,
                color: RRColor.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Game card
//
// Was a flat Material + InkWell in a saturated fill with white text. A ripple
// is a weak confirmation on a device a child is holding at arm's length, and
// white-on-deepPurple was the only thing separating the two games. Now each
// card is its own object, and the press is scale + shadow + haptic.
// ---------------------------------------------------------------------------
class _GameCard extends StatefulWidget {
  final _GameEntry game;

  const _GameCard({required this.game});

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
    if (v) HapticFeedback.mediumImpact();
  }

  void _tap() {
    final onTap = widget.game.onTap;
    if (onTap == null) return;
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      button: true,
      label: '${game.title}. ${game.description}',
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: _tap,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: Duration(milliseconds: reduceMotion ? 0 : 110),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: Duration(milliseconds: reduceMotion ? 0 : 110),
            height: 116,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: game.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: game.edge, width: 3),
              boxShadow: RRShape.lift(game.edge, pressed: _pressed),
            ),
            child: Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Text(game.emoji, style: const TextStyle(fontSize: 38)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.title,
                        style: TextStyle(
                          fontFamily: RRFont.display,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          color: game.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        game.description,
                        style: TextStyle(
                          fontFamily: RRFont.reader,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: game.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: game.ink, size: 34),
              ],
            ),
          ),
        ),
      ),
    );
  }
}