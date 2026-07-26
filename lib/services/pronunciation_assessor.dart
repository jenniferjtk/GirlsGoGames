import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/assessment_result.dart';

/// Thrown when a [PronunciationAssessor] fails to produce a result
/// (e.g. all retries against the provider's API were exhausted).
class PronunciationAssessmentException implements Exception {
  final String message;
  PronunciationAssessmentException(this.message);

  @override
  String toString() => message;
}

/// Swappable interface for scoring a recorded attempt at a word.
///
/// Azure is the primary implementation today; Speechace (or an
/// offline provider like Whisper/Vosk) can be swapped in later
/// behind this same interface without touching the practice screen.
abstract class PronunciationAssessor {
  Future<AssessmentResult> assess({
    required File audioFile,
    required String referenceText,
    void Function(int attempt)? onRetry,
  });
}

class AzurePronunciationAssessor implements PronunciationAssessor {
  static const _maxAttempts = 3;
  static const _endpoint =
      "https://eastus2.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=en-US";

  @override
  Future<AssessmentResult> assess({
    required File audioFile,
    required String referenceText,
    void Function(int attempt)? onRetry,
  }) async {
    final key = dotenv.env['AZURE_KEY'] as String;

    final configJson = {
      "referenceText": referenceText,
      "gradingSystem": "HundredMark",
      "dimension": "Comprehensive",
    };
    final configBase64 = base64.encode(utf8.encode(json.encode(configJson)));

    final audioBytes = await audioFile.readAsBytes();
    final url = Uri.parse(_endpoint);

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      final response = await http.post(
        url,
        headers: {
          "Ocp-Apim-Subscription-Key": key,
          "Content-Type": "audio/wav",
          "Pronunciation-Assessment": configBase64,
        },
        body: audioBytes,
      );

      if (response.statusCode == 200) {
        return AssessmentResult.fromJson(jsonDecode(response.body));
      }

      if (attempt == _maxAttempts) {
        throw PronunciationAssessmentException(
          "Azure pronunciation assessment failed after $_maxAttempts attempts "
          "(status ${response.statusCode}).",
        );
      }

      onRetry?.call(attempt);
    }

    throw PronunciationAssessmentException("Unexpected assessment failure.");
  }
}
