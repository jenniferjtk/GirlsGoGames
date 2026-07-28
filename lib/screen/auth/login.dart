import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:readright/config/theme.dart';
import 'package:readright/widgets/auth_ui.dart';
import 'package:readright/widgets/bloom_mascot.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorText;
  bool _obscurePassword = true; // Controls visibility of password

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Please fill in all fields.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final supabase = Supabase.instance.client;

      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = res.user;
      if (user == null) {
        setState(() {
          _errorText = 'Invalid email or password.';
          _isLoading = false;
        });
        return;
      }

      final roleData = await supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      final role = roleData?['role'] ?? 'student';

      if (mounted) {
        if (role == 'teacher') {
          Navigator.pushReplacementNamed(context, '/teacherDashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/studentDashboard');
        }
      }
    } catch (e) {
      setState(() => _errorText = 'Login failed: $e');
      debugPrint('Login error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                  mood: BloomMood.happy,
                  badge: Icons.menu_book_rounded,
                  badgeColor: RRColor.mint,
                  title: 'Welcome back!',
                  subtitle: 'Bloom has been reading without you.',
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: authField('Email'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: authField(
                    'Password',
                    suffixIcon: IconButton(
                      color: RRColor.inkSoft,
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 18),
                  const AuthMessage(text: 'Incorrect login information.'),
                ],
                const SizedBox(height: 26),
                AuthButton(
                  label: 'Log in',
                  loading: _isLoading,
                  onPressed: _login,
                ),
                const SizedBox(height: 10),
                AuthLink(
                  label: "Don't have an account? Sign up",
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/signup'),
                ),
                AuthLink(
                  label: 'Forgot your password? Reset here',
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/resetPassword'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}