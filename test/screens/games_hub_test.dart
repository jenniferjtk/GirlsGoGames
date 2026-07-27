import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:readright/providers/theme_provider.dart';
import 'package:readright/screen/games.dart';

void main() {
  setUp(() {
    // GamesHubPage renders via StudentBaseScaffold, which reads
    // ThemeProvider, which reads SharedPreferences.
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp() {
    return ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: const MaterialApp(
        home: GamesHubPage(),
      ),
    );
  }

  testWidgets('GamesHubPage lists Practice and Sound Pop!', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Practice'), findsOneWidget);
    expect(find.text('Sound Pop!'), findsOneWidget);
  });

  testWidgets('GamesHubPage shows the picker prompt', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Pick a game to play!'), findsOneWidget);
  });
}
