// lib/screen/ai_story_builder.dart
//
// The Stories tab.
//
// Biggest change is structural: this was a bare Scaffold with its own green
// AppBar, so opening it dropped a teacher out of the app entirely — no nav bar,
// no way back except the system gesture. It now lives inside
// TeacherBaseScaffold at index 3, which is what the new Stories tab points at.
//
// Design changes:
//   * Reading level and interest become chip grids instead of dropdowns. Ten
//     interests behind a dropdown is ten taps to browse; as chips it's one
//     glance, and the emoji make it scannable.
//   * Generation can take up to 60 seconds, and the old screen showed only a
//     18px spinner inside the button. There's now a real waiting state.
//   * The story result is set for reading, not for inspecting a payload.
//
// All logic is unchanged: the backend URLs, the Dolch lookup, the POST, the
// timeout, and the JSON handling are all exactly as they were.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:readright/config/theme.dart';
import 'package:readright/providers/teacherProvider.dart';
import 'package:readright/services/databaseHelper.dart';
import 'package:readright/widgets/auth_ui.dart';
import 'package:readright/widgets/bloom_mascot.dart';
import 'package:readright/widgets/teacher_base_scaffold.dart';

class AIStoryBuilderPage extends StatefulWidget {
  const AIStoryBuilderPage({super.key});

  @override
  State<AIStoryBuilderPage> createState() => _AIStoryBuilderPageState();
}

class _AIStoryBuilderPageState extends State<AIStoryBuilderPage> {
  String? _selectedStudentId;
  String _selectedLevel = 'Primer';
  String _selectedInterest = 'Animals';

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _storyResponse;

  static const List<String> _levels = <String>[
    'Pre-Primer',
    'Primer',
    'First Grade',
    'Second Grade',
    'Third Grade',
  ];

  static const List<String> _interests = <String>[
    'Animals',
    'Dinosaurs',
    'Space',
    'Sports',
    'Ocean',
    'Princesses',
    'Cars',
    'School',
    'Farm',
    'Adventure',
  ];

  /// Presentation only — the string sent to the backend is still the plain
  /// label above.
  static const Map<String, String> _interestEmoji = <String, String>{
    'Animals': '🐾',
    'Dinosaurs': '🦕',
    'Space': '🚀',
    'Sports': '⚽',
    'Ocean': '🌊',
    'Princesses': '👑',
    'Cars': '🚗',
    'School': '🏫',
    'Farm': '🚜',
    'Adventure': '🗺️',
  };

  static const String _webBackendBaseUrl = 'http://localhost:3000';
  static const String _androidEmulatorBackendBaseUrl = 'http://10.0.2.2:3000';

  String get _backendBaseUrl {
    // If you add STORY_BACKEND_URL to backend/.env and want to use it in Flutter,
    // you can expose it however your app already handles env values.
    // This fallback works immediately for local dev.
    return kIsWeb ? _webBackendBaseUrl : _androidEmulatorBackendBaseUrl;
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  StudentDashboardItem? _selectedStudent(List<StudentDashboardItem> students) {
    for (final student in students) {
      if (student.id == _selectedStudentId) return student;
    }
    return null;
  }

  Future<List<String>> _loadDolchWordsForLevel(String level) async {
    final db = DatabaseHelper.instance;
    final normalizedTarget = _normalize(level);
    final desiredOrder = _levelOrder(level);

    final wordLists = await db.fetchWordLists();

    Map<String, dynamic>? selectedList;
    for (final row in wordLists) {
      final title = (row['title'] ?? '').toString();
      final listOrder = row['list_order'];

      if (_normalize(title) == normalizedTarget) {
        selectedList = row;
        break;
      }

      final parsedOrder = int.tryParse(listOrder?.toString() ?? '');
      if (desiredOrder != null && parsedOrder == desiredOrder) {
        selectedList = row;
        break;
      }
    }

    if (selectedList == null) {
      return <String>[];
    }

    final listId = selectedList['id']?.toString();
    if (listId == null || listId.isEmpty) {
      return <String>[];
    }

    final words = await db.fetchWordsByList(listId);
    final result = <String>[];

    for (final row in words) {
      final text = row['text']?.toString().trim();
      if (text != null && text.isNotEmpty) {
        result.add(text);
      }
    }

    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  int? _levelOrder(String level) {
    switch (level) {
      case 'Pre-Primer':
        return 1;
      case 'Primer':
        return 2;
      case 'First Grade':
        return 3;
      case 'Second Grade':
        return 4;
      case 'Third Grade':
        return 5;
      default:
        return null;
    }
  }

  Future<void> _generateStory(List<StudentDashboardItem> students) async {
    final student = _selectedStudent(students);

    if (student == null) {
      setState(() {
        _error = 'Please choose a student.';
        _storyResponse = null;
      });
      return;
    }

    if (_selectedLevel.trim().isEmpty) {
      setState(() {
        _error = 'Please choose a reading level.';
        _storyResponse = null;
      });
      return;
    }

    if (_selectedInterest.trim().isEmpty) {
      setState(() {
        _error = 'Please choose an interest.';
        _storyResponse = null;
      });
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _isLoading = true;
      _error = null;
      _storyResponse = null;
    });

    try {
      final dolchWords = await _loadDolchWordsForLevel(_selectedLevel);

      if (dolchWords.isEmpty) {
        setState(() {
          _error = 'No Dolch words found for $_selectedLevel.';
        });
        return;
      }

      final response = await http
          .post(
            Uri.parse('$_backendBaseUrl/generate-story'),
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'studentId': student.id,
              'studentName': student.name,
              'readingLevel': _selectedLevel,
              'interest': _selectedInterest,
              'dolchWords': dolchWords,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (!mounted) return;

      final decoded = _tryDecodeJson(response.body);

      if (response.statusCode != 200) {
        setState(() {
          _error = decoded?['error']?.toString() ??
              'Request failed with status ${response.statusCode}.';
        });
        return;
      }

      if (decoded == null) {
        setState(() {
          _error = 'Backend returned invalid JSON.';
        });
        return;
      }

      setState(() {
        _storyResponse = decoded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach the backend: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic>? _tryDecodeJson(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TeacherProvider>(
      builder: (context, provider, _) {
        final students = provider.students;
        final selectedStudentStillExists =
            students.any((student) => student.id == _selectedStudentId);

        if (!selectedStudentStillExists) {
          _selectedStudentId = null;
        }

        return TeacherBaseScaffold(
          currentIndex: 3,
          pageTitle: 'Stories',
          pageIcon: Icons.auto_stories_rounded,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildIntroCard(),
                  const SizedBox(height: 18),
                  _buildSelectionCard(
                    context,
                    students,
                    provider.dashboardLoading,
                  ),
                  const SizedBox(height: 18),
                  _buildGenerateButton(students),
                  const SizedBox(height: 10),
                  Text(
                    'Backend: $_backendBaseUrl',
                    textAlign: TextAlign.center,
                    style: RRText.aside,
                  ),
                  if (_isLoading) ...[
                    const SizedBox(height: 20),
                    const _WaitingCard(),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 18),
                    AuthMessage(text: _error!),
                  ],
                  if (_storyResponse != null) ...[
                    const SizedBox(height: 18),
                    _buildResultCard(_storyResponse!),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Intro
  // -------------------------------------------------------------------------
  Widget _buildIntroCard() {
    return _Card(
      child: Row(
        children: [
          const BloomMascot(size: 72, mood: BloomMood.happy, glasses: true),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Write a story',
                  style: TextStyle(
                    fontFamily: RRFont.display,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: RRColor.ink,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Pick a student, a level, and something they like. '
                  'The story is built from that level’s Dolch words.',
                  style: RRText.body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Settings
  // -------------------------------------------------------------------------
  Widget _buildSelectionCard(
    BuildContext context,
    List<StudentDashboardItem> students,
    bool dashboardLoading,
  ) {
    final studentExists =
        students.any((student) => student.id == _selectedStudentId);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel('Student'),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: studentExists ? _selectedStudentId : null,
            borderRadius: BorderRadius.circular(16),
            decoration: authField('Student'),
            items: students
                .map(
                  (student) => DropdownMenuItem<String>(
                    value: student.id,
                    child: Text(student.name),
                  ),
                )
                .toList(),
            onChanged: students.isEmpty
                ? null
                : (value) {
                    setState(() {
                      _selectedStudentId = value;
                      _error = null;
                    });
                  },
            hint: dashboardLoading
                ? const Text('Loading students...')
                : students.isEmpty
                    ? const Text('No students found')
                    : const Text('Choose a student'),
          ),

          if (students.isEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'No students in this class yet. Add them from the Students tab.',
              style: TextStyle(
                fontFamily: RRFont.reader,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: RRColor.sunnyInk,
              ),
            ),
          ],

          const SizedBox(height: 22),
          const _SectionLabel('Reading level'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _levels
                .map(
                  (level) => _ChoiceChip(
                    label: level,
                    selected: _selectedLevel == level,
                    surface: RRColor.mintSurface,
                    edge: RRColor.mint,
                    ink: RRColor.mintInk,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedLevel = level;
                        _error = null;
                      });
                    },
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: 22),
          const _SectionLabel('Interest'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _interests
                .map(
                  (interest) => _ChoiceChip(
                    label: interest,
                    emoji: _interestEmoji[interest],
                    selected: _selectedInterest == interest,
                    surface: RRColor.skySurface,
                    edge: RRColor.sky,
                    ink: RRColor.skyInk,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedInterest = interest;
                        _error = null;
                      });
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton(List<StudentDashboardItem> students) {
    final disabled = _isLoading || students.isEmpty;

    return SizedBox(
      height: 62,
      child: ElevatedButton.icon(
        onPressed: disabled ? null : () => _generateStory(students),
        icon: Icon(
          _isLoading ? Icons.hourglass_top_rounded : Icons.auto_stories_rounded,
          size: 24,
        ),
        label: Text(
          _isLoading ? 'Writing…' : 'Generate story',
          style: const TextStyle(
            fontFamily: RRFont.display,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: RRColor.blossom,
          foregroundColor: Colors.white,
          disabledBackgroundColor: RRColor.lilac,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Result
  // -------------------------------------------------------------------------
  Widget _buildResultCard(Map<String, dynamic> data) {
    final title = data['title']?.toString().trim();
    final story = data['story']?.toString().trim() ?? '';
    final level = data['readingLevel']?.toString().trim() ?? _selectedLevel;
    final interest = data['interest']?.toString().trim() ?? _selectedInterest;
    final studentName = data['studentName']?.toString().trim();
    final dolchWordsUsed = (data['dolchWordsUsed'] is List)
        ? (data['dolchWordsUsed'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title?.isNotEmpty == true ? title! : 'Generated story',
                  style: const TextStyle(
                    fontFamily: RRFont.display,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: RRColor.ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy story',
                color: RRColor.inkSoft,
                icon: const Icon(Icons.copy_rounded, size: 22),
                onPressed: story.isEmpty
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: story));
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text('Story copied'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                      },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.person_rounded,
                label: studentName?.isNotEmpty == true
                    ? studentName!
                    : 'Selected student',
                surface: RRColor.mintSurface,
                edge: RRColor.mint,
                ink: RRColor.mintInk,
              ),
              _MetaChip(
                icon: Icons.stairs_rounded,
                label: level,
                surface: RRColor.skySurface,
                edge: RRColor.sky,
                ink: RRColor.skyInk,
              ),
              _MetaChip(
                icon: Icons.favorite_rounded,
                label: interest,
                surface: RRColor.blossomSurface,
                edge: RRColor.blossom,
                ink: RRColor.blossomInk,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // The story itself. Set for reading aloud to a child: generous line
          // height, wide letter spacing, and a soft page rather than white.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: RRColor.canvas,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: RRColor.lilac, width: 2),
            ),
            child: Text(
              story.isNotEmpty ? story : 'No story text was returned.',
              style: const TextStyle(
                fontFamily: RRFont.reader,
                fontSize: 19,
                height: 1.7,
                letterSpacing: 0.3,
                color: RRColor.ink,
              ),
            ),
          ),

          if (dolchWordsUsed.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionLabel('Dolch words used'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dolchWordsUsed
                  .map(
                    (word) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: RRColor.sunnyGlow,
                        borderRadius:
                            BorderRadius.circular(RRShape.radiusChip),
                        border:
                            Border.all(color: RRColor.sunny, width: 1.5),
                      ),
                      child: Text(
                        word,
                        style: const TextStyle(
                          fontFamily: RRFont.reader,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: RRColor.sunnyInk,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------
class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RRColor.card,
        borderRadius: BorderRadius.circular(RRShape.radiusCard),
        border: Border.all(color: RRColor.lilac, width: 2.5),
        boxShadow: RRShape.lift(RRColor.lilac),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: RRFont.display,
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: RRColor.ink,
      ),
    );
  }
}

/// A selectable chip. Selection is a fill plus a thicker border plus a check,
/// not colour alone.
class _ChoiceChip extends StatelessWidget {
  final String label;
  final String? emoji;
  final bool selected;
  final Color surface;
  final Color edge;
  final Color ink;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.surface,
    required this.edge,
    required this.ink,
    required this.onTap,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? surface : RRColor.card,
            borderRadius: BorderRadius.circular(RRShape.radiusChip),
            border: Border.all(
              color: selected ? ink : RRColor.lilac,
              width: selected ? 2.5 : 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 16, color: ink),
                const SizedBox(width: 6),
              ] else if (emoji != null) ...[
                Text(emoji!, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: RRFont.reader,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? ink : RRColor.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color surface;
  final Color edge;
  final Color ink;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.surface,
    required this.edge,
    required this.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(RRShape.radiusChip),
        border: Border.all(color: edge, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: ink),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: RRFont.reader,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Waiting state. Generation is allowed up to 60 seconds, and an 18px spinner
/// inside a button is not enough signal for a wait that long — it reads as a
/// hang. This says something is happening and roughly how long it takes.
class _WaitingCard extends StatelessWidget {
  const _WaitingCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: const [
          BloomMascot(size: 90, mood: BloomMood.happy, glasses: true),
          SizedBox(height: 14),
          Text(
            'Writing the story…',
            style: TextStyle(
              fontFamily: RRFont.display,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: RRColor.ink,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'This can take up to a minute.',
            textAlign: TextAlign.center,
            style: RRText.body,
          ),
          SizedBox(height: 16),
          SizedBox(
            width: 140,
            child: LinearProgressIndicator(
              minHeight: 10,
              backgroundColor: RRColor.lilacSurface,
              color: RRColor.blossom,
            ),
          ),
        ],
      ),
    );
  }
}