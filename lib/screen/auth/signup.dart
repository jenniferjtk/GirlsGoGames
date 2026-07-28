import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:readright/config/theme.dart';
import 'package:readright/services/databaseHelper.dart';
import 'package:readright/widgets/auth_ui.dart';
import 'package:readright/widgets/bloom_mascot.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _selectedRole = 'student';
  bool _isLoading = false;
  String? _message;

  // Classes
  List<Map<String, dynamic>> _classes = [];
  String? _selectedClassId;
  bool _loadingClasses = true;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final supabase = Supabase.instance.client;

      final res = await supabase
          .from('classes')
          .select('id, name')
          .order('name');

      setState(() {
        _classes = List<Map<String, dynamic>>.from(res);
        _loadingClasses = false;
      });
    } catch (e) {
      setState(() {
        _loadingClasses = false;
      });
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _message = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    try {
      final supabase = Supabase.instance.client;

      final res = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'role': _selectedRole,
          'class_id': _selectedRole == 'student' ? _selectedClassId : null,
        },
      );

      final user = res.user ?? supabase.auth.currentUser;
      if (user == null) {
        setState(() => _message = 'Signup failed: could not retrieve user.');
        return;
      }

      await DatabaseHelper.instance.insertUser({
        'id': user.id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'role': _selectedRole,
        'locale': 'en-US',
        'class_id': _selectedRole == 'student' ? _selectedClassId : null,
      });

      setState(() => _message = 'Account created successfully.');
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      setState(() => _message = 'Error: ${e.toString()}');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RRColor.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const AuthHeader(
                    mood: BloomMood.cheer,
                    badge: Icons.star_rounded,
                    badgeColor: RRColor.sunny,
                    title: 'Join ReadRight',
                    subtitle: 'Bloom cannot wait to meet you.',
                  ),
                  const SizedBox(height: 30),

                  // First Name
                  TextFormField(
                    controller: _firstNameController,
                    decoration: authField('First name'),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Last Name
                  TextFormField(
                    controller: _lastNameController,
                    decoration: authField('Last name'),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: authField('Email'),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Required';
                      if (!val.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: authField('Password'),
                    validator: (val) => val == null || val.length < 6
                        ? 'Min 6 characters'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Role dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRole,
                    borderRadius: BorderRadius.circular(16),
                    items: const [
                      DropdownMenuItem(
                          value: 'student', child: Text('Student')),
                      DropdownMenuItem(
                          value: 'teacher', child: Text('Teacher')),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedRole = val ?? 'student');
                    },
                    decoration: authField('Role'),
                  ),

                  const SizedBox(height: 16),

                  // Class dropdown — ONLY for students
                  if (_selectedRole == 'student')
                    _loadingClasses
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: CircularProgressIndicator(
                              color: RRColor.mint,
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            initialValue: _selectedClassId,
                            borderRadius: BorderRadius.circular(16),
                            items: _classes
                                .map<DropdownMenuItem<String>>(
                                  (c) => DropdownMenuItem<String>(
                                    value: c['id'] as String,
                                    child: Text(c['name'] as String),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() => _selectedClassId = val);
                            },
                            decoration: authField('Select class'),
                            validator: (val) =>
                                val == null ? 'Please select a class' : null,
                          ),

                  if (_message != null) ...[
                    const SizedBox(height: 20),
                    AuthMessage(
                      text: _message!,
                      isError: _message!.startsWith('Error') ||
                          _message!.startsWith('Signup failed'),
                    ),
                  ],

                  const SizedBox(height: 26),

                  AuthButton(
                    label: 'Create account',
                    loading: _isLoading,
                    onPressed: _signUp,
                  ),

                  const SizedBox(height: 10),

                  AuthLink(
                    label: 'Already have an account? Log in',
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}