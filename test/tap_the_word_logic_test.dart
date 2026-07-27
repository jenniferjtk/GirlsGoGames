// Pure Dart unit tests — no widget pumping, no Supabase. These test the
// game logic extracted from tap_the_word.dart (dedupeWordsByText,
// roundSummaryFor), which doesn't depend on Flutter or the network.
import 'package:flutter_test/flutter_test.dart';
import 'package:readright/models/word.dart';
import 'package:readright/screen/tap_the_word.dart';

Word _w(String text) => Word(id: text, text: text, type: 'word', sentences: []);

void main() {
  group('dedupeWordsByText', () {
    test('removes case-insensitive duplicates, keeping the first seen', () {
      final input = [_w('cat'), _w('Cat'), _w('dog'), _w('CAT')];
      final result = dedupeWordsByText(input);

      expect(result.length, 2);
      expect(result[0].text, 'cat');
      expect(result[1].text, 'dog');
    });

    test('returns the list unchanged when there are no duplicates', () {
      final input = [_w('the'), _w('and'), _w('play')];
      final result = dedupeWordsByText(input);

      expect(result.length, 3);
      expect(result.map((w) => w.text), ['the', 'and', 'play']);
    });

    test('returns an empty list when given an empty list', () {
      expect(dedupeWordsByText([]), isEmpty);
    });
  });

  group('roundSummaryFor', () {
    test('perfect score returns "Perfect Round!" and a trophy', () {
      final result = roundSummaryFor(score: 3, total: 3);
      expect(result.title, 'Perfect Round!');
      expect(result.emoji, '🏆');
    });

    test('score at or above half returns "Great Job!"', () {
      final result = roundSummaryFor(score: 2, total: 3);
      expect(result.title, 'Great Job!');
      expect(result.emoji, '🌟');
    });

    test('score below half but above zero returns "Nice Try!"', () {
      final result = roundSummaryFor(score: 1, total: 3);
      expect(result.title, 'Nice Try!');
      expect(result.emoji, '💪');
    });

    test('zero score returns "Keep Practicing!"', () {
      final result = roundSummaryFor(score: 0, total: 3);
      expect(result.title, 'Keep Practicing!');
      expect(result.emoji, '😊');
    });
  });
}
