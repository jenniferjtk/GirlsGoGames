import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:readright/providers/theme_provider.dart';

/// Pumps [child] wrapped with the providers the app's screens expect.
///
/// StudentBaseScaffold reads ThemeProvider via Provider.of, so any screen
/// built on it throws ProviderNotFoundException unless wrapped like this.
/// Also seeds SharedPreferences' mock store since ThemeProvider reads from
/// it on construction.
Future<void> pumpWithProviders(WidgetTester tester, Widget child) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: MaterialApp(home: child),
    ),
  );
}
