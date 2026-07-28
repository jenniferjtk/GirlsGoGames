import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:readright/providers/theme_provider.dart';
import 'package:readright/screen/student/tap_the_word.dart';

Widget _buildTestApp() {
  return ChangeNotifierProvider<ThemeProvider>(
    create: (_) => ThemeProvider(),
    child: const MaterialApp(
      home: TapTheWordPage(testMode: true),
    ),
  );
}

void main() {
  setUp(() {
    // TapTheWordPage renders via StudentBaseScaffold, which reads
    // ThemeProvider, which reads SharedPreferences — mock it so that
    // doesn't hit a real platform channel during tests.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('TapTheWordPage shows the hear-it-again button and 3 options',
      (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('🔊'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNWidgets(4)); // 1 speaker + 3 options
  });

  testWidgets('Tapping an option advances to the feedback screen',
      (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    // Tap the first answer option (index 1, since index 0 is the
    // speaker button).
    final optionButtons = find.byType(ElevatedButton);
    await tester.tap(optionButtons.at(1));
    await tester.pumpAndSettle();

    // Whether right or wrong, the feedback screen always shows one of
    // these two continue-buttons.
    final continueButton = find.textContaining('Next Word');
    final resultsButton = find.textContaining('See Results');
    expect(
      continueButton.evaluate().isNotEmpty ||
          resultsButton.evaluate().isNotEmpty,
      isTrue,
    );
  });
}
