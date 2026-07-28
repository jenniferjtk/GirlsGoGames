// lib/pages/tap_the_word.dart
//
// 'Tap the Word' — listen, then pick.
//
// Design changes:
//   * Reads as a game, not a form. A round HUD with gem slots, a pulsing
//     listen disc as the centrepiece, and three answer cards that press in.
//   * Each option is visually its own object — own colour, own hard border,
//     own shadow, 18dp of air between — instead of three identical bars.
//   * Rewards land in the moment: confetti on a correct pick, Bloom cheering,
//     stars that pop in one at a time on the summary.
//   * Hardened against button mashing. Details below.
//
// BUTTON-MASH HARDENING — the one place I changed behaviour, because you asked
// for it. Four separate holes, all reachable by a six-year-old drumming on the
// screen with both hands:
//
//   1. `_goToNext` had no stage guard. Two fast taps on 'Next Word' ran it
//      twice, incrementing `_currentIndex` twice and skipping a question — or
//      running off the end of `_questions` into a RangeError.
//   2. `_startNewRound` had no re-entry guard. Mashing 'Play Again' fired
//      overlapping async pool fetches whose setStates interleaved, producing a
//      round built from two different shuffles.
//   3. Tap-through. Answer cards and the 'Next' button occupy overlapping
//      screen space across a stage change, so a tap still travelling down when
//      the stage flips lands on whatever appeared underneath it. Every stage
//      change now locks input for 450ms.
//   4. Speech pile-up. Hammering the listen disc queued utterances that played
//      over each other and kept talking into the next question. Every `_speak`
//      now stops the previous one first.
//
// Round construction, the Supabase fetch, scoring, and the two pure helpers are
// untouched.

import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:readright/config/theme.dart';
import 'package:readright/models/word.dart';
import 'package:readright/widgets/bloom_mascot.dart';
import 'package:readright/widgets/student_base_scaffold.dart';

/// Number of words in a single "Tap the Word" round.
const int kWordsPerRound = 3;

/// Removes case-insensitive duplicate words by text, keeping the first
/// occurrence of each. Pure logic, pulled out of the round-building code
/// so it can be unit tested without spinning up the widget.
List<Word> dedupeWordsByText(List<Word> words) {
  final result = <Word>[];
  for (final w in words) {
    final alreadySeen =
        result.any((d) => d.text.toLowerCase() == w.text.toLowerCase());
    if (!alreadySeen) {
      result.add(w);
    }
  }
  return result;
}

/// Picks the round-summary title and emoji for a given [score] out of
/// [total] words. Pure logic, pulled out of _buildRoundSummary so it can
/// be unit tested without spinning up the widget.
({String title, String emoji}) roundSummaryFor({
  required int score,
  required int total,
}) {
  if (total <= 0) {
    return (title: 'Keep Practicing!', emoji: '😊');
  }
  if (score == total) {
    return (title: 'Perfect Round!', emoji: '🏆');
  }
  if (score >= (total / 2).ceil()) {
    return (title: 'Great Job!', emoji: '🌟');
  }
  if (score > 0) {
    return (title: 'Nice Try!', emoji: '💪');
  }
  return (title: 'Keep Practicing!', emoji: '😊');
}

enum _RoundStage { loading, question, feedback, summary }

/// One question in a round: a target word to listen for, and the set of
/// tappable options (the target + 2 distractors) shown for it.
class _RoundQuestion {
  final Word target;
  final List<Word> options;

  _RoundQuestion({required this.target, required this.options});
}

/// Per-option colour. Three fixed tones in a fixed order, so the answer cards
/// are three distinct objects rather than three copies of one button. Position
/// and colour together give a child something to aim at.
class _OptionTone {
  final Color surface;
  final Color edge;
  final Color ink;

  const _OptionTone(this.surface, this.edge, this.ink);

  static const List<_OptionTone> all = [
    _OptionTone(RRColor.mintSurface, RRColor.mint, RRColor.mintInk),
    _OptionTone(RRColor.skySurface, RRColor.sky, RRColor.skyInk),
    _OptionTone(RRColor.blossomSurface, RRColor.blossom, RRColor.blossomInk),
  ];

  static _OptionTone of(int i) => all[i % all.length];
}

/// "Tap the Word" game.
///
/// A round is [kWordsPerRound] words long. For each word, the app speaks
/// it aloud — the printed word is intentionally hidden during the
/// question, so audio is the only cue, matching the "hear it, don't see
/// it" design this game targets. The student taps the matching option
/// out of 3 cards (1 correct + 2 distractors pulled from the same
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

  // --- Mash guards -------------------------------------------------------
  //
  // A child's tap rate on a screen they like is well under 450ms apart, and
  // every one of those taps is real intent. The lock is not there to slow them
  // down — it is there so a tap that was already in flight when the screen
  // changed does not get counted against whatever replaced its target.
  DateTime _inputUnlockAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _roundLoading = false;

  bool get _inputLocked => DateTime.now().isBefore(_inputUnlockAt);

  void _lockInput([int ms = 450]) {
    _inputUnlockAt = DateTime.now().add(Duration(milliseconds: ms));
  }

  int get _score => _questionResults.where((r) => r == true).length;

  @override
  void initState() {
    super.initState();
    // Short burst. A two-second stream of confetti outlasts the moment it is
    // celebrating and delays the child's next tap; under a second lands as a
    // pop and clears.
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 700));
    _startNewRound();
  }

  @override
  void dispose() {
    textspeech.stop();
    _confettiController.dispose();
    super.dispose();
  }

  // Speech helper — same voice as practice.dart and the word list.
  Future<void> _speak(String text) async {
    // GUARD 4: stop before speaking. Without this, a mashed listen button
    // queues utterances that talk over each other and run into the next
    // question.
    await textspeech.stop();
    await textspeech.setLanguage('en-US');
    await textspeech.setPitch(1.3);
    await textspeech.setSpeechRate(.45);
    await textspeech.speak(text);
  }

  Future<void> _speakCurrent() async {
    if (_questions.isEmpty) return;
    await _speak(_questions[_currentIndex].target.text);
  }

  /// The listen disc. Always allowed — hearing the word again is never the
  /// wrong thing for a child to want, so this deliberately skips the input
  /// lock and only carries the speech-level stop.
  void _tapListen() {
    HapticFeedback.mediumImpact();
    _speakCurrent();
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
    // GUARD 2: re-entry. Mashing 'Play Again' used to fire overlapping fetches
    // whose setStates interleaved, building a round out of two shuffles.
    if (_roundLoading) return;
    _roundLoading = true;

    setState(() {
      _stage = _RoundStage.loading;
      _currentIndex = 0;
      _questionResults = List.filled(kWordsPerRound, null);
      _selectedWord = null;
      _isCorrect = false;
    });

    try {
      final pool = await _fetchWordPool();

      // Dedupe by text so we never treat two spellings of the same word as
      // different options.
      final distinct = dedupeWordsByText([...pool]..shuffle(_rand));

      // Safety net: make sure there are enough distinct words for a full
      // round, padding from the fallback pool if the real data came up short.
      if (distinct.length < kWordsPerRound) {
        for (final w in _fallbackPool) {
          if (distinct
              .any((d) => d.text.toLowerCase() == w.text.toLowerCase())) {
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

      if (!mounted) return;
      setState(() {
        _questions = questions;
        _stage = _RoundStage.question;
      });
      _lockInput();

      _speakCurrent();
    } finally {
      _roundLoading = false;
    }
  }

  void _handleSelect(Word selected) {
    // GUARD 1 + 3: wrong stage, or a tap that was in flight when the stage
    // changed.
    if (_stage != _RoundStage.question || _inputLocked) return;

    final target = _questions[_currentIndex].target;
    final correct = selected.id == target.id;

    HapticFeedback.heavyImpact();

    setState(() {
      _selectedWord = selected;
      _isCorrect = correct;
      _questionResults[_currentIndex] = correct;
      _stage = _RoundStage.feedback;
    });
    _lockInput();

    // Reward lands on the pick, not three screens later.
    if (correct) _confettiController.play();

    // Say the word again as part of the feedback — the reveal below is
    // just the single word (not a sentence), but a pre-reading student
    // still needs to hear it to know what it says.
    _speak(target.text);
  }

  void _goToNext() {
    // GUARD 1 + 3: this method had no guard at all. Two fast taps skipped a
    // question or ran off the end of the list.
    if (_stage != _RoundStage.feedback || _inputLocked) return;

    HapticFeedback.mediumImpact();
    final isLastQuestion = _currentIndex == _questions.length - 1;

    if (isLastQuestion) {
      setState(() {
        _stage = _RoundStage.summary;
      });
      _lockInput(600);
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
    _lockInput();

    _speakCurrent();
  }

  void _tapPlayAgain() {
    if (_inputLocked) return;
    HapticFeedback.heavyImpact();
    _startNewRound();
  }

  void _tapExitToGames() {
    if (_inputLocked) return;
    HapticFeedback.mediumImpact();
    textspeech.stop();
    Navigator.pushReplacementNamed(context, '/games');
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    switch (_stage) {
      case _RoundStage.loading:
        content = const _LoadingView();
        break;
      case _RoundStage.question:
        content = _scrollableCentered(_buildQuestion());
        break;
      case _RoundStage.feedback:
        content = _scrollableCentered(_buildQuestionFeedback());
        break;
      case _RoundStage.summary:
        content = _scrollableCentered(_buildRoundSummary());
        break;
    }

    return StudentBaseScaffold(
      currentIndex: 1,
      pageTitle: 'Tap the Word',
      pageIcon: Icons.hearing_rounded,
      body: Container(
        color: RRColor.canvas,
        child: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                colors: const [
                  RRColor.mint,
                  RRColor.sky,
                  RRColor.blossom,
                  RRColor.sunny,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Centers [child] vertically when it fits, but scrolls instead of
  /// overflowing when it doesn't (e.g. smaller screens, landscape, or
  /// split-screen). Used for all three round stages.
  Widget _scrollableCentered(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Question
  // -------------------------------------------------------------------------
  Widget _buildQuestion() {
    final question = _questions[_currentIndex];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundHud(
          results: _questionResults,
          currentIndex: _currentIndex,
          total: _questions.length,
        ),
        const SizedBox(height: 22),
        const Text(
          'Listen, then tap the word',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: RRFont.display,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: RRColor.ink,
          ),
        ),
        const SizedBox(height: 18),
        _ListenDisc(onTap: _tapListen),
        const SizedBox(height: 28),
        for (var i = 0; i < question.options.length; i++) ...[
          _OptionCard(
            word: question.options[i],
            tone: _OptionTone.of(i),
            onTap: () => _handleSelect(question.options[i]),
          ),
          if (i != question.options.length - 1) const SizedBox(height: 18),
        ],
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Feedback
  // -------------------------------------------------------------------------
  Widget _buildQuestionFeedback() {
    final target = _questions[_currentIndex].target;
    final isLastQuestion = _currentIndex == _questions.length - 1;

    // Kept intentionally short (no full sentences) so a student who
    // can't yet read sentences can still follow along using the mascot's
    // face and the single word reveal below.
    final message = _isCorrect ? 'Correct!' : 'Try Again!';
    final tone = _isCorrect
        ? const _OptionTone(RRColor.mintSurface, RRColor.mint, RRColor.mintInk)
        : const _OptionTone(
            RRColor.skySurface, RRColor.sky, RRColor.skyInk);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundHud(
          results: _questionResults,
          currentIndex: _currentIndex,
          total: _questions.length,
        ),
        const SizedBox(height: 20),
        // Bloom carries the result now that the emoji is gone. Cheering on a
        // hit, puzzled on a miss — puzzled at the word, not at the child.
        BloomMascot(
          size: 124,
          mood: _isCorrect ? BloomMood.cheer : BloomMood.confused,
        ),
        const SizedBox(height: 14),
        Text(
          message,
          style: TextStyle(
            fontFamily: RRFont.display,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: tone.ink,
          ),
        ),
        const SizedBox(height: 20),

        // Reveal the word itself — a single word, not a sentence — so a
        // pre-reading student gets a print + sound pairing as the answer.
        // Tappable, because the pairing only sticks if they can repeat it.
        Semantics(
          button: true,
          label: '${target.text}. Tap to hear it again.',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _speak(target.text);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              decoration: BoxDecoration(
                color: tone.surface,
                borderRadius: BorderRadius.circular(RRShape.radiusCard),
                border: Border.all(color: tone.edge, width: 3),
                boxShadow: RRShape.lift(tone.edge),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    target.text,
                    style: TextStyle(
                      fontFamily: RRFont.reader,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: tone.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.volume_up_rounded, size: 18, color: tone.ink),
                      const SizedBox(width: 6),
                      Text(
                        'Hear it again',
                        style: TextStyle(
                          fontFamily: RRFont.reader,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tone.ink,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),
        // Forward is an arrow, not a sentence. On the last word it becomes a
        // trophy, since 'go on' and 'you're done' are different promises and a
        // child who can't read the label needs them to look different.
        _IconAction(
          icon: isLastQuestion
              ? Icons.emoji_events_rounded
              : Icons.arrow_forward_rounded,
          label: isLastQuestion ? 'See results' : 'Next word',
          color: RRColor.sky,
          onTap: _goToNext,
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Summary
  // -------------------------------------------------------------------------
  Widget _buildRoundSummary() {
    final total = _questions.length;
    final score = _score;
    final summary = roundSummaryFor(score: score, total: total);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BloomMascot(
          size: 130,
          mood: score == total
              ? BloomMood.cheer
              : score > 0
                  ? BloomMood.happy
                  : BloomMood.idle,
        ),
        const SizedBox(height: 10),
        Text(summary.emoji, style: const TextStyle(fontSize: 54)),
        const SizedBox(height: 8),
        Text(
          summary.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: RRFont.display,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: RRColor.ink,
          ),
        ),
        const SizedBox(height: 24),

        // One star per word in the round; filled gold = correct. They pop in
        // one at a time — the round is being counted back to the child, which
        // is the moment the score becomes a result rather than a number.
        _StarRow(results: _questionResults, total: total),

        const SizedBox(height: 18),
        Text(
          '$score out of $total',
          style: const TextStyle(
            fontFamily: RRFont.display,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: RRColor.sunnyInk,
          ),
        ),
        const SizedBox(height: 34),
        // Two ways out, both icons. Replay is the bigger, warmer one, since it
        // is what most children want; Games is the door back, quieter but the
        // same size target.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _IconAction(
              icon: Icons.replay_rounded,
              label: 'Play again',
              color: RRColor.blossom,
              onTap: _tapPlayAgain,
            ),
            const SizedBox(width: 28),
            _IconAction(
              icon: Icons.sports_esports_rounded,
              label: 'Back to games',
              color: RRColor.sky,
              onTap: _tapExitToGames,
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// HUD — where am I in the round
//
// Was a row of Material icons in green / red / grey. Red-on-green is the one
// pair to avoid, roughly 1 in 12 boys cannot separate them, and a red X is a
// harsh thing to leave on screen for a five-year-old mid-round. Now: a filled
// gold gem for correct, a soft outlined gem for missed, a pulsing blossom gem
// for the one being played. Shape and fill carry the state, colour supports it.
// ---------------------------------------------------------------------------
class _RoundHud extends StatelessWidget {
  final List<bool?> results;
  final int currentIndex;
  final int total;

  const _RoundHud({
    required this.results,
    required this.currentIndex,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Word ${currentIndex + 1} of $total',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: RRColor.card,
          borderRadius: BorderRadius.circular(RRShape.radiusChip),
          border: Border.all(color: RRColor.lilac, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(total, (i) {
            final result = i < results.length ? results[i] : null;
            final isCurrent = i == currentIndex;

            final Color fill = result == true
                ? RRColor.sunny
                : result == false
                    ? RRColor.lilacSurface
                    : isCurrent
                        ? RRColor.blossomGlow
                        : RRColor.canvas;
            final Color edge = result == true
                ? RRColor.sunnyInk
                : result == false
                    ? RRColor.lilacInk
                    : isCurrent
                        ? RRColor.blossomInk
                        : RRColor.lilac;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: Border.all(color: edge, width: 2.5),
                ),
                child: Icon(
                  result == true
                      ? Icons.star_rounded
                      : result == false
                          ? Icons.star_border_rounded
                          : isCurrent
                              ? Icons.volume_up_rounded
                              : Icons.circle_outlined,
                  size: 18,
                  color: result == true ? Colors.white : edge,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Listen disc — the centrepiece of the question screen.
//
// 150dp, pulsing ring so it reads as 'press me' before anything is explained,
// and it never locks out: a child asking to hear the word again is never doing
// the wrong thing.
// ---------------------------------------------------------------------------
class _ListenDisc extends StatefulWidget {
  final VoidCallback onTap;

  const _ListenDisc({required this.onTap});

  @override
  State<_ListenDisc> createState() => _ListenDiscState();
}

class _ListenDiscState extends State<_ListenDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  bool _pressed = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      button: true,
      label: 'Hear the word',
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: SizedBox(
          width: 190,
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!reduceMotion)
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    final t = _pulse.value;
                    return Container(
                      width: 150 + 40 * t,
                      height: 150 + 40 * t,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: RRColor.skyGlow.withOpacity((1 - t) * 0.7),
                          width: 4,
                        ),
                      ),
                    );
                  },
                ),
              AnimatedScale(
                scale: _pressed ? 0.93 : 1.0,
                duration: Duration(milliseconds: reduceMotion ? 0 : 110),
                curve: Curves.easeOut,
                child: Container(
                  width: 150,
                  height: 150,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: RRColor.sky,
                    shape: BoxShape.circle,
                    border: Border.all(color: RRColor.skyInk, width: 4),
                    boxShadow: RRShape.lift(RRColor.sky, pressed: _pressed),
                  ),
                  child: const Text('🔊', style: TextStyle(fontSize: 62)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Option card
//
// Was a 240x60 ElevatedButton, three of them stacked in one colour, 8dp apart.
// Now each is its own object: full width, 84dp tall, its own tone, a hard 3px
// border, its own shadow, and 18dp of air between. A child aiming at the
// middle one has a target, not a row.
// ---------------------------------------------------------------------------
class _OptionCard extends StatefulWidget {
  final Word word;
  final _OptionTone tone;
  final VoidCallback onTap;

  const _OptionCard({
    required this.word,
    required this.tone,
    required this.onTap,
  });

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
    if (v) HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      button: true,
      label: widget.word.text,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: Duration(milliseconds: reduceMotion ? 0 : 110),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: Duration(milliseconds: reduceMotion ? 0 : 110),
            width: double.infinity,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: tone.edge, width: 3),
              boxShadow: RRShape.lift(tone.edge, pressed: _pressed),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.word.text,
                  style: TextStyle(
                    fontFamily: RRFont.reader,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: tone.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stars, counted back one at a time.
// ---------------------------------------------------------------------------
class _StarRow extends StatefulWidget {
  final List<bool?> results;
  final int total;

  const _StarRow({required this.results, required this.total});

  @override
  State<_StarRow> createState() => _StarRowState();
}

class _StarRowState extends State<_StarRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 320 * widget.total),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.total, (i) {
        final correct =
            i < widget.results.length && widget.results[i] == true;

        final star = Icon(
          correct ? Icons.star_rounded : Icons.star_border_rounded,
          size: 54,
          color: correct ? RRColor.sunny : RRColor.lilac,
        );

        if (reduceMotion) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: star,
          );
        }

        final start = i / widget.total;
        final end = (i + 1) / widget.total;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: _c,
              curve: Interval(start, end, curve: Curves.elasticOut),
            ),
            child: star,
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Icon action — the forward and exit controls.
//
// No words. A 92dp disc with a single high-contrast glyph, which is what a
// pre-reader can actually parse at speed: arrow means on, trophy means done,
// loop means again, controller means out. The label still exists — it goes to
// the screen reader and the long-press tooltip, not to the child's eye.
// ---------------------------------------------------------------------------
class _IconAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _IconAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_IconAction> createState() => _IconActionState();
}

class _IconActionState extends State<_IconAction> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.label,
        child: GestureDetector(
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.93 : 1.0,
            duration: Duration(milliseconds: reduceMotion ? 0 : 110),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: Duration(milliseconds: reduceMotion ? 0 : 110),
              width: 92,
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: RRShape.lift(widget.color, pressed: _pressed),
              ),
              child: Icon(widget.icon, size: 46, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading
// ---------------------------------------------------------------------------
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BloomMascot(size: 120, mood: BloomMood.sleepy),
          SizedBox(height: 20),
          Text('Getting the game ready…', style: RRText.body),
          SizedBox(height: 20),
          SizedBox(
            width: 120,
            child: LinearProgressIndicator(
              minHeight: 10,
              backgroundColor: RRColor.lilacSurface,
              color: RRColor.mint,
            ),
          ),
        ],
      ),
    );
  }
}