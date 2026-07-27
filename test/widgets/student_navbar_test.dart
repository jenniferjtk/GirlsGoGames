import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:readright/widgets/student_navbar.dart';

void main() {
  testWidgets('StudentNavBar shows a Games tab (renamed from Practice)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: StudentNavBar(
            currentIndex: 1,
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Games'), findsOneWidget);
    expect(find.text('Practice'), findsNothing);
    expect(find.byIcon(Icons.sports_esports), findsOneWidget);
  });

  testWidgets('StudentNavBar still shows Dashboard, Words, and Progress',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: StudentNavBar(
            currentIndex: 0,
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Words'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
  });
}
