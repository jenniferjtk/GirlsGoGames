// lib/widgets/auth_ui.dart
//
// Shared pieces for the three auth screens (login, signup, reset).
//
// These screens are used by adults and by students being set up, not by a
// six-year-old navigating alone, so the type stays at normal sizes — the
// oversized targets belong on the play screens. What carries across is the
// palette, the rounded-and-outlined shape language, and Bloom.

import 'package:flutter/material.dart';

import 'package:readright/config/theme.dart';
import 'package:readright/widgets/bloom_mascot.dart';

/// Bloom plus a small badge showing what it's up to on this screen.
class AuthHeader extends StatelessWidget {
  final BloomMood mood;
  final IconData badge;
  final Color badgeColor;
  final String title;
  final String subtitle;

  const AuthHeader({
    super.key,
    required this.mood,
    required this.badge,
    required this.badgeColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 116,
          width: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              BloomMascot(size: 104, mood: mood),
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: RRShape.lift(badgeColor),
                  ),
                  child: Icon(badge, size: 22, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: RRFont.display,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: RRColor.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: RRText.body,
        ),
      ],
    );
  }
}

/// One decoration for every field on every auth screen.
InputDecoration authField(String label, {Widget? suffixIcon}) {
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    labelText: label,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: RRColor.card,
    labelStyle: const TextStyle(
      fontFamily: RRFont.reader,
      fontSize: 16,
      color: RRColor.inkSoft,
    ),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    enabledBorder: border(RRColor.lilac, 2),
    border: border(RRColor.lilac, 2),
    focusedBorder: border(RRColor.mint, 2.5),
    errorBorder: border(RRColor.blossomInk, 2),
    focusedErrorBorder: border(RRColor.blossomInk, 2.5),
    errorStyle: const TextStyle(
      fontFamily: RRFont.reader,
      fontSize: 13,
      color: RRColor.blossomInk,
    ),
  );
}

/// Primary action button.
class AuthButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final Color color;

  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.color = RRColor.mint,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: RRColor.lilac,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontFamily: RRFont.display,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

/// Secondary navigation link.
class AuthLink extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const AuthLink({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: RRColor.skyInk,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: RRFont.reader,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Error or success banner. An icon carries the state alongside the colour, so
/// it doesn't rely on red-vs-green alone.
class AuthMessage extends StatelessWidget {
  final String text;
  final bool isError;

  const AuthMessage({super.key, required this.text, this.isError = true});

  @override
  Widget build(BuildContext context) {
    final surface = isError ? RRColor.blossomSurface : RRColor.mintSurface;
    final edge = isError ? RRColor.blossom : RRColor.mint;
    final ink = isError ? RRColor.blossomInk : RRColor.mintInk;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: edge, width: 2),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
            size: 22,
            color: ink,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: RRFont.reader,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
