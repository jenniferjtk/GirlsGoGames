// Reading order, top to bottom, is deliberately "who am I → how am I doing →
// where am I → what did I just do":
//
//   Greeting        name + class, class demoted to a chip
//   Word Nest       segmented ring + Bloom          <- the signature element
//   Badge Trail     the five Dolch lists as a path
//   Recent          last 5 words as faces, not scores


import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:readright/config/theme.dart';
import 'package:readright/services/databaseHelper.dart';
import 'package:readright/widgets/bloom_mascot.dart';
import 'package:readright/widgets/student_base_scaffold.dart';
import 'package:readright/providers/studentDashboardProvider.dart';

/// The five Dolch lists, in order. Index 0 == list 1.
const List<String> kDolchLists = [
  'Pre-Primer',
  'Primer',
  '1st Grade',
  '2nd Grade',
  '3rd Grade',
];

class StudentDashboard extends StatefulWidget {
  final bool skipLoad;
  final bool testStartLoaded;
  final SupabaseClient? testClient;

  const StudentDashboard({
    super.key,
    this.skipLoad = false,
    this.testStartLoaded = false,
    this.testClient,
  });

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  // Lifted from _ProgressPageState — same calls, same shape.
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _attempts = [];

  @override
  void initState() {
    super.initState();

    if (widget.testStartLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<StudentDashboardProvider>().isLoading = false;
      });
      return;
    }

    if (widget.skipLoad) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<StudentDashboardProvider>().loadDashboard();
    });

    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final supabase = widget.testClient ?? Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final db = DatabaseHelper.instance;
      final userStats = await db.getUserProgressStats(currentUser.id);
      final userAttempts = await db.fetchAttemptsByUser(currentUser.id);

      if (!mounted) return;
      setState(() {
        _stats = userStats;
        _attempts = userAttempts;
      });
    } catch (_) {
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<StudentDashboardProvider>();

    return StudentBaseScaffold(
      currentIndex: 0,
      pageTitle: 'Home',
      pageIcon: Icons.home_rounded,
      body: Container(
        color: RRColor.canvas,
        child: SafeArea(
          child: dashboard.isLoading
              ? const _LoadingView()
              : dashboard.errorMessage != null
                  ? _ErrorView(
                      message: dashboard.errorMessage!,
                      onRetry: () {
                        HapticFeedback.mediumImpact();
                        context.read<StudentDashboardProvider>().loadDashboard();
                        _loadProgress();
                      },
                    )
                  : _HomeBody(
                      dashboard: dashboard,
                      stats: _stats,
                      attempts: _attempts,
                    ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------
class _HomeBody extends StatelessWidget {
  final StudentDashboardProvider dashboard;
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> attempts;

  const _HomeBody({
    required this.dashboard,
    required this.stats,
    required this.attempts,
  });

  /// Which Dolch list the child is on, 1-based.
  ///
  /// Prefer the provider's list title, since that is what the teacher assigned;
  /// fall back to the stats row, then to list 1.
  int get _currentList {
    final title = dashboard.currentList?['title'];
    if (title is String) {
      final i = kDolchLists.indexWhere(
        (l) => l.toLowerCase() == title.trim().toLowerCase(),
      );
      if (i >= 0) return i + 1;
    }
    final fromStats = stats['currentList'];
    if (fromStats is int && fromStats >= 1) return fromStats;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final user = dashboard.userInfo;
    final firstName = (user?['first_name'] ?? 'Reader') as String;
    final className = user?['class_name'] as String?;

    final total = dashboard.totalWords;
    final mastered = dashboard.masteredWords;
    final progress = total == 0 ? 0.0 : mastered / total;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      children: [
        _Greeting(firstName: firstName, className: className),
        const SizedBox(height: 20),
        _WordNest(mastered: mastered, total: total, progress: progress),
        const SizedBox(height: 28),
        _BadgeTrail(currentList: _currentList),
        const SizedBox(height: 28),
        _RecentStrip(attempts: attempts),
        const SizedBox(height: 28),
        _StatsCard(stats: stats, attempts: attempts),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Greeting
//
// Was two stacked heading-weight blocks. The class name is teacher-relevant,
// not child-relevant, so it drops to a chip: present for anyone who needs it,
// out of the reading path for the child.
// ---------------------------------------------------------------------------
class _Greeting extends StatelessWidget {
  final String firstName;
  final String? className;

  const _Greeting({required this.firstName, this.className});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Hi, Reader $firstName!', style: RRText.greeting, textAlign: TextAlign.center),
            if (className != null && className!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: RRColor.lilacSurface,
                  borderRadius: BorderRadius.circular(RRShape.radiusChip),
                  border: Border.all(color: RRColor.lilac, width: 1.5),
                ),
                child: Text(
                  '🏫 Class: $className',
                  style: const TextStyle(
                    fontFamily: RRFont.reader,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: RRColor.lilacInk,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SIGNATURE ELEMENT — Bloom's Word Nest
//
// A *segmented* ring, not a continuous bar. Ten arcs a child can count with a
// finger, instead of a fill percentage they have to estimate. Bloom sits in the
// middle and changes mood as the nest fills, so the state of things is legible
// before a single character is read.
//
// The old '48.0% • 12 / 25 words mastered' string is gone. Percentages are not
// taught until third or fourth grade.
// ---------------------------------------------------------------------------
class _WordNest extends StatelessWidget {
  final int mastered;
  final int total;
  final double progress;

  const _WordNest({
    required this.mastered,
    required this.total,
    required this.progress,
  });

  BloomMood get _mood {
    if (total > 0 && progress >= 1.0) return BloomMood.cheer;
    if (progress > 0) return BloomMood.happy;
    return BloomMood.idle;
  }

  String get _caption {
    if (total == 0) return 'Your words are on the way.';
    if (progress >= 1.0) return 'You got them all!';
    if (progress > 0) return 'Nice reading. Keep going.';
    return 'Tap Games to learn your first word.';
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      label: 'You have learned $mastered of $total words. $_caption',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: RRColor.card,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: RRColor.lilac, width: 3),
          boxShadow: RRShape.lift(RRColor.lilac),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: reduceMotion ? progress : 0, end: progress),
                    duration: Duration(milliseconds: reduceMotion ? 0 : 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => CustomPaint(
                      size: const Size(220, 220),
                      painter: _SegmentedRingPainter(value),
                    ),
                  ),
                  BloomMascot(size: 112, mood: _mood),
                ],
              ),
            ),
            const SizedBox(height: 10),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: RRText.hero,
                children: [
                  TextSpan(text: '$mastered'),
                  TextSpan(
                    text: '  of  $total',
                    style: const TextStyle(
                      fontFamily: RRFont.display,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: RRColor.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text('words', style: RRText.body),
            const SizedBox(height: 10),
            Text(_caption, textAlign: TextAlign.center, style: RRText.body),
          ],
        ),
      ),
    );
  }
}

class _SegmentedRingPainter extends CustomPainter {
  final double progress;

  _SegmentedRingPainter(this.progress);

  static const int segments = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - stroke) / 2,
    );

    const gap = 0.10; // radians between arcs — the countable bit
    final sweep = (2 * math.pi - gap * segments) / segments;
    final filled = progress * segments;

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = RRColor.lilacSurface;

    final fillRim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = RRColor.mint;

    final fillCore = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.55
      ..strokeCap = StrokeCap.round
      ..color = RRColor.mintGlow;

    for (var i = 0; i < segments; i++) {
      final start = -math.pi / 2 + i * (sweep + gap);
      canvas.drawArc(rect, start, sweep, false, base);

      final fraction = (filled - i).clamp(0.0, 1.0);
      if (fraction > 0) {
        canvas.drawArc(rect, start, sweep * fraction, false, fillRim);
        canvas.drawArc(rect, start, sweep * fraction, false, fillCore);
      }
    }
  }

  @override
  bool shouldRepaint(_SegmentedRingPainter old) => old.progress != progress;
}

// ---------------------------------------------------------------------------
// Badge Trail
//
// Absorbs both the old 'Progress in current list: $title' line and the old
// Dolch badge row. Position on a left-to-right path is something a child reads
// spatially: behind me = done, under my finger = now, ahead = later. The list
// name no longer needs to be stated in a sentence.
//
// Locked badges keep a visible outline rather than going flat grey — a greyed
// circle reads as broken, an outlined one reads as empty.
// ---------------------------------------------------------------------------
class _BadgeTrail extends StatelessWidget {
  final int currentList;

  const _BadgeTrail({required this.currentList});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: const Text('🏅 My Badges', style: RRText.section),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 108,
          child: Stack(
            children: [
              // The path itself, behind the badges.
              Positioned(
                left: 20,
                right: 20,
                top: 32,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: RRColor.lilacSurface,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(kDolchLists.length, (i) {
                  final listNumber = i + 1;
                  return _Badge(
                    label: kDolchLists[i],
                    earned: listNumber < currentList,
                    current: listNumber == currentList,
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatefulWidget {
  final String label;
  final bool earned;
  final bool current;

  const _Badge({
    required this.label,
    required this.earned,
    required this.current,
  });

  @override
  State<_Badge> createState() => _BadgeState();
}

class _BadgeState extends State<_Badge> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.current) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _tap() {
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
    final message = widget.earned
        ? '${widget.label} — done!'
        : widget.current
            ? '${widget.label} — you are here.'
            : '${widget.label} — coming soon.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          backgroundColor: RRColor.ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RRShape.radiusChip),
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: RRFont.display,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final Color fill = widget.earned
        ? RRColor.sunny
        : widget.current
            ? RRColor.blossomGlow
            : RRColor.card;
    final Color edge = widget.earned
        ? RRColor.sunnyInk
        : widget.current
            ? RRColor.blossomInk
            : RRColor.lilac;
    final Color labelColor = widget.earned
        ? RRColor.sunnyInk
        : widget.current
            ? RRColor.blossomInk
            : RRColor.lilacInk;

    Widget medal = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: edge, width: 3),
        boxShadow: widget.earned ? RRShape.lift(RRColor.sunny) : null,
      ),
      child: Icon(
        widget.earned
            ? Icons.star_rounded
            : widget.current
                ? Icons.play_arrow_rounded
                : Icons.lock_outline_rounded,
        size: 30,
        color: widget.earned ? Colors.white : edge,
      ),
    );

    if (widget.current && !reduceMotion) {
      medal = ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 1.08)
            .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
        child: medal,
      );
    }

    return Semantics(
      button: true,
      label: widget.earned
          ? '${widget.label} badge, earned'
          : widget.current
              ? '${widget.label}, your list now'
              : '${widget.label}, locked',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _tap,
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              medal,
              const SizedBox(height: 8),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: RRFont.reader,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: labelColor,
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
// Recent Strip
//
// Was a three-column word / score / feedback table. A number like 73 means
// nothing to a first grader and reads as failure to one who has just started
// recognising digits, so the score becomes a face:
//
//   >= 80  star   "Got it!"
//   >= 50  smile  "Almost!"
//    < 50  loop   "Try again"
//
// The feedback string is still exact and still reachable — one tap — for a
// teacher looking over the child's shoulder. Nothing was deleted from the data.
// ---------------------------------------------------------------------------
class _RecentStrip extends StatelessWidget {
  final List<Map<String, dynamic>> attempts;

  const _RecentStrip({required this.attempts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: const Text('🎒 My Words', style: RRText.section),
        ),
        const SizedBox(height: 14),
        if (attempts.isEmpty)
          const _EmptyRecent()
        else
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: attempts.length > 5 ? 5 : attempts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _WordChip(attempt: attempts[i]),
            ),
          ),
      ],
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: RRColor.skySurface,
        borderRadius: BorderRadius.circular(RRShape.radiusCard),
        border: Border.all(color: RRColor.skyGlow, width: 2),
      ),
      child: Row(
        children: [
          const BloomMascot(size: 56, mood: BloomMood.idle),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Tap  🎮Games to start reading!',
              style: RRText.body,
            ),
          ),
        ],
      ),
    );
  }
}

class _WordChip extends StatefulWidget {
  final Map<String, dynamic> attempt;

  const _WordChip({required this.attempt});

  @override
  State<_WordChip> createState() => _WordChipState();
}

class _WordChipState extends State<_WordChip> {
  bool _pressed = false;

  String get _word =>
      (widget.attempt['words']?['text'] ?? widget.attempt['word_text'] ?? 'word')
          .toString();

  int get _score => ((widget.attempt['score'] ?? 0) as num).round();

  String get _feedback =>
      (widget.attempt['feedback'] ?? 'No feedback').toString();

  _Band get _band {
    if (_score >= 80) return _Band.got;
    if (_score >= 50) return _Band.almost;
    return _Band.again;
  }

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
    if (v) HapticFeedback.selectionClick();
  }

  void _open() {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: RRColor.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
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
            const SizedBox(height: 22),
            Text(_band.emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            Text(
              _word,
              style: const TextStyle(
                fontFamily: RRFont.reader,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: RRColor.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(_band.label,
                style: TextStyle(
                  fontFamily: RRFont.display,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _band.ink,
                )),
            const SizedBox(height: 20),
            // Teacher detail. Small on purpose.
            Text('$_feedback  ·  score $_score',
                textAlign: TextAlign.center, style: RRText.aside),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final band = _band;

    return Semantics(
      button: true,
      label: '${_word}. ${band.label}.',
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: _open,
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: Container(
            width: 116,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: band.surface,
              borderRadius: BorderRadius.circular(RRShape.radiusCard),
              border: Border.all(color: band.edge, width: 2.5),
              boxShadow: RRShape.lift(band.edge, pressed: _pressed),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(band.emoji, style: const TextStyle(fontSize: 34)),
                const SizedBox(height: 8),
                Text(
                  _word,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: RRText.word,
                ),
                const SizedBox(height: 2),
                Text(
                  band.label,
                  style: TextStyle(
                    fontFamily: RRFont.reader,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: band.ink,
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

/// Score bands. Colour is never the only signal — every band also has a
/// distinct emoji and a distinct word, so it survives colour blindness and a
/// child who cannot yet read the label.
enum _Band {
  got('🌟', 'Got it!', RRColor.mintSurface, RRColor.mint, RRColor.mintInk),
  almost('🙂', 'Almost!', RRColor.skySurface, RRColor.sky, RRColor.skyInk),
  again('🔁', 'Try again', RRColor.blossomSurface, RRColor.blossom,
      RRColor.blossomInk);

  final String emoji;
  final String label;
  final Color surface;
  final Color edge;
  final Color ink;

  const _Band(this.emoji, this.label, this.surface, this.edge, this.ink);
}

// ---------------------------------------------------------------------------
// Stats Card — 'How I'm doing'
//
// The three numbers from the old stats card are all still here (total attempts,
// average score, last attempt) and none of them lost precision. What changed is
// that each one now has a shape a child can read before the digits:
//
//   Average score   -> a half-dial with three named zones, so the number has a
//                      position, not just a value. Bloom's face sits in the
//                      middle and matches the zone.
//   Total attempts  -> a big count with a row of mic tokens under it, capped at
//                      ten so it stays countable.
//   Last attempt    -> 'Today' / 'Yesterday' / 'N days ago', with the exact
//                      timestamp kept in the teacher aside at the bottom.
//
// The week strip is new: seven dots, one per day, filled where there is at
// least one attempt. It answers 'have I practised lately' spatially, and it is
// the one place a habit is visible at all.
// ---------------------------------------------------------------------------
class _StatsCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> attempts;

  const _StatsCard({required this.stats, required this.attempts});

  double get _avg => ((stats['avgScore'] ?? 0) as num).toDouble();

  int get _totalAttempts => ((stats['totalAttempts'] ?? 0) as num).round();

  @override
  Widget build(BuildContext context) {
    final lastDate = _parseDate(stats['lastAttempt']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: const Text('🏆 My Progress', style: RRText.section),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          decoration: BoxDecoration(
            color: RRColor.card,
            borderRadius: BorderRadius.circular(RRShape.radiusCard),
            border: Border.all(color: RRColor.lilac, width: 2.5),
            boxShadow: RRShape.lift(RRColor.lilac),
          ),
          child: Column(
            children: [
              _ScoreGauge(value: _avg),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      emoji: '🎤',
                      value: '$_totalAttempts',
                      label: 'times I read',
                      surface: RRColor.skySurface,
                      edge: RRColor.skyGlow,
                      ink: RRColor.skyInk,
                      tokens: _totalAttempts,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _StatTile(
                      emoji: '📅',
                      value: _relativeDay(lastDate),
                      label: 'last practice',
                      surface: RRColor.blossomSurface,
                      edge: RRColor.blossomGlow,
                      ink: RRColor.blossomInk,
                      valueFontSize: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _WeekStrip(attempts: attempts),
              const SizedBox(height: 14),
              // Teacher aside. Full precision, deliberately quiet.
              Text(
                'Average ${_avg.toStringAsFixed(1)}  ·  '
                '$_totalAttempts attempts  ·  '
                'last ${_formatDate(stats['lastAttempt']?.toString())}',
                textAlign: TextAlign.center,
                style: RRText.aside,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Half-dial for the average score.
///
/// Zones are named, not just coloured: a child is told 'Great' or 'Getting
/// there', and the needle's position says the same thing without the words.
class _ScoreGauge extends StatelessWidget {
  final double value; // 0..100

  const _ScoreGauge({required this.value});

  _Band get _band {
    if (value >= 80) return _Band.got;
    if (value >= 50) return _Band.almost;
    return _Band.again;
  }

  String get _zoneWord {
    if (value >= 80) return '⭐ Super Star! ⭐';
    if (value >= 50) return '🚀 Keep Going! 🚀';
    return '📖 Time to Read! 📖';
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final band = _band;

    return Semantics(
      label: 'Your average score is ${value.round()} out of 100. $_zoneWord',
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            width: 236,
            height: 138,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: reduceMotion ? value : 0,
                    end: value.clamp(0, 100),
                  ),
                  duration: Duration(milliseconds: reduceMotion ? 0 : 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => CustomPaint(
                    size: const Size(236, 138),
                    painter: _GaugePainter(v, band.edge),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(band.emoji, style: const TextStyle(fontSize: 30)),
                      const SizedBox(height: 2),
                      Text(
                        '${value.round()}',
                        style: TextStyle(
                          fontFamily: RRFont.display,
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          color: band.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _zoneWord,
            style: TextStyle(
              fontFamily: RRFont.display,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: band.ink,
            ),
          ),
          const SizedBox(height: 2),
          const Text('my score', style: RRText.body),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value; // 0..100
  final Color fill;

  _GaugePainter(this.value, this.fill);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final center = Offset(size.width / 2, size.height - stroke * 0.6);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Three named zones on the track, so the dial has landmarks.
    void zone(double from, double to, Color color) {
      canvas.drawArc(
        rect,
        math.pi + math.pi * (from / 100),
        math.pi * ((to - from) / 100),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = color,
      );
    }

    zone(0, 50, RRColor.blossomSurface);
    zone(50, 80, RRColor.skySurface);
    zone(80, 100, RRColor.mintSurface);

    // Filled portion.
    final v = value.clamp(0.0, 100.0);
    if (v > 0) {
      canvas.drawArc(
        rect,
        math.pi,
        math.pi * (v / 100),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = fill,
      );
    }

    // Knob at the current value — the 'you are here' marker.
    final angle = math.pi + math.pi * (v / 100);
    final knob = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    canvas.drawCircle(knob, stroke * 0.62, Paint()..color = Colors.white);
    canvas.drawCircle(
      knob,
      stroke * 0.62,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = fill,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value || old.fill != fill;
}

/// One number, one emoji, and — where the number is a count — a row of tokens
/// under it so the quantity is visible as well as written.
class _StatTile extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color surface;
  final Color edge;
  final Color ink;
  final int? tokens;
  final double valueFontSize;

  const _StatTile({
    required this.emoji,
    required this.value,
    required this.label,
    required this.surface,
    required this.edge,
    required this.ink,
    this.tokens,
    this.valueFontSize = 30,
  });

  @override
  Widget build(BuildContext context) {
    final capped = tokens == null ? 0 : (tokens! > 10 ? 10 : tokens!);

    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(RRShape.radiusChip),
          border: Border.all(color: edge, width: 2),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: RRFont.display,
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  color: ink,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: RRFont.reader,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            if (capped > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: List.generate(
                  capped,
                  (_) => Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: edge, shape: BoxShape.circle),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Seven dots, oldest to newest, filled on days with at least one attempt.
///
/// Renders as an empty week rather than disappearing when no attempt row
/// carries a parseable date — an empty week is still true and still an
/// invitation; a missing widget is a layout that shifts under the child.
class _WeekStrip extends StatelessWidget {
  final List<Map<String, dynamic>> attempts;

  const _WeekStrip({required this.attempts});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final active = <DateTime>{};
    for (final a in attempts) {
      final d = _parseDate(
        a['created_at'] ?? a['attempt_date'] ?? a['timestamp'] ?? a['inserted_at'],
      );
      if (d != null) active.add(DateTime(d.year, d.month, d.day));
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final day = today.subtract(Duration(days: 6 - i));
            final practised = active.contains(day);
            final isToday = i == 6;

            return Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: practised ? RRColor.mint : RRColor.lilacSurface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isToday
                          ? RRColor.ink
                          : (practised ? RRColor.mintInk : RRColor.lilac),
                      width: isToday ? 2.5 : 1.5,
                    ),
                  ),
                  child: practised
                      ? const Icon(Icons.check_rounded,
                          size: 18, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 5),
                Text(
                  DateFormat('E').format(day).substring(0, 1),
                  style: TextStyle(
                    fontFamily: RRFont.reader,
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                    color: isToday ? RRColor.ink : RRColor.inkSoft,
                  ),
                ),
              ],
            );
          }),
        ),
        const SizedBox(height: 8),
        const Text('my week', style: RRText.body),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Date helpers — formatDate is carried over verbatim from progress.dart.
// ---------------------------------------------------------------------------
DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final s = value.toString();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

String _formatDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return 'N/A';
  try {
    final date = DateTime.parse(dateStr);
    return DateFormat('MMM d, yyyy • h:mm a').format(date);
  } catch (_) {
    return dateStr;
  }
}

/// 'Today' beats a timestamp for a child who cannot yet read a date.
String _relativeDay(DateTime? date) {
  if (date == null) return '—';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final then = DateTime(date.year, date.month, date.day);
  final days = today.difference(then).inDays;

  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  if (days < 14) return 'Last week';
  return DateFormat('MMM d').format(date);
}

// ---------------------------------------------------------------------------
// Loading + error
//
// Both were bare: a spinner, and red 18px text. Neither told a child anything.
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
          Text('Getting your words ready…', style: RRText.body),
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

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BloomMascot(size: 120, mood: BloomMood.idle),
            const SizedBox(height: 20),
            const Text('Bloom lost your words', style: RRText.section),
            const SizedBox(height: 8),
            const Text(
              'Tap the big button to look again.',
              textAlign: TextAlign.center,
              style: RRText.body,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 72,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 30),
                label: const Text(
                  'Try again',
                  style: TextStyle(
                    fontFamily: RRFont.display,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: RRColor.sky,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Teacher-facing detail, deliberately small and quiet so it reads
            // as "not for you" to a six-year-old.
            Text(message, textAlign: TextAlign.center, style: RRText.aside),
          ],
        ),
      ),
    );
  }
}