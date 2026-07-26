import 'package:flutter/material.dart';

import 'package:readright/config/config.dart';
import 'package:readright/widgets/student_base_scaffold.dart';

/// A single playable activity shown on the Games hub.
///
/// To add a new game to the hub later, add one more _GameEntry to the
/// `games` list in [GamesHubPage.build] below — nothing else on this
/// screen needs to change.
class _GameEntry {
  final String emoji;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _GameEntry({
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
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
        description: 'Say your words out loud and get feedback.',
        color: Color(AppConfig.primaryColor),
        onTap: () => Navigator.pushNamed(context, '/practice'),
      ),
      _GameEntry(
        // Fun name for the "Tap the Word" game — easy to rename, this
        // string is the only place it appears.
        emoji: '🎯',
        title: 'Sound Pop!',
        description: 'Listen for the word, then tap it!',
        color: Colors.deepPurple,
        onTap: () => Navigator.pushNamed(context, '/tapTheWord'),
      ),
      // Add future games here, e.g.:
      // _GameEntry(
      //   emoji: '📝',
      //   title: 'Fill in the Blank',
      //   description: 'Pick the word that finishes the sentence.',
      //   color: Colors.teal,
      //   onTap: () => Navigator.pushNamed(context, '/fillInTheBlank'),
      // ),
    ];

    return StudentBaseScaffold(
      currentIndex: 1,
      pageTitle: 'Games',
      pageIcon: Icons.sports_esports,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Pick a game to play!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ...games.map(
              (game) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _GameCard(game: game),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final _GameEntry game;

  const _GameCard({required this.game});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: game.color,
      borderRadius: BorderRadius.circular(16),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: game.onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Text(game.emoji, style: const TextStyle(fontSize: 44)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      game.description,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}
