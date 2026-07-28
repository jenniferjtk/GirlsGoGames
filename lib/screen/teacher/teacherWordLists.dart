import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:readright/config/theme.dart';
import 'package:readright/models/word.dart';
import 'package:readright/providers/teacherProvider.dart';
import 'package:readright/widgets/bloom_mascot.dart';
import 'package:readright/widgets/teacher_base_scaffold.dart';

/// Card palette, rotated by index so a long list reads as a set of distinct
/// items rather than one repeated row. A given list keeps its colour across
/// visits, which is what makes the rotation navigable instead of decorative.
class _ListTone {
  final Color surface;
  final Color edge;
  final Color ink;

  const _ListTone(this.surface, this.edge, this.ink);

  static const List<_ListTone> all = [
    _ListTone(RRColor.mintSurface, RRColor.mint, RRColor.mintInk),
    _ListTone(RRColor.skySurface, RRColor.sky, RRColor.skyInk),
    _ListTone(RRColor.blossomSurface, RRColor.blossom, RRColor.blossomInk),
    _ListTone(RRColor.sunnyGlow, RRColor.sunny, RRColor.sunnyInk),
  ];

  static _ListTone of(int i) => all[i % all.length];
}

class TeacherWordListsPage extends StatelessWidget {
  const TeacherWordListsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _WordListsView();
  }
}

class _WordListsView extends StatelessWidget {
  const _WordListsView();

  @override
  Widget build(BuildContext context) {
    return Consumer<TeacherProvider>(
      builder: (context, provider, _) {
        return TeacherBaseScaffold(
          // Was 1 — that highlighted the wrong tab under the new nav.
          currentIndex: 2,
          pageTitle: 'Word Lists',
          pageIcon: Icons.menu_book_rounded,
          body: SafeArea(
            child: RefreshIndicator(
              color: RRColor.mint,
              onRefresh: provider.refreshWordLists,
              child: provider.listsLoading
                  ? const _LoadingView()
                  : provider.listsError != null
                      ? _ErrorView(message: provider.listsError!)
                      : _ListsBody(provider: provider),
            ),
          ),
        );
      },
    );
  }
}

class _ListsBody extends StatelessWidget {
  final TeacherProvider provider;

  const _ListsBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    final lists = provider.wordLists;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _Header(count: lists.length),
        const SizedBox(height: 20),
        if (lists.isEmpty)
          const _EmptyView()
        else
          for (var i = 0; i < lists.length; i++) ...[
            _WordListCard(
              // Keyed by id so expansion and loaded words survive a rebuild.
              key: ValueKey(lists[i].id),
              item: lists[i],
              tone: _ListTone.of(i),
            ),
            const SizedBox(height: 14),
          ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------
class _Header extends StatelessWidget {
  final int count;

  const _Header({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: RRColor.card,
        borderRadius: BorderRadius.circular(RRShape.radiusCard),
        border: Border.all(color: RRColor.lilac, width: 2.5),
        boxShadow: RRShape.lift(RRColor.lilac),
      ),
      child: Row(
        children: [
          const BloomMascot(size: 66, mood: BloomMood.happy, glasses: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Word lists',
                  style: TextStyle(
                    fontFamily: RRFont.display,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: RRColor.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count == 0
                      ? 'Nothing here yet.'
                      : 'Tap a grade to see every word in it.',
                  style: RRText.body,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: RRColor.mintSurface,
                    borderRadius: BorderRadius.circular(RRShape.radiusChip),
                    border: Border.all(color: RRColor.mint, width: 1.5),
                  ),
                  child: Text(
                    '$count ${count == 1 ? 'list' : 'lists'}',
                    style: const TextStyle(
                      fontFamily: RRFont.reader,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: RRColor.mintInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grade card — header always visible, words expand underneath.
// ---------------------------------------------------------------------------
class _WordListCard extends StatefulWidget {
  final WordListItem item;
  final _ListTone tone;

  const _WordListCard({super.key, required this.item, required this.tone});

  @override
  State<_WordListCard> createState() => _WordListCardState();
}

class _WordListCardState extends State<_WordListCard> {
  bool _expanded = false;
  bool _pressed = false;

  // Lifted from TeacherWordListDetailsPage, unchanged.
  bool _loading = false;
  String? _error;
  List<Word> _words = [];
  bool _loadedOnce = false;

  Future<void> _loadWords() async {
    final supabase = Supabase.instance.client;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final wordData = await supabase
          .from('words')
          .select('id, text, type, sentences')
          .eq('list_id', widget.item.id)
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

      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadedOnce = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load words.';
      });
    }
  }

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
    if (v) HapticFeedback.selectionClick();
  }

  void _toggle() {
    HapticFeedback.mediumImpact();
    setState(() => _expanded = !_expanded);

    // Nothing is queried until a grade is actually opened.
    if (_expanded && !_loadedOnce && !_loading) {
      _loadWords();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone;
    final item = widget.item;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: Duration(milliseconds: reduceMotion ? 0 : 110),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: Duration(milliseconds: reduceMotion ? 0 : 110),
        decoration: BoxDecoration(
          color: tone.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: tone.edge, width: 2.5),
          boxShadow: RRShape.lift(tone.edge, pressed: _pressed),
        ),
        child: Column(
          children: [
            // ---- Header row (the tap target) ----
            Semantics(
              button: true,
              expanded: _expanded,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _setPressed(true),
                onTapUp: (_) => _setPressed(false),
                onTapCancel: () => _setPressed(false),
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.list_alt_rounded,
                            size: 26, color: tone.ink),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: RRFont.display,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                color: tone.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(
                                          RRShape.radiusChip),
                                      border: Border.all(
                                          color: tone.edge, width: 1.5),
                                    ),
                                    child: Text(
                                      // Once loaded, the word count replaces
                                      // the category label — it's the thing a
                                      // teacher came here to find out.
                                      _loadedOnce
                                          ? '${_words.length} words'
                                          : item.category,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: RRFont.reader,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: tone.ink,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Chevron rotates rather than pointing right — this opens
                      // in place now, it doesn't go anywhere.
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration:
                            Duration(milliseconds: reduceMotion ? 0 : 180),
                        child: Icon(Icons.expand_more_rounded,
                            size: 28, color: tone.ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ---- Expanded body ----
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: _ExpandedWords(
                tone: tone,
                loading: _loading,
                error: _error,
                words: _words,
                onRetry: _loadWords,
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: Duration(milliseconds: reduceMotion ? 0 : 200),
              sizeCurve: Curves.easeOut,
            ),
          ],
        ),
      ),
    );
  }
}

/// The words themselves, on a white sheet inside the tinted card so the grade
/// still frames them.
class _ExpandedWords extends StatelessWidget {
  final _ListTone tone;
  final bool loading;
  final String? error;
  final List<Word> words;
  final VoidCallback onRetry;

  const _ExpandedWords({
    required this.tone,
    required this.loading,
    required this.error,
    required this.words,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RRColor.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Builder(
        builder: (context) {
          if (loading) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    backgroundColor: RRColor.lilacSurface,
                    color: tone.edge,
                  ),
                ),
              ),
            );
          }

          if (error != null) {
            return Column(
              children: [
                Text(error!, textAlign: TextAlign.center, style: RRText.body),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  style: TextButton.styleFrom(foregroundColor: tone.ink),
                  label: const Text(
                    'Try again',
                    style: TextStyle(
                      fontFamily: RRFont.display,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          }

          if (words.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No words in this list yet.', style: RRText.body),
            );
          }

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: words
                .map(
                  (w) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: tone.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: tone.edge, width: 2),
                    ),
                    child: Text(
                      w.text,
                      style: TextStyle(
                        fontFamily: RRFont.reader,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: tone.ink,
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty / loading / error
// ---------------------------------------------------------------------------
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 40),
      child: Column(
        children: [
          BloomMascot(size: 110, mood: BloomMood.idle, glasses: true),
          SizedBox(height: 18),
          Text(
            'No word lists yet',
            style: TextStyle(
              fontFamily: RRFont.display,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: RRColor.ink,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Pull down to refresh once lists have been set up.',
            textAlign: TextAlign.center,
            style: RRText.body,
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 90),
        Center(
          child: Column(
            children: [
              BloomMascot(size: 110, mood: BloomMood.sleepy, glasses: true),
              SizedBox(height: 18),
              Text('Loading word lists…', style: RRText.body),
              SizedBox(height: 18),
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
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const BloomMascot(
                    size: 110, mood: BloomMood.confused, glasses: true),
                const SizedBox(height: 18),
                const Text(
                  'Could not load word lists',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: RRFont.display,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: RRColor.ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pull down to try again.',
                  textAlign: TextAlign.center,
                  style: RRText.body,
                ),
                const SizedBox(height: 18),
                Text(message, textAlign: TextAlign.center, style: RRText.aside),
              ],
            ),
          ),
        ),
      ],
    );
  }
}