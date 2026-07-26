import 'package:flutter_test/flutter_test.dart';
import 'package:readright/models/assessment_result.dart';

void main() {
  group('AssessmentResult.fromJson', () {
    test('parses a full Azure pronunciation assessment response', () {
      final json = {
        "NBest": [
          {
            "AccuracyScore": 92.0,
            "CompletenessScore": 100.0,
            "FluencyScore": 88.0,
            "ProsodyScore": 75.0,
            "PronScore": 90.0,
            "Words": [
              {
                "Word": "cat",
                "PronunciationAssessment": {"AccuracyScore": 92.0},
              },
            ],
          },
        ],
      };

      final result = AssessmentResult.fromJson(json);

      expect(result.accuracy, 92.0);
      expect(result.completeness, 100.0);
      expect(result.fluency, 88.0);
      expect(result.prosody, 75.0);
      expect(result.pronScore, 90.0);
      expect(result.words, hasLength(1));
      expect(result.words.first.word, 'cat');
      expect(result.words.first.accuracy, 92.0);
    });

    test('throws when NBest is missing', () {
      expect(
        () => AssessmentResult.fromJson({}),
        throwsA(isA<Exception>()),
      );
    });

    test('throws when NBest is an empty list', () {
      expect(
        () => AssessmentResult.fromJson({"NBest": []}),
        throwsA(isA<Exception>()),
      );
    });

    test('defaults missing score fields to 0', () {
      final result = AssessmentResult.fromJson({
        "NBest": [<String, dynamic>{}],
      });

      expect(result.accuracy, 0.0);
      expect(result.completeness, 0.0);
      expect(result.fluency, 0.0);
      expect(result.prosody, 0.0);
      expect(result.pronScore, 0.0);
      expect(result.words, isEmpty);
    });

    test('defaults a word missing PronunciationAssessment to 0 accuracy', () {
      final result = AssessmentResult.fromJson({
        "NBest": [
          {
            "PronScore": 50.0,
            "Words": [
              {"Word": "dog"},
            ],
          },
        ],
      });

      expect(result.words.single.word, 'dog');
      expect(result.words.single.accuracy, 0.0);
    });
  });
}
