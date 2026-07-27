import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:readright/providers/teacherProvider.dart';
import 'package:readright/services/databaseHelper.dart';

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

        return Scaffold(
          appBar: AppBar(
            title: const Text('Teacher Story Builder'),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildIntroCard(),
                  const SizedBox(height: 16),
                  _buildSelectionCard(
                    context,
                    students,
                    provider.dashboardLoading,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed:
                    _isLoading || students.isEmpty
                        ? null
                        : () => _generateStory(students),
                    icon:
                    _isLoading
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.auto_stories),
                    label: Text(
                      _isLoading ? 'Generating...' : 'Generate Story',
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Backend: $_backendBaseUrl',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) _buildErrorCard(_error!),
                  if (_storyResponse != null) ...[
                    const SizedBox(height: 16),
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

  Widget _buildIntroCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Generate a story for one student',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Pick a student, reading level, and interest. The backend proxy will build the prompt and return an age-appropriate story.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard(
      BuildContext context,
      List<StudentDashboardItem> students,
      bool dashboardLoading,
      ) {
    final theme = Theme.of(context);
    final studentExists =
    students.any((student) => student.id == _selectedStudentId);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Story settings',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: studentExists ? _selectedStudentId : null,
              decoration: const InputDecoration(
                labelText: 'Student',
                border: OutlineInputBorder(),
              ),
              items:
              students
                  .map(
                    (student) => DropdownMenuItem<String>(
                  value: student.id,
                  child: Text(student.name),
                ),
              )
                  .toList(),
              onChanged:
              students.isEmpty
                  ? null
                  : (value) {
                setState(() {
                  _selectedStudentId = value;
                  _error = null;
                });
              },
              hint:
              dashboardLoading
                  ? const Text('Loading students...')
                  : students.isEmpty
                  ? const Text('No students found')
                  : const Text('Choose a student'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedLevel,
              decoration: const InputDecoration(
                labelText: 'Reading level',
                border: OutlineInputBorder(),
              ),
              items:
              _levels
                  .map(
                    (level) => DropdownMenuItem<String>(
                  value: level,
                  child: Text(level),
                ),
              )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedLevel = value;
                  _error = null;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedInterest,
              decoration: const InputDecoration(
                labelText: 'Interest',
                border: OutlineInputBorder(),
              ),
              items:
              _interests
                  .map(
                    (interest) => DropdownMenuItem<String>(
                  value: interest,
                  child: Text(interest),
                ),
              )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedInterest = value;
                  _error = null;
                });
              },
            ),
            const SizedBox(height: 12),
            if (students.isEmpty)
              const Text(
                'Load students in the teacher dashboard first.',
                style: TextStyle(color: Colors.orange),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Card(
      color: Colors.redAccent.shade100.withOpacity(0.15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> data) {
    final title = data['title']?.toString().trim();
    final story = data['story']?.toString().trim() ?? '';
    final level = data['readingLevel']?.toString().trim() ?? _selectedLevel;
    final interest = data['interest']?.toString().trim() ?? _selectedInterest;
    final studentName = data['studentName']?.toString().trim();
    final dolchWordsUsed = (data['dolchWordsUsed'] is List)
        ? (data['dolchWordsUsed'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title?.isNotEmpty == true ? title! : 'Generated story',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Student: ${studentName?.isNotEmpty == true ? studentName : 'Selected student'}',
            ),
            Text('Level: $level'),
            Text('Interest: $interest'),
            const SizedBox(height: 16),
            Text(
              story.isNotEmpty ? story : 'No story text was returned.',
              style: const TextStyle(fontSize: 18, height: 1.4),
            ),
            if (dolchWordsUsed.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Dolch words used',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                dolchWordsUsed
                    .map(
                      (word) => Chip(
                    label: Text(word),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}