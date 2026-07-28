// lib/config/theme.dart
//
// ReadRight design tokens.
//
// The brief's palette (#81F4E1 mint, #56CBF9 sky, #FF729F blossom, #D3C4D1
// lilac) is preserved, but each hue is split into three roles so that nothing
// fails contrast:
//
//   *Surface  — the pale wash. Backgrounds only, never type.
//   *Glow     — the brief's literal hex. Large fills, rings, badges.
//   base      — a saturated version for solid buttons and icons.
//   *Ink      — a darkened version, >= 4.5:1 on white, for type on light.
//
// A six-year-old reads type set in `ink` or a `*Ink`. Everything else is
// decoration. Do not set body text in `mint`, `sky`, `blossom`, or `lilac`.

import 'package:flutter/material.dart';

class RRColor {
  RRColor._();

  // Canvas — warm white, not pure #FFFFFF. Reduces glare under classroom
  // fluorescents and on the Pixel's OLED.
  static const Color canvas = Color(0xFFFFFCF8);
  static const Color card = Color(0xFFFFFFFF);

  // Type
  static const Color ink = Color(0xFF2B2440); // 13.6:1 on canvas
  static const Color inkSoft = Color(0xFF5C5470); // 7.1:1 on canvas

  // Mint — mastery, growth, Bloom's own colour
  static const Color mintSurface = Color(0xFFD9FBF3);
  static const Color mintGlow = Color(0xFF81F4E1); // brief hex
  static const Color mint = Color(0xFF17BFA3);
  static const Color mintInk = Color(0xFF07695A); // 5.4:1 on white

  // Sky — listening, calm, the "not yet" state
  static const Color skySurface = Color(0xFFE0F4FE);
  static const Color skyGlow = Color(0xFF56CBF9); // brief hex
  static const Color sky = Color(0xFF1FA8DC);
  static const Color skyInk = Color(0xFF05627F); // 6.6:1 on white

  // Blossom — speaking, encouragement, the current step
  static const Color blossomSurface = Color(0xFFFFE4EC);
  static const Color blossomGlow = Color(0xFFFF729F); // brief hex
  static const Color blossom = Color(0xFFFF4D86);
  static const Color blossomInk = Color(0xFFB3164E); // 6.2:1 on white

  // Lilac — structure. Borders, dividers, locked states. Never type on white.
  static const Color lilacSurface = Color(0xFFF3EDF2);
  static const Color lilac = Color(0xFFD3C4D1); // brief hex
  static const Color lilacInk = Color(0xFF6B5A69); // 5.9:1 on white

  // Sunny — badges earned
  static const Color sunnyGlow = Color(0xFFFFD467);
  static const Color sunny = Color(0xFFFFC53D);
  static const Color sunnyInk = Color(0xFF8A5B00); // 5.1:1 on white
}

/// Type roles.
///
/// Both are `null` today, which resolves to the platform default so nothing
/// breaks in Chrome or on the Pixel without a pubspec change. To switch on the
/// intended pairing, add `google_fonts` and replace the two getters with
/// `GoogleFonts.baloo2().fontFamily` (display) and
/// `GoogleFonts.lexend().fontFamily` (reader) — Lexend is designed for early
/// readers and measurably improves reading proficiency in this age band.
class RRFont {
  RRFont._();

  /// Rounded, heavy, friendly. Numbers, names, headings, button words.
  static const String? display = null;

  /// High legibility, generous letter spacing. Sight words themselves.
  static const String? reader = null;
}

/// Type scale. Nothing a child must read is below 18.
class RRText {
  RRText._();

  static const TextStyle hero = TextStyle(
    fontFamily: RRFont.display,
    fontSize: 46,
    fontWeight: FontWeight.w800,
    color: RRColor.mintInk,
    height: 1.0,
  );

  static const TextStyle greeting = TextStyle(
    fontFamily: RRFont.display,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    color: RRColor.ink,
  );

  static const TextStyle section = TextStyle(
    fontFamily: RRFont.display,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: RRColor.ink,
  );

  /// Sight words. Letter-spaced so `b`/`d` and `m`/`n` stay distinct.
  static const TextStyle word = TextStyle(
    fontFamily: RRFont.reader,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: RRColor.ink,
  );

  static const TextStyle body = TextStyle(
    fontFamily: RRFont.reader,
    fontSize: 18,
    color: RRColor.inkSoft,
  );

  /// Teacher-facing only — deliberately small so it reads as "not for you".
  static const TextStyle aside = TextStyle(
    fontFamily: RRFont.reader,
    fontSize: 12,
    color: RRColor.inkSoft,
  );
}

/// Shared shape language: one radius family, one shadow.
class RRShape {
  RRShape._();

  static const double radiusCard = 28;
  static const double radiusChip = 20;

  static List<BoxShadow> lift(Color tint, {bool pressed = false}) => [
        BoxShadow(
          color: tint.withOpacity(0.30),
          blurRadius: pressed ? 4 : 14,
          offset: Offset(0, pressed ? 2 : 6),
        ),
      ];
}
