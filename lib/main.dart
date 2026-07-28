import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:readright/providers/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:readright/config/config.dart';
import 'package:readright/services/databaseHelper.dart';

// Providers
import 'package:readright/providers/studentDashboardProvider.dart';
import 'package:readright/providers/teacherProvider.dart';

// Screens
import 'package:readright/screen/auth/login.dart';
import 'package:readright/screen/auth/signup.dart';
import 'package:readright/screen/auth/resetPassword.dart';
import 'package:readright/screen/student/studentDashboard.dart';
import 'package:readright/screen/student/practice.dart';
import 'package:readright/screen/student/wordList.dart';
import 'package:readright/screen/student/feedback.dart';
import 'package:readright/models/assessment_result.dart';
import 'package:readright/screen/teacher/teacherDashboard.dart';
import 'package:readright/screen/teacher/teacherWordLists.dart';
import 'package:readright/screen/teacher/teacherStudents.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:readright/screen/ai_story_builder.dart';
import 'package:readright/screen/student/tap_the_word.dart';
import 'package:readright/screen/student/games.dart';

// REMOVED:
//   progress.dart      — merged into StudentDashboard (the Home tab).
//   teacherSettings.dart — its only content was the per-student save_audio
//                          toggle, which now lives on the Students tab.

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();

  final supabaseUrl = AppConfig.supabaseUrl;
  final supabaseAnonKey = AppConfig.supabaseAnonKey;

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(
    MultiProvider(
      // TeacherProvider is already app-wide here, which is what the teacher
      // tabs now rely on. It stays lazy (the default), so it isn't constructed
      // until a teacher screen first reads it — important, because it loads in
      // its constructor and would otherwise query with no session.
      providers: [
        ChangeNotifierProvider(create: (_) => StudentDashboardProvider()),
        ChangeNotifierProvider(create: (_) => TeacherProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider())
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _initialized = false;
  bool _checkingRole = false;
  Widget? _homePage;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      if (!kIsWeb) {
        final db = DatabaseHelper.instance;
        final imported = await db.isDolchImported();

        if (!imported) {
          await db.importAllDolchLists();
          await db.setDolchImported();
          debugPrint("Dolch CSV imported (first run)");
        } else {
          debugPrint("Dolch import skipped (already imported)");
        }
      }
    } catch (e) {
      debugPrint("Dolch import error: $e");
    }

    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    if (session == null) {
      _homePage = const LoginPage();
    } else {
      _checkingRole = true;
      try {
        final userId = session.user.id;
        final result = await supabase
            .from('users')
            .select('role')
            .eq('id', userId)
            .maybeSingle();

        final role = result?['role'] ?? 'student';
        _homePage = (role == 'teacher')
            ? const TeacherDashboard()
            : const StudentDashboard();
      } catch (e) {
        debugPrint("Role lookup failed: $e");
        _homePage = const LoginPage();
      }
    }

    if (mounted) {
      setState(() {
        _initialized = true;
        _checkingRole = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (!_initialized || _checkingRole) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: themeProvider.isDarkMode
            ? ColorScheme.dark(
                primary: Color(AppConfig.primaryColor),
                secondary: Color(AppConfig.secondaryColor),
              )
            : ColorScheme.light(
                primary: Color(AppConfig.primaryColor),
                secondary: Color(AppConfig.secondaryColor),
              ),
        useMaterial3: false,
      ),
      home: _homePage,
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/resetPassword': (context) => const ResetPasswordPage(),
        '/studentDashboard': (context) => const StudentDashboard(),
        '/practice': (context) => const PracticePage(),
        '/wordlist': (context) => const WordListPage(),
        '/feedback': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return FeedbackPage(
            word: args['word'] as String,
            result: args['result'] as AssessmentResult,
          );
        },
        '/teacherDashboard': (context) => const TeacherDashboard(),
        '/teacherWordLists': (context) => const TeacherWordListsPage(),
        '/teacherStudents': (context) => const TeacherStudentsPage(),
        '/aiStoryBuilder': (context) => const AIStoryBuilderPage(),
        '/tapTheWord': (context) => const TapTheWordPage(),
        '/games': (context) => const GamesHubPage(),
      },
    );
  }
}