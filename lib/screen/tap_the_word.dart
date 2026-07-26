import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:readright/config/config.dart';
import 'package:readright/models/word.dart';
import 'package:readright/widgets/student_base_scaffold.dart';

/// MVP for the "Tap the Word" game.
///
/// Flow: the app speaks a Dolch word aloud, the student sees 3 word
/// buttons (1 correct + 2 distractors pulled from the same Dolch list)
/// and taps one. The screen then shows correct/incorrect feedback with
/// a "Play Again" button.
///
/// MVP NOTE: the target word's text is also shown on screen (not just
/// spoken) so it's easy to confirm the TTS + button logic works while
/// testing. The real "hear it, don't see it" version this game design
/// was meant for just removes the `Text(_targetWord?.text ...)` widget
/// in `_buildQuestion()` below — everything else stays the same.
class TapTheWordPage extends StatefulWidget {
  final bool testMode;

  const TapTheWordPage({super.key, this.testMode = false});

  @override
  State<TapTheWordPage> createState() => _TapTheWordPageState();
}

class _TapTheWordPageState extends State<TapTheWordPage> {
  final FlutterTts textspeech = FlutterTts();
  final Random _rand = Random();

  // Static fallback pool so this screen can be opened and tested even
  // without being logged in / having a current Dolch list set up yet.
  static final List<Word> _fallbackPool = [
    Word(id: 'fallback-1', text: 'the', type: 'word', sentences: []),
    Word(id: 'fallback-2', text: 'and', type: 'word', sentences: []),
    Word(id: 'fallback-3', text: 'said', type: 'word', sentences: []),
    Word(id: 'fallback-4', text: 'play', type: 'word', sentences: []),
    Word(id: 'fallback-5', text: 'look', type: 'word', sentences: []),
    Word(id: 'fallback-6', text: 'went', type: 'word', sentences: []),
    Word(id: 'fallback-7', text: 'come', type: 'word', sentences: []),
    Word(id: 'fallback-8', text: 'little', type: 'word', sentences: []),
  ];

  bool _loading = true;
  Word? _targetWord;
  List<Word> _options = [];

  bool _answered = false;
  Word? _selectedWord;
  bool _isCorrect = false;

  @override
  void initState() {
    super.initState();
    _loadRound();
  }

  @override
  void dispose() {
    textspeech.stop();
    super.dispose();
  }

  // Speech helper — same setup as wordSpeech() in practice.dart
  Future<void> _speakTarget() async {
    if (_targetWord == null) return;
    await textspeech.setLanguage('en-US');
    await textspeech.setPitch(1.3);
    await textspeech.setSpeechRate(.45);
    await textspeech.speak(_targetWord!.text);
  }

  Future<List<Word>> _fetchWordPool() async {
    if (widget.testMode) return _fallbackPool;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return _fallbackPool;

      final listResult = await Supabase.instance.client.rpc(
        'get_current_list_for_student',
        params: {'user_id_input': user.id},
      );

      String? listId;
      if (listResult is List && listResult.isNotEmpty) {
        listId = listResult.first['list_id'] as String?;
      } else if (listResult is Map<String, dynamic>) {
        listId = listResult['list_id'] as String?;
      }

      if (listId == null) return _fallbackPool;

      final rows = await Supabase.instance.client
          .from('words')
          .select('id,text,type,sentences')
          .eq('list_id', listId)
          .limit(15);

      final pool = rows
          .map<Word>((w) => Word(
                id: w['id'],
                text: w['text'],
                type: w['type'],
                sentences: (w['sentences'] as List?)?.cast<String>() ?? [],
              ))
          .toList();

      return pool.length >= 3 ? pool : _fallbackPool;
    } catch (_) {
      return _fallbackPool;
    }
  }

  Future<void> _loadRound() async {
    setState(() {
      _loading = true;
      _answered = false;
      _selectedWord = null;
      _isCorrect = false;
    });

    final pool = await _fetchWordPool();
    final shuffled = [...pool]..shuffle(_rand);

    // Dedupe by text so we never show two buttons with the same word.
    final chosen = <Word>[];
    for (final w in shuffled) {
      if (chosen.any((c) => c.text.toLowerCase() == w.text.toLowerCase())) {
        continue;
      }
      chosen.add(w);
      if (chosen.length == 3) break;
    }

    // Safety net: if the real data somehow didn't have 3 distinct words,
    // fall back to the static pool so the game never gets stuck.
    if (chosen.length < 3) {
      chosen
        ..clear()
        ..addAll(_fallbackPool.take(3));
    }

    final target = chosen[_rand.nextInt(chosen.length)];

    setState(() {
      _targetWord = target;
      _options = chosen;
      _loading = false;
    });

    // Speak the word as soon as the round loads.
    _speakTarget();
  }

  void _handleSelect(Word selected) {
    if (_answered) return;
    setState(() {
      _answered = true;
      _selectedWord = selected;
      _isCorrect = selected.id == _targetWord!.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StudentBaseScaffold(
      currentIndex: 1,
      pageTitle: 'Tap the Word',
      pageIcon: Icons.hearing,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: _answered ? _buildFeedback() : _buildQuestion(),
                ),
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.volume_up,
          size: 64,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        const Text(
          'Listen and tap the matching word!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),

        // MVP visual aid — see the class doc comment at the top of this
        // file for how to remove this for the audio-only version.
        Text(
          _targetWord?.text ?? '',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),

        const SizedBox(height: 16),

        ElevatedButton.icon(
          onPressed: _speakTarget,
          icon: const Icon(Icons.replay),
          label: const Text('Hear it again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(AppConfig.primaryColor),
            foregroundColor: Colors.white,
            minimumSize: const Size(220, 50),
          ),
        ),

        const SizedBox(height: 36),

        ..._options.map(
          (word) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              width: 240,
              height: 60,
              child: ElevatedButton(
                onPressed: () => _handleSelect(word),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(AppConfig.secondaryColor),
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  word.text,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedback() {
    final message = _isCorrect ? 'Great job!' : 'Not quite!';
    final emoji = _isCorrect ? '🌟' : '😊';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 70)),
        const SizedBox(height: 20),
        Text(
          message,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          _isCorrect
              ? 'You picked "${_selectedWord!.text}" correctly.'
              : 'The word was "${_targetWord!.text}". You picked "${_selectedWord!.text}".',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: _loadRound,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(230, 55),
            backgroundColor: Color(AppConfig.primaryColor),
            foregroundColor: Colors.white,
          ),
          child: const Text('Play Again', style: TextStyle(fontSize: 22)),
        ),
      ],
    );
  }
}
