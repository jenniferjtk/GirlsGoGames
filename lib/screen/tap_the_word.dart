import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:readright/config/config.dart';
import 'package:readright/models/word.dart';
import 'package:readright/widgets/student_base_scaffold.dart';

/// Number of words in a single "Tap the Word" round.
const int kWordsPerRound = 3;

enum _RoundStage { loading, question, feedback, summary }

/// One question in a round: a target word to listen for, and the set of
/// tappable options (the target + 2 distractors) shown for it.
class _RoundQuestion {
  final Word target;
  final List<Word> options;

  _RoundQuestion({required this.target, required this.options});
}

/// "Tap the Word" game — MVP.
///
/// A round is [kWordsPerRound] words long. For each word, the app speaks
/// it aloud — the printed word is intentionally hidden during the
/// question, so audio is the only cue, matching the "hear it, don't see
/// it" design this game targets. The student taps the matching option
/// out of 3 buttons (1 correct + 2 distractors pulled from the same
/// Dolch list). After each pick, a feedback screen reveals the word
/// (print + a repeated audio readout) using minimal, non-sentence text
/// so a pre-reading student can follow along. After all words in the
/// round are answered, a round-summary screen shows a star for each
/// word (filled if correct) plus how many the student got right, with
/// a "Play Again" button to start a fresh round.
class TapTheWordPage extends StatefulWidget {
  final bool testMode;

  const TapTheWordPage({super.key, this.testMode = false});

  @override
  State<TapTheWordPage> createState() => _TapTheWordPageState();
}

class _TapTheWordPageState extends State<TapTheWordPage> {
  final FlutterTts textspeech = FlutterTts();
  final Random _rand = Random();
  late final ConfettiController _confettiController;

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

  _RoundStage _stage = _RoundStage.loading;

  List<_RoundQuestion> _questions = [];
  List<bool?> _questionResults = List.filled(kWordsPerRound, null);
  int _currentIndex = 0;

  Word? _selectedWord;
  bool _isCorrect = false;

  int get _score => _questionResults.where((r) => r == true).length;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _startNewRound();
  }

  @override
  void dispose() {
    textspeech.stop();
    _confettiController.dispose();
    super.dispose();
  }

  // Speech helper — same setup as wordSpeech() in practice.dart
  Future<void> _speak(String text) async {
    await textspeech.setLanguage('en-US');
    await textspeech.setPitch(1.3);
    await textspeech.setSpeechRate(.45);
    await textspeech.speak(text);
  }

  Future<void> _speakCurrent() async {
    if (_questions.isEmpty) return;
    await _speak(_questions[_currentIndex].target.text);
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

  /// Builds a fresh set of [kWordsPerRound] questions (each with 3 unique
  /// options), and resets round progress.
  Future<void> _startNewRound() async {
    setState(() {
      _stage = _RoundStage.loading;
      _currentIndex = 0;
      _questionResults = List.filled(kWordsPerRound, null);
      _selectedWord = null;
      _isCorrect = false;
    });

    final pool = await _fetchWordPool();

    // Dedupe by text so we never treat two spellings of the same word as
    // different options.
    final distinct = <Word>[];
    for (final w in [...pool]..shuffle(_rand)) {
      if (distinct.any((d) => d.text.toLowerCase() == w.text.toLowerCase())) {
        continue;
      }
      distinct.add(w);
    }

    // Safety net: make sure there are enough distinct words for a full
    // round, padding from the fallback pool if the real data came up short.
    if (distinct.length < kWordsPerRound) {
      for (final w in _fallbackPool) {
        if (distinct.any((d) => d.text.toLowerCase() == w.text.toLowerCase())) {
          continue;
        }
        distinct.add(w);
        if (distinct.length >= kWordsPerRound) break;
      }
    }

    final targets = distinct.take(kWordsPerRound).toList();

    final questions = <_RoundQuestion>[];
    for (final target in targets) {
      final distractorPool = distinct
          .where((w) => w.text.toLowerCase() != target.text.toLowerCase())
          .toList()
        ..shuffle(_rand);

      final distractors = distractorPool.take(2).toList();

      // Safety net: pad from the fallback pool if this specific target
      // somehow doesn't have 2 distinct distractors available.
      if (distractors.length < 2) {
        for (final w in _fallbackPool) {
          if (w.text.toLowerCase() == target.text.toLowerCase()) continue;
          if (distractors
              .any((d) => d.text.toLowerCase() == w.text.toLowerCase())) {
            continue;
          }
          distractors.add(w);
          if (distractors.length >= 2) break;
        }
      }

      final options = [target, ...distractors]..shuffle(_rand);
      questions.add(_RoundQuestion(target: target, options: options));
    }

    setState(() {
      _questions = questions;
      _stage = _RoundStage.question;
    });

    _speakCurrent();
  }

  void _handleSelect(Word selected) {
    if (_stage != _RoundStage.question) return;

    final target = _questions[_currentIndex].target;
    final correct = selected.id == target.id;

    setState(() {
      _selectedWord = selected;
      _isCorrect = correct;
      _questionResults[_currentIndex] = correct;
      _stage = _RoundStage.feedback;
    });

    // Say the word again as part of the feedback — the reveal below is
    // just the single word (not a sentence), but a pre-reading student
    // still needs to hear it to know what it says.
    _speak(target.text);
  }

  void _goToNext() {
    final isLastQuestion = _currentIndex == _questions.length - 1;

    if (isLastQuestion) {
      setState(() {
        _stage = _RoundStage.summary;
      });
      if (_score >= (_questions.length / 2).ceil()) {
        _confettiController.play();
      }
      return;
    }

    setState(() {
      _currentIndex++;
      _selectedWord = null;
      _isCorrect = false;
      _stage = _RoundStage.question;
    });

    _speakCurrent();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    switch (_stage) {
      case _RoundStage.loading:
        content = const Center(child: CircularProgressIndicator());
        break;
      case _RoundStage.question:
        content = Center(child: _buildQuestion());
        break;
      case _RoundStage.feedback:
        content = Center(child: _buildQuestionFeedback());
        break;
      case _RoundStage.summary:
        content = Center(child: _buildRoundSummary());
        break;
    }

    return StudentBaseScaffold(
      currentIndex: 1,
      pageTitle: 'Tap the Word',
      pageIcon: Icons.hearing,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: content,
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
            ),
          ),
        ],
      ),
    );
  }

  /// Row of per-word progress indicators shown during a round: filled
  /// green check for a correct answer, red X for incorrect, a highlighted
  /// dot for the current word, and a hollow dot for words not reached yet.
  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_questions.length, (i) {
        final result = _questionResults[i];
        IconData icon;
        Color color;

        if (result == true) {
          icon = Icons.check_circle;
          color = Colors.green;
        } else if (result == false) {
          icon = Icons.cancel;
          color = Colors.redAccent;
        } else if (i == _currentIndex) {
          icon = Icons.radio_button_checked;
          color = Color(AppConfig.primaryColor);
        } else {
          icon = Icons.circle_outlined;
          color = Colors.grey;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(icon, color: color, size: 28),
        );
      }),
    );
  }

  Widget _buildQuestion() {
    final question = _questions[_currentIndex];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildProgressDots(),
        const SizedBox(height: 8),
        Text(
          'Word ${_currentIndex + 1} of ${_questions.length}',
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Listen and tap the matching word!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 28),

        // Big, emoji-only "hear it again" button — no text label, since a
        // young reader may not be able to read one yet. The word itself
        // is intentionally NOT shown as text here; audio is the only cue.
        ElevatedButton(
          onPressed: _speakCurrent,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(AppConfig.primaryColor),
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            minimumSize: const Size(140, 140),
            elevation: 4,
          ),
          child: const Text('🔊', style: TextStyle(fontSize: 56)),
        ),

        const SizedBox(height: 36),

        ...question.options.map(
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

  Widget _buildQuestionFeedback() {
    final target = _questions[_currentIndex].target;
    final isLastQuestion = _currentIndex == _questions.length - 1;

    // Kept intentionally short (no full sentences) so a student who
    // can't yet read sentences can still follow along using the emoji
    // and the single word reveal below.
    final emoji = _isCorrect ? '🎉' : '💪';
    final message = _isCorrect ? 'Correct!' : 'Try Again!';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildProgressDots(),
        const SizedBox(height: 24),
        Text(emoji, style: const TextStyle(fontSize: 72)),
        const SizedBox(height: 16),
        Text(
          message,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        // Reveal the word itself — a single word, not a sentence — so a
        // pre-reading student gets a print + sound pairing as the answer.
        Text(
          target.text,
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),

        const SizedBox(height: 36),
        ElevatedButton(
          onPressed: _goToNext,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(230, 60),
            backgroundColor: Color(AppConfig.primaryColor),
            foregroundColor: Colors.white,
          ),
          // Emoji included so a child who can't read the label yet can
          // still recognize the "go forward" action.
          child: Text(
            isLastQuestion ? 'See Results 🎉' : 'Next Word ➡️',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildRoundSummary() {
    final total = _questions.length;
    final score = _score;

    String title;
    String emoji;

    if (score == total) {
      title = 'Perfect Round!';
      emoji = '🏆';
    } else if (score >= (total / 2).ceil()) {
      title = 'Great Job!';
      emoji = '🌟';
    } else if (score > 0) {
      title = 'Nice Try!';
      emoji = '💪';
    } else {
      title = 'Keep Practicing!';
      emoji = '😊';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 70)),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        // One star per word in the round; filled gold = correct.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(total, (i) {
            final correct = _questionResults[i] == true;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                correct ? Icons.star : Icons.star_border,
                size: 48,
                color: correct ? Colors.amber : Colors.grey,
              ),
            );
          }),
        ),

        const SizedBox(height: 16),

        Text(
          'You got $score out of $total words right!',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 40),

        ElevatedButton(
          onPressed: _startNewRound,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(230, 55),
            backgroundColor: Color(AppConfig.primaryColor),
            foregroundColor: Colors.white,
          ),
          child: const Text(
            'Play Again 🔄',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}