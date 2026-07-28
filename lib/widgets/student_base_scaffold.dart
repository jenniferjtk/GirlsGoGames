import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:readright/config/theme.dart';
import 'package:readright/widgets/student_navbar.dart';

import '../providers/theme_provider.dart';

class StudentBaseScaffold extends StatelessWidget {
  final Widget body;
  final String pageTitle;
  final IconData pageIcon;
  final int currentIndex;

  const StudentBaseScaffold({
    super.key,
    required this.body,
    required this.pageTitle,
    required this.pageIcon,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: RRColor.canvas,
      appBar: AppBar(
        backgroundColor: RRColor.mint,
        elevation: 0,
        toolbarHeight: 68,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Row(
          children: [
            Icon(pageIcon, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            Text(
              pageTitle,
              style: const TextStyle(
                fontFamily: RRFont.display,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            iconSize: 26,
            icon: themeProvider.isDarkMode
                ? const Icon(Icons.light_mode, color: Colors.white)
                : const Icon(Icons.dark_mode, color: Colors.white),
            tooltip: 'Dark mode',
            onPressed: () async {
              HapticFeedback.selectionClick();
              themeProvider.toggleTheme();
            },
          ),
          IconButton(
            iconSize: 26,
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
      bottomNavigationBar: StudentNavBar(
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == currentIndex) return;
          HapticFeedback.mediumImpact();
          SystemSound.play(SystemSoundType.click);
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/studentDashboard');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/games');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/wordlist');
              break;
            default:
              Navigator.pushReplacementNamed(context, '/studentDashboard');
          }
        },
      ),
    );
  }
}