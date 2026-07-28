import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:readright/config/theme.dart';
import 'package:readright/models/word.dart';
import 'package:readright/widgets/bloom_mascot.dart';
import 'package:readright/widgets/student_base_scaffold.dart';

/// Card palette. Four hues from the brief, rotated by index so the grid is
/// lively without being random — the same word keeps the same colour on every
/// visit, which is what makes a wall of words feel learnable rather than noisy.
class _CardTone {
  final Color surface;
  final Color edge;
  final Color ink;

  const _CardTone(this.surface, this.edge, this.ink);

  static const List<_CardTone> all = [
    _CardTone(RRColor.mintSurface, RRColor.mint, RRColor.mintInk),
    _CardTone(RRColor.skySurface, RRColor.sky, RRColor.skyInk),
    _CardTone(RRColor.blossomSurface, RRColor.blossom, RRColor.blossomInk),
    _CardTone(RRColor.sunnyGlow, RRColor.sunny, RRColor.sunnyInk),
  ];

  static _CardTone of(int index) => all[index % all.length];
}

class WordListPage extends StatefulWidget {
  const WordListPage({super.key});

  @override
  State<WordListPage> createState() => _WordListPageState();
}

class _WordListPageState extends State<WordListPage> {
  bool _loading = true;
  List<Word> _words = [];
  String _listTitle = '';
  String? _error;

  // Same engine and same voice settings as practice.dart, so a word sounds
  // identical wherever the child hears it. A pitch of 1.3 and a rate of .45 is
  // the voice they already know from Practice; changing it here would make the
  // same word sound like a different word.
  final FlutterTts textspeech = FlutterTts();

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    // Not in practice.dart, but needed here: the grid invites rapid tapping,
    // and without a stop the utterances queue and play long after the child
    // has moved on.
    await textspeech.stop();
    await textspeech.setLanguage('en-US');
    await textspeech.setPitch(1.3);
    await textspeech.setSpeechRate(.45);
    await textspeech.speak(text);
  }

  @override
  void dispose() {
    textspeech.stop();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentWordList();
  }

  // Load current list and words
  Future<void> _loadCurrentWordList() async {
    final supabase = Supabase.instance.client;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'User not logged in.';
          _loading = false;
        });
        return;
      }

      // Fetch student's current list index
      final userData = await supabase
          .from('users')
          .select('current_list_int')
          .eq('id', user.id)
          .maybeSingle();

      if (userData == null || userData['current_list_int'] == null) {
        setState(() {
          _error = 'No Dolch list assigned.';
          _loading = false;
        });
        return;
      }

      final currentOrder = userData['current_list_int'] as int;

      // Find the matching word list
      final listData = await supabase
          .from('word_lists')
          .select('id, title, list_order')
          .eq('list_order', currentOrder)
          .maybeSingle();

      if (listData == null) {
        setState(() {
          _error = 'Word list not found for order $currentOrder.';
          _loading = false;
        });
        return;
      }

      final listId = listData['id'] as String;
      _listTitle = listData['title'] ?? 'Current List';

      // Fetch words from this list
      final wordData = await supabase
          .from('words')
          .select('id, text, type, sentences')
          .eq('list_id', listId)
          .order('text', ascending: true);

      _words = wordData.map<Word>((w) {
        final sentenceList = (w['sentences'] as List?)?.cast<String>() ?? [];
        return Word(
          id: w['id'],
          text: w['text'],
          type: w['type'],
          sentences: sentenceList,
        );
      }).toList();

      setState(() => _loading = false);
    } catch (e) {
      debugPrint('Error loading current list: $e');
      setState(() {
        _error = 'Failed to load current word list.';
        _loading = false;
      });
    }
  }

  //  UI
  @override
  Widget build(BuildContext context) {
    return StudentBaseScaffold(
      currentIndex: 2,
      pageTitle: 'My Words',
      pageIcon: Icons.menu_book_rounded,
      body: Container(
        color: RRColor.canvas,
        child: SafeArea(
          child: _loading
              ? const _LoadingView()
              : _error != null
                  ? _MessageView(
                      mood: BloomMood.idle,
                      headline: 'No words to show',
                      detail: _error!,
                    )
                  : _words.isEmpty
                      ? const _MessageView(
                          mood: BloomMood.idle,
                          headline: 'This list is empty',
                          detail: 'No words found in the current list.',
                        )
                      : _WordGrid(
                          title: _listTitle,
                          words: _words,
                          onSpeak: _speak,
                        ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid + grade header
// ---------------------------------------------------------------------------
class _WordGrid extends StatelessWidget {
  final String title;
  final List<Word> words;
  final Future<void> Function(String) onSpeak;

  const _WordGrid({
    required this.title,
    required this.words,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          sliver: SliverToBoxAdapter(
            child: _GradeHeader(title: title, count: words.length),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.98,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _WordCard(
                word: words[i],
                tone: _CardTone.of(i),
                onSpeak: onSpeak,
              ),
              childCount: words.length,
            ),
          ),
        ),
      ],
    );
  }
}

/// The grade level, treated as an award rather than a label.
///
/// Same medal shape as the badge trail on Home, so a child who has seen the
/// trail already knows what this is. The word count sits beside it as a chip —
/// present for a teacher, ignorable by a child.
class _GradeHeader extends StatelessWidget {
  final String title;
  final int count;

  const _GradeHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: '$title list, $count words',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: RRColor.card,
          borderRadius: BorderRadius.circular(RRShape.radiusCard),
          border: Border.all(color: RRColor.lilac, width: 2.5),
          boxShadow: RRShape.lift(RRColor.lilac),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: RRColor.sunny,
                shape: BoxShape.circle,
                border: Border.all(color: RRColor.sunnyInk, width: 3),
                boxShadow: RRShape.lift(RRColor.sunny),
              ),
              child: const Icon(Icons.star_rounded,
                  size: 32, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: RRFont.display,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      color: RRColor.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: RRColor.mintSurface,
                      borderRadius:
                          BorderRadius.circular(RRShape.radiusChip),
                      border: Border.all(color: RRColor.mint, width: 1.5),
                    ),
                    child: Text(
                      '$count words',
                      style: const TextStyle(
                        fontFamily: RRFont.reader,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: RRColor.mintInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const BloomMascot(size: 52, mood: BloomMood.happy),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mini card
//
// Presses in on touch: 0.93 scale, shadow collapses to a 2px offset, medium
// haptic on press and a heavier one on open. The card looks like it moved, not
// only like it changed colour — a child watching their own thumb needs the
// motion, and a child with low vision needs the shadow change.
// ---------------------------------------------------------------------------
class _WordCard extends StatefulWidget {
  final Word word;
  final _CardTone tone;
  final Future<void> Function(String) onSpeak;

  const _WordCard({
    required this.word,
    required this.tone,
    required this.onSpeak,
  });

  @override
  State<_WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<_WordCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
    if (v) {
      HapticFeedback.mediumImpact();
      // No SystemSound click here any more — a click landing a beat before the
      // spoken word muddies the first phoneme, which is the one that matters.
    }
  }

  void _open() {
    HapticFeedback.heavyImpact();
    // Speak first, so the sound starts as the sheet animates in rather than
    // after it settles. A child taps and hears; the sheet is the follow-up.
    widget.onSpeak(widget.word.text);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: RRColor.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => _WordSheet(
        word: widget.word,
        tone: widget.tone,
        onSpeak: widget.onSpeak,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      button: true,
      label: '${widget.word.text}. Tap to hear it.',
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: _open,
        child: AnimatedScale(
          scale: _pressed ? 0.93 : 1.0,
          duration: Duration(milliseconds: reduceMotion ? 0 : 110),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: Duration(milliseconds: reduceMotion ? 0 : 110),
            decoration: BoxDecoration(
              color: tone.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: tone.edge, width: 2.5),
              boxShadow: RRShape.lift(tone.edge, pressed: _pressed),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.word.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: RRFont.reader,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: tone.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                // Speaker mark. A child cannot discover 'this makes a sound'
                // by looking at a plain card, and will not tap to find out.
                Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    _pressed
                        ? Icons.volume_up_rounded
                        : Icons.volume_up_outlined,
                    size: 16,
                    color: tone.ink.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Word sheet — the word, large, with a sentence it lives in.
// ---------------------------------------------------------------------------
class _WordSheet extends StatelessWidget {
  final Word word;
  final _CardTone tone;
  final Future<void> Function(String) onSpeak;

  const _WordSheet({
    required this.word,
    required this.tone,
    required this.onSpeak,
  });

  /// Bolds the sight word inside its example sentence so the child can find it.
  Widget _sentence(String sentence) {
    final lower = sentence.toLowerCase();
    final target = word.text.toLowerCase();
    final at = lower.indexOf(target);

    const base = TextStyle(
      fontFamily: RRFont.reader,
      fontSize: 22,
      height: 1.5,
      color: RRColor.ink,
    );

    if (at < 0 || target.isEmpty) {
      return Text(sentence, textAlign: TextAlign.center, style: base);
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: sentence.substring(0, at)),
          TextSpan(
            text: sentence.substring(at, at + target.length),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: tone.ink,
              backgroundColor: tone.surface,
            ),
          ),
          TextSpan(text: sentence.substring(at + target.length)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sentences = word.sentences.take(2).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: RRColor.lilac,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 26),
          // Tap the word to hear it again. This is the replay control: a child
          // who missed it the first time reaches for the word itself, not for a
          // button beside it.
          Semantics(
            button: true,
            label: '${word.text}. Tap to hear it again.',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                onSpeak(word.text);
              },
              child: Column(
                children: [
                  Text(
                    word.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: RRFont.reader,
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      height: 1.1,
                      color: tone.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: tone.surface,
                      borderRadius:
                          BorderRadius.circular(RRShape.radiusChip),
                      border: Border.all(color: tone.edge, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.volume_up_rounded,
                            size: 22, color: tone.ink),
                        const SizedBox(width: 8),
                        Text(
                          'Hear it again',
                          style: TextStyle(
                            fontFamily: RRFont.display,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: tone.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          if (sentences.isEmpty)
            const Text(
              'No sentence for this word yet.',
              textAlign: TextAlign.center,
              style: RRText.body,
            )
          else
            for (final s in sentences) ...[
              Semantics(
                button: true,
                label: 'Sentence. Tap to hear it.',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onSpeak(s);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: RRColor.canvas,
                      borderRadius:
                          BorderRadius.circular(RRShape.radiusCard),
                      border: Border.all(color: RRColor.lilac, width: 2),
                    ),
                    child: Column(
                      children: [
                        _sentence(s),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.volume_up_outlined,
                                size: 18, color: RRColor.inkSoft),
                            const SizedBox(width: 6),
                            const Text(
                              'Hear the sentence',
                              style: TextStyle(
                                fontFamily: RRFont.reader,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: RRColor.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          const SizedBox(height: 8),
          // Teacher-facing detail, deliberately small and quiet.
          if (word.type != null && word.type!.isNotEmpty)
            Text(word.type!, style: RRText.aside),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading + message states
//
// Both were bare: a spinner, and red text. Neither told a child anything, and
// red on its own is meaningless to a five-year-old.
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
          Text('Finding your words…', style: RRText.body),
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

class _MessageView extends StatelessWidget {
  final BloomMood mood;
  final String headline;
  final String detail;

  const _MessageView({
    required this.mood,
    required this.headline,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BloomMascot(size: 120, mood: mood),
            const SizedBox(height: 20),
            Text(headline,
                textAlign: TextAlign.center, style: RRText.section),
            const SizedBox(height: 10),
            const Text(
              'Ask your teacher to set up your list.',
              textAlign: TextAlign.center,
              style: RRText.body,
            ),
            const SizedBox(height: 20),
            // Teacher-facing detail, deliberately small and quiet so it reads
            // as 'not for you' to a six-year-old.
            Text(detail, textAlign: TextAlign.center, style: RRText.aside),
          ],
        ),
      ),
    );
  }
}