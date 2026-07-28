import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:readright/config/theme.dart';
import 'package:readright/widgets/auth_ui.dart';
import 'package:readright/widgets/bloom_mascot.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;
  String? _successText;

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorText = 'Please enter your email address.';
        _successText = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
      _successText = null;
    });

    try {
      final supabase = Supabase.instance.client;

      await supabase.auth.resetPasswordForEmail(email);

      setState(() {
        _successText =
            'Password reset link sent! Check your email for instructions.';
        _errorText = null;
      });
    } catch (e) {
      setState(() {
        _errorText = 'Failed to send reset email: $e';
        _successText = null;
      });
      debugPrint('Password reset error: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RRColor.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AuthHeader(
                  mood: BloomMood.confused,
                  badge: Icons.key_rounded,
                  badgeColor: RRColor.sky,
                  title: 'Forgot it?',
                  subtitle: 'Bloom forgets things too. Enter your email.',
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: authField('Email'),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 18),
                  AuthMessage(text: _errorText!),
                ],
                if (_successText != null) ...[
                  const SizedBox(height: 18),
                  AuthMessage(text: _successText!, isError: false),
                ],
                const SizedBox(height: 26),
                AuthButton(
                  label: 'Send reset link',
                  loading: _isLoading,
                  onPressed: _sendResetEmail,
                  color: RRColor.sky,
                ),
                const SizedBox(height: 10),
                AuthLink(
                  label: 'Back to log in',
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}