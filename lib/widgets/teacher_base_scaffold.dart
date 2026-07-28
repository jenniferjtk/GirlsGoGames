// lib/widgets/teacher_base_scaffold.dart
//
// Changes:
//   * Routes the four new tabs: Class / Students / Words / Stories.
//   * Dark mode toggle removed. ThemeProvider stays registered and unused.
//   * App bar takes the theme tokens, matching the student scaffold.
//   * Haptics on tab change, and a same-tab tap is a no-op rather than a
//     pointless pushReplacement.
//
// Logout behaviour is untouched.
//
// !! ROUTE NAMES — confirm these against main.dart. Only /teacherDashboard and
// /aiStoryBuilder appear in code I've seen; the other two are my guesses and
// are pulled out as constants so they're a one-line fix.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:readright/config/theme.dart';
import 'package:readright/widgets/teacher_navbar.dart';

/// Tab index -> named route. Index order must match TeacherNavBar._items.
const List<String> kTeacherTabRoutes = [
  '/teacherDashboard', // 0 Class    — confirmed
  '/teacherStudents', // 1 Students — CHECK
  '/teacherWordLists', // 2 Words    — CHECK
  '/aiStoryBuilder', // 3 Stories  — confirmed
];

class TeacherBaseScaffold extends StatelessWidget {
  final Widget body;
  final String pageTitle;
  final IconData pageIcon;
  final int currentIndex;

  /// Optional trailing app bar actions for a specific page — e.g. a search
  /// toggle on Students. Logout is always appended after these.
  final List<Widget> actions;

  const TeacherBaseScaffold({
    super.key,
    required this.body,
    required this.pageTitle,
    required this.pageIcon,
    required this.currentIndex,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RRColor.canvas,
      appBar: AppBar(
        backgroundColor: RRColor.mint,
        elevation: 0,
        toolbarHeight: 64,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Row(
          children: [
            Icon(pageIcon, color: Colors.white, size: 26),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                pageTitle,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: RRFont.display,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          ...actions,
          IconButton(
            iconSize: 24,
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () async {
              final supabase = Supabase.instance.client;

              // Sign out the user
              await supabase.auth.signOut();

              // Navigate to login page & clear stack
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: body,
      bottomNavigationBar: TeacherNavBar(
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == currentIndex) return;
          HapticFeedback.selectionClick();

          final route = index >= 0 && index < kTeacherTabRoutes.length
              ? kTeacherTabRoutes[index]
              : kTeacherTabRoutes.first;

          Navigator.pushReplacementNamed(context, route);
        },
      ),
    );
  }
}