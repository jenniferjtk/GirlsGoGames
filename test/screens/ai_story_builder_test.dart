import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:readright/providers/teacherProvider.dart';
import 'package:readright/screen/ai_story_builder.dart';

class FakeTeacherProvider extends ChangeNotifier implements TeacherProvider {
  FakeTeacherProvider({
    required List<StudentDashboardItem> students,
    bool dashboardLoading = false,
  })  : _students = students,
        _dashboardLoading = dashboardLoading;

  final List<StudentDashboardItem> _students;
  final bool _dashboardLoading;

  @override
  List<StudentDashboardItem> get students => _students;

  @override
  bool get dashboardLoading => _dashboardLoading;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AI Story Builder UI Tests', () {
    late FakeTeacherProvider provider;

    setUp(() {
      provider = FakeTeacherProvider(
        students: [
          StudentDashboardItem(
            id: 'student-1',
            name: 'student student',
            progress: 0.5,
            accuracy: 75,
            trendingUp: true,
          ),
        ],
        dashboardLoading: false,
      );
    });

    Widget buildTestWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<TeacherProvider>.value(
            value: provider,
          ),
        ],
        child: const MaterialApp(
          home: AIStoryBuilderPage(),
        ),
      );
    }

    testWidgets('AI Story Builder screen shows the main UI', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Teacher Story Builder'), findsOneWidget);
      expect(find.text('Generate a story for one student'), findsOneWidget);
      expect(find.text('Story settings'), findsOneWidget);
      expect(find.text('Generate Story'), findsOneWidget);
    });

    testWidgets('AI Story Builder shows an error when no student is selected',
            (tester) async {
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<TeacherProvider>.value(
                  value: FakeTeacherProvider(
                    students: [
                      StudentDashboardItem(
                        id: 'student-1',
                        name: 'student student',
                        progress: 0.5,
                        accuracy: 75,
                        trendingUp: true,
                      ),
                    ],
                    dashboardLoading: false,
                  ),
                ),
              ],
              child: const MaterialApp(
                home: AIStoryBuilderPage(),
              ),
            ),
          );

          await tester.pumpAndSettle();

          await tester.tap(find.text('Generate Story'));
          await tester.pump();

          expect(find.text('Please choose a student.'), findsOneWidget);
        });
  });
}