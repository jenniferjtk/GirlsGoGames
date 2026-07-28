// lib/widgets/teacher_student_forms.dart
//
// Lifted out of teacherDashboard.dart so they survive the dashboard becoming
// read-only. Both are opened as bottom sheets; the Students tab will own them.
//
// All provider calls, CSV parsing, and validation are unchanged — this is a
// move plus a restyle, not a rewrite. The classes are public now (they were
// private to the dashboard file) so the Students tab can import them.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:readright/config/theme.dart';
import 'package:readright/providers/teacherProvider.dart';
import 'package:readright/widgets/auth_ui.dart';

/// Sheet handle + title, shared by both forms.
class _SheetHeader extends StatelessWidget {
  final String title;

  const _SheetHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 5,
          decoration: BoxDecoration(
            color: RRColor.lilac,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            fontFamily: RRFont.display,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: RRColor.ink,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class AddStudentForm extends StatefulWidget {
  final TeacherProvider provider;

  const AddStudentForm({super.key, required this.provider});

  @override
  State<AddStudentForm> createState() => _AddStudentFormState();
}

class _AddStudentFormState extends State<AddStudentForm> {
  final _formKey = GlobalKey<FormState>();

  final first = TextEditingController();
  final last = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();

  bool loading = false;
  String? error;

  @override
  void dispose() {
    first.dispose();
    last.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
      error = null;
    });

    final r = await widget.provider.addStudent(
      firstName: first.text.trim(),
      lastName: last.text.trim(),
      email: email.text.trim(),
      password: password.text.trim(),
    );

    if (!mounted) return;

    if (r != null) {
      setState(() {
        loading = false;
        error = r;
      });
      return;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHeader(title: 'Add new student'),
            TextFormField(
              controller: first,
              decoration: authField('First name'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: last,
              decoration: authField('Last name'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: authField('Email'),
              validator: (v) => v!.contains('@') ? null : 'Invalid email',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: password,
              obscureText: true,
              decoration: authField('Password'),
              validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
            ),
            if (error != null) ...[
              const SizedBox(height: 18),
              AuthMessage(text: error!),
            ],
            const SizedBox(height: 22),
            AuthButton(
              label: 'Create student',
              loading: loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class BulkUploadStudentForm extends StatefulWidget {
  final TeacherProvider provider;

  const BulkUploadStudentForm({super.key, required this.provider});

  @override
  State<BulkUploadStudentForm> createState() => _BulkUploadStudentFormState();
}

class _BulkUploadStudentFormState extends State<BulkUploadStudentForm> {
  bool loading = false;
  String? result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetHeader(title: 'Bulk upload students'),

          // The expected shape of the file, stated before the picker rather
          // than discovered through a failed import.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: RRColor.skySurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: RRColor.skyGlow, width: 2),
            ),
            child: const Text(
              'CSV columns, in order: first name, last name, email, password. '
              'The first row is treated as a header and skipped. Password is '
              'optional and defaults to readright123.',
              style: TextStyle(
                fontFamily: RRFont.reader,
                fontSize: 14,
                height: 1.4,
                color: RRColor.skyInk,
              ),
            ),
          ),
          const SizedBox(height: 20),
          AuthButton(
            label: 'Choose CSV file',
            loading: loading,
            onPressed: importCSV,
            color: RRColor.sky,
          ),
          if (result != null) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: RRColor.canvas,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: RRColor.lilac, width: 2),
              ),
              child: Text(
                result!,
                style: const TextStyle(
                  fontFamily: RRFont.reader,
                  fontSize: 13,
                  height: 1.5,
                  color: RRColor.ink,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> importCSV() async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (pick == null) return;

    final file = File(pick.files.single.path!);
    final text = await file.readAsString();

    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final rows = lines.skip(1).map((line) {
      final cols = line.split(',');
      return {
        "first_name": cols[0],
        "last_name": cols[1],
        "email": cols[2],
        "password": cols.length > 3 ? cols[3] : "readright123",
      };
    }).toList();

    setState(() => loading = true);

    final report = await widget.provider.bulkAddStudents(rows);

    final added = report["added"] as List;
    final failed = report["failed"] as List;

    final buffer = StringBuffer();
    buffer.writeln("Upload Finished:");
    buffer.writeln("✓ ${added.length} succeeded");
    buffer.writeln("✗ ${failed.length} failed\n");

    if (added.isNotEmpty) {
      buffer.writeln("--- Successful ---");
      for (var s in added) {
        buffer.writeln("${s['first_name']} ${s['last_name']} (${s['email']})");
      }
      buffer.writeln("");
    }

    if (failed.isNotEmpty) {
      buffer.writeln("--- Failed ---");
      for (var f in failed) {
        buffer.writeln("${f['row']} → ${f['reason']}");
      }
    }

    if (!mounted) return;
    setState(() {
      loading = false;
      result = buffer.toString();
    });
  }
}
