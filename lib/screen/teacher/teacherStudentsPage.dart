// lib/screen/teacher/teacherStudentsPage.dart
//
// The Students tab — the single home for the roster.
//
// This absorbs three previous surfaces:
//   * the student list that used to sit at the bottom of the dashboard
//   * ManageStudentsPage (whose only unique power was delete)
//   * teacherSettings.dart (whose entire content was a per-student
//     save_audio toggle — student management wearing a different hat)
//
// Every action on a student now happens either on the row or in that row's
// sheet. One tab in, one place per child.
//
// Queries are unchanged: the roster comes from TeacherProvider exactly as
// before, and the save_audio read/write are the same two Supabase calls lifted
// verbatim out of teacherSettings.dart.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:readright/config/theme.dart';
import 'package:readright/providers/teacherProvider.dart';
import 'package:readright/screen/teacher/teacherStudentView.dart';
import 'package:readright/widgets/bloom_mascot.dart';
import 'package:readright/widgets/teacher_base_scaffold.dart';
import 'package:readright/widgets/teacher_student_forms.dart';

class TeacherStudentsPage extends StatelessWidget {
  const TeacherStudentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TeacherProvider(),
      child: const _TeacherStudentsView(),
    );
  }
}

class _TeacherStudentsView extends StatefulWidget {
  const _TeacherStudentsView();

  @override
  State<_TeacherStudentsView> createState() => _TeacherStudentsViewState();
}

class _TeacherStudentsViewState extends State<_TeacherStudentsView> {
  final supabase = Supabase.instance.client;
  final TextEditingController _search = TextEditingController();

  String _query = '';

  /// student id -> save_audio. Loaded once; the switch writes through.
  Map<String, bool> _saveAudio = {};

  @override
  void initState() {
    super.initState();
    _loadSaveAudio();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // Same two queries as the old settings page.
  Future<void> _loadSaveAudio() async {
    final teacher = supabase.auth.currentUser;
    if (teacher == null) return;

    final classRow = await supabase
        .from('classes')
        .select('id')
        .eq('teacher_id', teacher.id)
        .maybeSingle();

    if (classRow == null || classRow['id'] == null) return;

    final rows = await supabase
        .from('users')
        .select('id, save_audio')
        .eq('role', 'student')
        .eq('class_id', classRow['id']);

    if (!mounted) return;
    setState(() {
      _saveAudio = {
        for (final r in rows) r['id'] as String: (r['save_audio'] ?? true) as bool,
      };
    });
  }

  Future<void> _updateSaveAudio(String userId, bool newValue) async {
    setState(() => _saveAudio[userId] = newValue);
    await supabase
        .from('users')
        .update({'save_audio': newValue})
        .eq('id', userId);
  }

  void _openAddSheet(TeacherProvider provider) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: RRColor.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
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
              const SizedBox(height: 20),
              _SheetAction(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Add one student',
                subtitle: 'Enter their name, email and password.',
                surface: RRColor.mintSurface,
                edge: RRColor.mint,
                ink: RRColor.mintInk,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showFormSheet(AddStudentForm(provider: provider));
                },
              ),
              const SizedBox(height: 12),
              _SheetAction(
                icon: Icons.upload_file_rounded,
                title: 'Bulk upload',
                subtitle: 'Import a class list from a CSV file.',
                surface: RRColor.skySurface,
                edge: RRColor.sky,
                ink: RRColor.skyInk,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showFormSheet(BulkUploadStudentForm(provider: provider));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFormSheet(Widget form) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RRColor.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: form,
      ),
    );
    // A new student needs a save_audio entry before their switch renders.
    await _loadSaveAudio();
  }

  void _openStudentSheet(TeacherProvider provider, dynamic student) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: RRColor.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final id = student.id as String;
            final keeping = _saveAudio[id] ?? true;

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: RRColor.lilac,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    student.name,
                    style: const TextStyle(
                      fontFamily: RRFont.display,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: RRColor.ink,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Audio retention — the whole of the old Settings tab.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: RRColor.canvas,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: RRColor.lilac, width: 2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.mic_rounded,
                            size: 22, color: RRColor.inkSoft),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Keep audio recordings',
                                style: TextStyle(
                                  fontFamily: RRFont.reader,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: RRColor.ink,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Stores this student’s practice recordings.',
                                style: RRText.aside,
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: keeping,
                          activeThumbColor: RRColor.mint,
                          onChanged: (v) async {
                            HapticFeedback.selectionClick();
                            setSheetState(() {});
                            await _updateSaveAudio(id, v);
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  _SheetAction(
                    icon: Icons.bar_chart_rounded,
                    title: 'View attempts',
                    subtitle: 'Every word this student has practised.',
                    surface: RRColor.skySurface,
                    edge: RRColor.sky,
                    ink: RRColor.skyInk,
                    onTap: () {
                      Navigator.pop(sheetContext);
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
                  ),

                  const SizedBox(height: 12),

                  _SheetAction(
                    icon: Icons.person_remove_rounded,
                    title: 'Remove student',
                    subtitle: 'Takes them out of this class.',
                    surface: RRColor.blossomSurface,
                    edge: RRColor.blossom,
                    ink: RRColor.blossomInk,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _confirmRemove(provider, student);
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Same confirm-then-remove flow as ManageStudentsPage.
  Future<void> _confirmRemove(
      TeacherProvider provider, dynamic student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: RRColor.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          'Remove student',
          style: TextStyle(
            fontFamily: RRFont.display,
            fontWeight: FontWeight.w800,
            color: RRColor.ink,
          ),
        ),
        content: Text(
          'Are you sure you want to remove ${student.name}?',
          style: RRText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: RRColor.inkSoft),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: RRColor.blossomInk),
            child: const Text(
              'Remove',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final error = await provider.removeStudent(student.id);

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    // Required for auto refresh
    await provider.loadDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TeacherProvider>(
      builder: (context, provider, _) {
        final all = provider.students;
        final filtered = _query.isEmpty
            ? all
            : all
                .where((s) => (s.name as String)
                    .toLowerCase()
                    .contains(_query.toLowerCase()))
                .toList();

        return TeacherBaseScaffold(
          currentIndex: 1,
          pageTitle: 'Students',
          pageIcon: Icons.people_rounded,
          actions: [
            IconButton(
              iconSize: 24,
              tooltip: 'Add student',
              icon: const Icon(Icons.person_add_alt_1_rounded,
                  color: Colors.white),
              onPressed: () => _openAddSheet(provider),
            ),
          ],
          body: SafeArea(
            child: RefreshIndicator(
              color: RRColor.mint,
              onRefresh: () async {
                await provider.refreshDashboard();
                await _loadSaveAudio();
              },
              child: provider.dashboardLoading
                  ? const _LoadingView()
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        if (all.isNotEmpty) ...[
                          _SearchField(
                            controller: _search,
                            onChanged: (v) => setState(() => _query = v),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _query.isEmpty
                                ? '${all.length} ${all.length == 1 ? 'student' : 'students'}'
                                : '${filtered.length} of ${all.length}',
                            style: RRText.aside,
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (all.isEmpty)
                          _EmptyRoster(onAdd: () => _openAddSheet(provider))
                        else if (filtered.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text('No student by that name.',
                                  style: RRText.body),
                            ),
                          )
                        else
                          ...filtered.map(
                            (s) => _StudentTile(
                              student: s,
                              onOpen: () {
                                HapticFeedback.selectionClick();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StudentAttemptsScreen(
                                      studentId: s.id,
                                      studentName: s.name,
                                    ),
                                  ),
                                );
                              },
                              onMore: () => _openStudentSheet(provider, s),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(
        fontFamily: RRFont.reader,
        fontSize: 16,
        color: RRColor.ink,
      ),
      decoration: InputDecoration(
        hintText: 'Search students',
        hintStyle: const TextStyle(
          fontFamily: RRFont.reader,
          fontSize: 16,
          color: RRColor.inkSoft,
        ),
        prefixIcon: const Icon(Icons.search_rounded, color: RRColor.inkSoft),
        filled: true,
        fillColor: RRColor.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: RRColor.lilac, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: RRColor.mint, width: 2.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: RRColor.lilac, width: 2),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Student row
//
// Tap opens their attempts; the trailing button opens everything else. Two
// targets, so the common action doesn't sit behind a menu.
// ---------------------------------------------------------------------------
class _StudentTile extends StatelessWidget {
  final dynamic student;
  final VoidCallback onOpen;
  final VoidCallback onMore;

  const _StudentTile({
    required this.student,
    required this.onOpen,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final name = student.name as String;
    final accuracy = (student.accuracy as num).toInt();
    final progress = (student.progress as num).toDouble();
    final up = student.trendingUp as bool;

    final trendColor = up ? RRColor.mintInk : RRColor.sunnyInk;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: RRColor.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: RRColor.lilac, width: 2),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: '$name, accuracy $accuracy percent. View attempts.',
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onOpen,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 4, 10),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: RRColor.mintSurface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: RRColor.mint, width: 2),
                              ),
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontFamily: RRFont.display,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: RRColor.mintInk,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                name,
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
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: trendColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Student options',
                  iconSize: 24,
                  color: RRColor.inkSoft,
                  icon: const Icon(Icons.more_vert_rounded),
                  onPressed: onMore,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: RRColor.lilacSurface,
                  color: up ? RRColor.mint : RRColor.sunny,
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
// Sheet action row
// ---------------------------------------------------------------------------
class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color surface;
  final Color edge;
  final Color ink;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.surface,
    required this.edge,
    required this.ink,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: edge, width: 2),
          ),
          child: Row(
            children: [
              Icon(icon, size: 24, color: ink),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: RRFont.display,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: RRFont.reader,
                        fontSize: 13,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 24, color: ink),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty + loading
// ---------------------------------------------------------------------------
class _EmptyRoster extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyRoster({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Column(
        children: [
          const BloomMascot(size: 110, mood: BloomMood.idle, glasses: true),
          const SizedBox(height: 18),
          const Text(
            'No students yet',
            style: TextStyle(
              fontFamily: RRFont.display,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: RRColor.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add them one at a time, or import a CSV.',
            textAlign: TextAlign.center,
            style: RRText.body,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 22),
              label: const Text(
                'Add students',
                style: TextStyle(
                  fontFamily: RRFont.display,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: RRColor.mint,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 26),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
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
              Text('Loading your roster…', style: RRText.body),
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
