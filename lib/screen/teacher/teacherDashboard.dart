// lib/screen/teacherDashboard.dart
//
// The Class tab — read-only monitoring.
//
// Everything that creates or edits a student record has left this screen: Add
// Student, Bulk Upload, and Manage Students now belong to the Students tab, and
// the Story Builder button is now its own tab. What remains answers one
// question a teacher asks on a Monday morning: who needs me this week?
//
// Reading order: class health -> which words are failing -> which children to
// look at. Every number that names a group of students is tappable and lands on
// the Students tab, so this screen points rather than does.
//
// Provider calls are unchanged: refreshDashboard, createClass, and the same
// fields the old screen read. No new queries.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:readright/config/theme.dart';
import 'package:readright/providers/teacherProvider.dart';
import 'package:readright/screen/teacher/teacherStudentView.dart';
import 'package:readright/widgets/bloom_mascot.dart';
import 'package:readright/widgets/teacher_base_scaffold.dart';

/// Accuracy at or below this is treated as "needs attention" for the watch
/// list below.
///
/// NOTE: this is a presentation-level threshold applied to students the
/// provider has already loaded — it adds no query. If TeacherProvider computes
/// needsHelpCount with a different rule, these two numbers can disagree; worth
/// exposing the provider's own predicate later so there's one definition.
const double kNeedsAttentionAccuracy = 70;

/// How many students the watch list shows before deferring to the Students tab.
const int kWatchListLength = 4;

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    // TeacherProvider is hoisted above the routes in main.dart, so every
    // teacher tab shares one instance and one load. Creating it here instead
    // meant each tab switch built a fresh provider and refetched the class.
    return const _TeacherDashboardView();
  }
}

class _TeacherDashboardView extends StatelessWidget {
  const _TeacherDashboardView();

  @override
  Widget build(BuildContext context) {
    return Consumer<TeacherProvider>(
      builder: (context, provider, _) {
        // A teacher with no class has exactly one thing they can do, so this is
        // a gate rather than a card buried in a scroll.
        if (provider.needsClassCreated) {
          return TeacherBaseScaffold(
            currentIndex: 0,
            pageTitle: 'Set up class',
            pageIcon: Icons.school_rounded,
            body: SafeArea(child: _CreateClassGate(provider: provider)),
          );
        }

        return TeacherBaseScaffold(
          currentIndex: 0,
          pageTitle: 'Class',
          pageIcon: Icons.insights_rounded,
          body: SafeArea(
            child: RefreshIndicator(
              color: RRColor.mint,
              onRefresh: provider.refreshDashboard,
              child: provider.dashboardLoading
                  ? const _LoadingView()
                  : provider.dashboardError != null
                      ? _ErrorView(message: provider.dashboardError!)
                      : _DashboardBody(provider: provider),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------
class _DashboardBody extends StatelessWidget {
  final TeacherProvider provider;

  const _DashboardBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    // Lowest accuracy first — the top of this list is who to call over.
    final watchList = [...provider.students]
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));

    final flagged = watchList
        .where((s) => s.accuracy <= kNeedsAttentionAccuracy)
        .toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _ClassHeader(
          studentCount: provider.students.length,
          average: provider.classAverageAccuracy,
        ),
        const SizedBox(height: 20),
        _StatRow(provider: provider),
        const SizedBox(height: 20),
        _MostMissedCard(provider: provider),
        const SizedBox(height: 20),
        _WatchListCard(
          flagged: flagged.take(kWatchListLength).toList(),
          totalStudents: provider.students.length,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header — Bloom in reading glasses.
// ---------------------------------------------------------------------------
class _ClassHeader extends StatelessWidget {
  final int studentCount;
  final double average;

  const _ClassHeader({required this.studentCount, required this.average});

  BloomMood get _mood {
    if (studentCount == 0) return BloomMood.idle;
    if (average >= 80) return BloomMood.cheer;
    if (average >= 60) return BloomMood.happy;
    return BloomMood.confused;
  }

  String get _line {
    if (studentCount == 0) return 'No students yet.';
    if (average >= 80) return 'Your class is flying.';
    if (average >= 60) return 'Steady progress this week.';
    return 'A few readers could use a hand.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: RRColor.card,
        borderRadius: BorderRadius.circular(RRShape.radiusCard),
        border: Border.all(color: RRColor.lilac, width: 2.5),
        boxShadow: RRShape.lift(RRColor.lilac),
      ),
      child: Row(
        children: [
          BloomMascot(size: 78, mood: _mood, glasses: true),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Class overview',
                  style: TextStyle(
                    fontFamily: RRFont.display,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: RRColor.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(_line, style: RRText.body),
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
                    '$studentCount ${studentCount == 1 ? 'student' : 'students'}',
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
// Stat row
//
// Was three bare numbers in a card, one of them red. 'Needs Help' is now a
// button — a count of struggling students is useless unless it takes you to
// them.
// ---------------------------------------------------------------------------
class _StatRow extends StatelessWidget {
  final TeacherProvider provider;

  const _StatRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    final avg = provider.classAverageAccuracy;

    final Color avgSurface = avg >= 80
        ? RRColor.mintSurface
        : avg >= 60
            ? RRColor.skySurface
            : RRColor.blossomSurface;
    final Color avgEdge = avg >= 80
        ? RRColor.mint
        : avg >= 60
            ? RRColor.sky
            : RRColor.blossom;
    final Color avgInk = avg >= 80
        ? RRColor.mintInk
        : avg >= 60
            ? RRColor.skyInk
            : RRColor.blossomInk;

    // IntrinsicHeight is what makes CrossAxisAlignment.stretch legal here.
    // This Row is a direct child of a ListView, so its vertical constraint is
    // unbounded; stretch without a bounded height throws
    // 'BoxConstraints forces an infinite height' on every frame. Intrinsic
    // measures the tallest tile first, then all three match it — which is the
    // reason for stretch in the first place, since 'Top reader' wraps to two
    // lines when a name is long and the other two tiles shouldn't shrink.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Expanded(
          child: _StatTile(
            icon: Icons.speed_rounded,
            value: '${avg.toStringAsFixed(0)}%',
            label: 'Avg. accuracy',
            surface: avgSurface,
            edge: avgEdge,
            ink: avgInk,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.emoji_events_rounded,
            value: provider.topPerformerName ?? '—',
            label: 'Top reader',
            surface: RRColor.sunnyGlow,
            edge: RRColor.sunny,
            ink: RRColor.sunnyInk,
            valueFontSize: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.flag_rounded,
            value: '${provider.needsHelpCount}',
            label: 'Need help',
            surface: RRColor.lilacSurface,
            edge: RRColor.lilac,
            ink: RRColor.lilacInk,
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pushReplacementNamed(
                  context, kTeacherTabRoutes[1]);
            },
          ),
        ),
      ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color surface;
  final Color edge;
  final Color ink;
  final double valueFontSize;
  final VoidCallback? onTap;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.surface,
    required this.edge,
    required this.ink,
    this.valueFontSize = 26,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: edge, width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: ink),
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(height: 4),
            Icon(Icons.arrow_forward_rounded, size: 14, color: ink),
          ],
        ],
      ),
    );

    if (onTap == null) return tile;

    return Semantics(
      button: true,
      label: '$label: $value. Opens the student list.',
      excludeSemantics: true,
      child: GestureDetector(onTap: onTap, child: tile),
    );
  }
}

// ---------------------------------------------------------------------------
// Most missed words
//
// Was a right-aligned column of red percentages. A bar makes the gap between
// the worst word and the merely tricky one visible at a glance, which the
// numbers alone did not.
// ---------------------------------------------------------------------------
class _MostMissedCard extends StatelessWidget {
  final TeacherProvider provider;

  const _MostMissedCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return _Card(
      icon: Icons.warning_amber_rounded,
      iconColor: RRColor.blossomInk,
      title: 'Most missed words',
      child: Builder(
        builder: (context) {
          if (provider.mostMissedLoading) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: CircularProgressIndicator(color: RRColor.mint),
              ),
            );
          }
          if (provider.mostMissedError != null) {
            return Text(provider.mostMissedError!,
                style: const TextStyle(
                  fontFamily: RRFont.reader,
                  fontSize: 14,
                  color: RRColor.blossomInk,
                ));
          }
          if (provider.mostMissedWords.isEmpty) {
            return const Text('No data yet.', style: RRText.body);
          }

          return Column(
            children: provider.mostMissedWords.map((row) {
              final score = (row['avg_score'] as num).toDouble();
              final attempts = row['attempts'];

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        row['word'],
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: RRFont.reader,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: RRColor.ink,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (score / 100).clamp(0.0, 1.0),
                          minHeight: 12,
                          backgroundColor: RRColor.lilacSurface,
                          color: score >= 60
                              ? RRColor.sky
                              : RRColor.blossom,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 78,
                      child: Text(
                        '${score.toStringAsFixed(0)}% · $attempts',
                        textAlign: TextAlign.right,
                        style: RRText.aside,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Watch list
//
// The old screen printed every student here, which made the roster and the
// dashboard the same thing. This shows only who is below the threshold, and
// hands off to the Students tab for everyone else.
// ---------------------------------------------------------------------------
class _WatchListCard extends StatelessWidget {
  final List<dynamic> flagged;
  final int totalStudents;

  const _WatchListCard({required this.flagged, required this.totalStudents});

  @override
  Widget build(BuildContext context) {
    return _Card(
      icon: Icons.visibility_rounded,
      iconColor: RRColor.skyInk,
      title: 'Keep an eye on',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (totalStudents == 0)
            const Text(
              'No students yet. Add them from the Students tab.',
              style: RRText.body,
            )
          else if (flagged.isEmpty)
            Row(
              children: [
                const BloomMascot(
                    size: 48, mood: BloomMood.cheer, glasses: true),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Nobody is falling behind right now.',
                    style: RRText.body,
                  ),
                ),
              ],
            )
          else
            ...flagged.map((s) => _StudentRow(student: s)),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pushReplacementNamed(context, kTeacherTabRoutes[1]);
            },
            style: TextButton.styleFrom(foregroundColor: RRColor.skyInk),
            child: Text(
              totalStudents == 0
                  ? 'Go to Students'
                  : 'See all $totalStudents students',
              style: const TextStyle(
                fontFamily: RRFont.display,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final dynamic student;

  const _StudentRow({required this.student});

  @override
  Widget build(BuildContext context) {
    final accuracy = (student.accuracy as num).toInt();
    final progress = (student.progress as num).toDouble();
    final up = student.trendingUp as bool;

    // Trend uses mint up / sunny down rather than green/red. Falling behind is
    // information, not an alarm, and red-on-green is the pair to avoid.
    final trendColor = up ? RRColor.mintInk : RRColor.sunnyInk;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        label: '${student.name}, accuracy $accuracy percent',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StudentAttemptsScreen(
                  studentId: student.id,
                  studentName: student.name,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: RRColor.canvas,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: RRColor.lilac, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        student.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: RRFont.display,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: RRColor.ink,
                        ),
                      ),
                    ),
                    Icon(
                      up
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 20,
                      color: trendColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$accuracy%',
                      style: TextStyle(
                        fontFamily: RRFont.display,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: trendColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: RRColor.lilacSurface,
                    color: up ? RRColor.mint : RRColor.sunny,
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
// Shared card shell
// ---------------------------------------------------------------------------
class _Card extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _Card({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RRColor.card,
        borderRadius: BorderRadius.circular(RRShape.radiusCard),
        border: Border.all(color: RRColor.lilac, width: 2.5),
        boxShadow: RRShape.lift(RRColor.lilac),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: RRFont.display,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: RRColor.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// First-run gate
//
// Was a card inside the dashboard scroll that suppressed everything below it.
// A teacher with no class has one available action, so it gets the screen.
// ---------------------------------------------------------------------------
class _CreateClassGate extends StatefulWidget {
  final TeacherProvider provider;

  const _CreateClassGate({required this.provider});

  @override
  State<_CreateClassGate> createState() => _CreateClassGateState();
}

class _CreateClassGateState extends State<_CreateClassGate> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _create() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    HapticFeedback.mediumImpact();
    widget.provider.createClass(name);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BloomMascot(
                size: 110, mood: BloomMood.happy, glasses: true),
            const SizedBox(height: 18),
            const Text(
              'Create your class',
              style: TextStyle(
                fontFamily: RRFont.display,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: RRColor.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Name it something your students will recognise.',
              textAlign: TextAlign.center,
              style: RRText.body,
            ),
            const SizedBox(height: 26),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _create(),
              decoration: InputDecoration(
                labelText: 'Class name',
                filled: true,
                fillColor: RRColor.card,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                labelStyle: const TextStyle(
                  fontFamily: RRFont.reader,
                  fontSize: 16,
                  color: RRColor.inkSoft,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: RRColor.lilac, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: RRColor.mint, width: 2.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: RRColor.lilac, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: RRColor.mint,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Create class',
                  style: TextStyle(
                    fontFamily: RRFont.display,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading + error
// ---------------------------------------------------------------------------
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 90),
        Center(
          child: Column(
            children: [
              BloomMascot(
                  size: 110, mood: BloomMood.sleepy, glasses: true),
              SizedBox(height: 18),
              Text('Loading your class…', style: RRText.body),
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
                  'Could not load the class',
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