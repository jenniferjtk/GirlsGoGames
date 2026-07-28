import 'package:flutter_test/flutter_test.dart';
import 'package:readright/models/assessment_result.dart';
import 'package:readright/screen/student/feedback.dart';

import '../helpers/pump_app.dart';

AssessmentResult _resultWith({
  double pronScore = 90,
  double accuracy = 92,
  double fluency = 88,
  double completeness = 100,
}) {
  return AssessmentResult(
    accuracy: accuracy,
    completeness: completeness,
    fluency: fluency,
    prosody: 75,
    pronScore: pronScore,
    words: const [],
  );
}

void main() {
  testWidgets('FeedbackPage displays the real practiced word, not "cat"', (
    tester,
  ) async {
    await pumpWithProviders(
      tester,
      FeedbackPage(word: 'elephant', result: _resultWith()),
    );
    await tester.pumpAndSettle();

    expect(find.text('elephant'), findsOneWidget);
    expect(find.text('cat'), findsNothing);
  });

  testWidgets('FeedbackPage displays the real pronScore, not the old 88 placeholder', (
    tester,
  ) async {
    await pumpWithProviders(
      tester,
      FeedbackPage(word: 'dog', result: _resultWith(pronScore: 63)),
    );
    await tester.pumpAndSettle();

    expect(find.text('63'), findsOneWidget);
    expect(find.text('88'), findsNothing);
  });

  testWidgets('FeedbackPage shows an accuracy breakdown instead of phoneme chips', (
    tester,
  ) async {
    await pumpWithProviders(
      tester,
      FeedbackPage(
        word: 'dog',
        result: _resultWith(accuracy: 77, fluency: 81, completeness: 95),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Accuracy Breakdown'), findsOneWidget);
    expect(find.text('77%'), findsOneWidget);
    expect(find.text('81%'), findsOneWidget);
    expect(find.text('95%'), findsOneWidget);

    // The old placeholder phonemes should never appear.
    expect(find.text('/k/'), findsNothing);
    expect(find.text('/æ/'), findsNothing);
    expect(find.text('/t/'), findsNothing);
  });

  testWidgets('FeedbackPage shows an encouraging message tied to a low score', (
    tester,
  ) async {
    await pumpWithProviders(
      tester,
      FeedbackPage(word: 'dog', result: _resultWith(pronScore: 20)),
    );
    await tester.pumpAndSettle();

    expect(find.text("You're doing great — try again!"), findsOneWidget);
    expect(find.text('Excellent pronunciation!'), findsNothing);
  });
}
