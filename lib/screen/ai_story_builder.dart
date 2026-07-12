import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AIStoryBuilderPage extends StatefulWidget {
  const AIStoryBuilderPage({super.key});

  @override
  State<AIStoryBuilderPage> createState() => _AIStoryBuilderPageState();
}

class _AIStoryBuilderPageState extends State<AIStoryBuilderPage> {
  final TextEditingController _promptController = TextEditingController(
    text: 'Write a short story using cat, run, and play.',
  );

  bool _isLoading = false;
  String? _story;
  String? _error;

  static const String _webBackendBaseUrl = 'http://localhost:3000';
  static const String _androidEmulatorBackendBaseUrl = 'http://10.0.2.2:3000';

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  String get _backendBaseUrl {
    if (kIsWeb) return _webBackendBaseUrl;
    return _androidEmulatorBackendBaseUrl;
  }

  Future<void> _generateStory() async {
    final prompt = _promptController.text.trim();

    if (prompt.isEmpty) {
      setState(() {
        _error = 'Please enter a prompt.';
        _story = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _story = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$_backendBaseUrl/generate-story'),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'prompt': prompt}),
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        final decoded = _tryDecodeJson(response.body);
        setState(() {
          _error = decoded?['error']?.toString() ??
              'Request failed with status ${response.statusCode}.';
        });
        return;
      }

      final decoded = _tryDecodeJson(response.body);
      final story = decoded?['story']?.toString().trim();

      setState(() {
        _story = (story == null || story.isEmpty)
            ? 'No story text was returned.'
            : story;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach the backend: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic>? _tryDecodeJson(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Story Builder'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Test the story pipeline',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Send one prompt to your backend proxy and display the returned story.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _promptController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Story prompt',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _generateStory,
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Generate Story'),
              ),
              const SizedBox(height: 12),
              Text(
                'Backend: $_backendBaseUrl',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _error != null
                      ? SingleChildScrollView(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                      ),
                    ),
                  )
                      : _story != null
                      ? SingleChildScrollView(
                    child: Text(
                      _story!,
                      style: const TextStyle(fontSize: 18, height: 1.4),
                    ),
                  )
                      : const Center(
                    child: Text(
                      'Your story will appear here.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}