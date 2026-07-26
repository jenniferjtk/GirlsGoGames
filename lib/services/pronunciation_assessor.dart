import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
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

/// Calls Azure's pronunciation assessment API through our backend proxy,
/// so the Azure key never has to live inside the Flutter app.
class AzurePronunciationAssessor implements PronunciationAssessor {
  static const _maxAttempts = 3;

  static const _localhostBackendBaseUrl = 'http://localhost:3000';
  static const _androidEmulatorBackendBaseUrl = 'http://10.0.2.2:3000';

  /// Resolves where the backend proxy is running.
  ///
  /// - Web and iOS Simulator share the host Mac's network, so `localhost`
  ///   reaches a backend running on the same machine.
  /// - The Android emulator is a separate VM; `10.0.2.2` is its alias for
  ///   the host machine's localhost.
  /// - A real physical device (iOS or Android) is a separate machine on
  ///   the network and can't reach `localhost` at all. Set
  ///   `BACKEND_BASE_URL=http://<your-mac-lan-ip>:3000` in .env to point
  ///   it at your Mac when demoing on a real device.
  String get _backendBaseUrl {
    final override = dotenv.env['BACKEND_BASE_URL'];
    if (override != null && override.isNotEmpty) return override;

    if (!kIsWeb && Platform.isAndroid) return _androidEmulatorBackendBaseUrl;
    return _localhostBackendBaseUrl;
  }

  @override
  Future<AssessmentResult> assess({
    required File audioFile,
    required String referenceText,
    void Function(int attempt)? onRetry,
  }) async {
    final audioBytes = await audioFile.readAsBytes();
    final url = Uri.parse(
      '$_backendBaseUrl/assess-pronunciation'
      '?referenceText=${Uri.encodeQueryComponent(referenceText)}',
    );

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      final response = await http.post(
        url,
        headers: {"Content-Type": "audio/wav"},
        body: audioBytes,
      );

      if (response.statusCode == 200) {
        return AssessmentResult.fromJson(jsonDecode(response.body));
      }

      if (attempt == _maxAttempts) {
        throw PronunciationAssessmentException(
          "Pronunciation assessment failed after $_maxAttempts attempts "
          "(status ${response.statusCode}).",
        );
      }

      onRetry?.call(attempt);
    }

    throw PronunciationAssessmentException("Unexpected assessment failure.");
  }
}
