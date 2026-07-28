// lib/widgets/bloom_mascot.dart
//
// Bloom — a sprout that hatched. Round mint body, one leaf, no limbs.
//
// Drawn entirely in CustomPaint: no asset, no pubspec entry, pixel-identical
// in Chrome and on the Pixel 6, and it scales to any size without a 3x export.
//
// Bloom's job is to carry state that a pre-reader cannot get from text. Mood is
// the only prop that matters: it is how the screen says "you're doing well"
// without writing "you're doing well".

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:readright/config/theme.dart';

enum BloomMood {
  /// Nothing learned yet, or waiting. Neutral, eyes open.
  idle,

  /// Some progress. Curved eyes, small smile.
  happy,

  /// List complete. Open mouth, sparkles, leaf lifted.
  cheer,

  /// Wrong answer. Asymmetric eyes, wavy mouth, leaf tipped over. Puzzled, not
  /// sad — Bloom is confused about the word, never disappointed in the child.
  confused,

  /// Loading. Closed eyes.
  sleepy,
}

class BloomMascot extends StatelessWidget {
  final double size;
  final BloomMood mood;

  /// Reading glasses. Used on the teacher side of the app: same mascot, one
  /// costume change, so a teacher sees the character their students see while
  /// still knowing whose screen they're on.
  final bool glasses;

  const BloomMascot({
    super.key,
    required this.size,
    this.mood = BloomMood.idle,
    this.glasses = false,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _BloomPainter(mood, glasses)),
      ),
    );
  }
}

class _BloomPainter extends CustomPainter {
  final BloomMood mood;
  final bool glasses;

  _BloomPainter(this.mood, this.glasses);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h * 0.56;
    final r = w * 0.34;

    // Ground shadow — anchors Bloom so it doesn't float.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + r * 1.02), width: r * 1.5, height: r * 0.26),
      Paint()..color = RRColor.lilac.withOpacity(0.45),
    );

    // Stem + leaf. Lifts on cheer, tips over on confused.
    final lift = mood == BloomMood.cheer ? -r * 0.12 : 0.0;
    final tilt = mood == BloomMood.confused ? r * 0.34 : 0.0;
    final stemTop = Offset(cx + r * 0.06 + tilt, cy - r * 1.02 + lift + tilt * 0.4);
    canvas.drawLine(
      Offset(cx, cy - r * 0.85),
      stemTop,
      Paint()
        ..color = RRColor.mintInk
        ..strokeWidth = r * 0.11
        ..strokeCap = StrokeCap.round,
    );

    final leaf = Path()
      ..moveTo(stemTop.dx, stemTop.dy)
      ..quadraticBezierTo(
          stemTop.dx + r * 0.52, stemTop.dy - r * 0.34, stemTop.dx + r * 0.60, stemTop.dy + r * 0.12)
      ..quadraticBezierTo(
          stemTop.dx + r * 0.30, stemTop.dy + r * 0.26, stemTop.dx, stemTop.dy);
    canvas.drawPath(leaf, Paint()..color = RRColor.mint);

    // Body
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = RRColor.mintGlow);
    // Belly highlight, offset low-left so the form reads as round.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, cy + r * 0.22), width: r * 1.32, height: r * 1.10),
      Paint()..color = Colors.white.withOpacity(0.55),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09
        ..color = RRColor.mintInk,
    );

    // Face
    final eyeY = cy - r * 0.12;
    final eyeDx = r * 0.36;
    final eyeR = r * 0.115;
    final facePaint = Paint()
      ..color = RRColor.ink
      ..strokeWidth = r * 0.10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    switch (mood) {
      case BloomMood.sleepy:
        for (final dx in [-eyeDx, eyeDx]) {
          canvas.drawArc(
            Rect.fromCenter(
                center: Offset(cx + dx, eyeY), width: eyeR * 2.6, height: eyeR * 2.0),
            0,
            math.pi,
            false,
            facePaint,
          );
        }
        break;
      case BloomMood.happy:
      case BloomMood.cheer:
        for (final dx in [-eyeDx, eyeDx]) {
          canvas.drawArc(
            Rect.fromCenter(
                center: Offset(cx + dx, eyeY + eyeR * 0.5),
                width: eyeR * 2.6,
                height: eyeR * 2.2),
            math.pi,
            math.pi,
            false,
            facePaint,
          );
        }
        break;
      case BloomMood.confused:
        // One wide eye, one squint. Asymmetry is what reads as 'puzzled' —
        // two identical sad eyes would read as 'told off'.
        canvas.drawCircle(
            Offset(cx - eyeDx, eyeY), eyeR * 1.15, Paint()..color = RRColor.ink);
        canvas.drawCircle(
            Offset(cx - eyeDx + eyeR * 0.3, eyeY - eyeR * 0.4),
            eyeR * 0.34,
            Paint()..color = Colors.white);
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(cx + eyeDx, eyeY + eyeR * 0.3),
              width: eyeR * 2.4,
              height: eyeR * 1.8),
          math.pi,
          math.pi,
          false,
          facePaint,
        );
        break;
      case BloomMood.idle:
        for (final dx in [-eyeDx, eyeDx]) {
          canvas.drawCircle(
              Offset(cx + dx, eyeY), eyeR, Paint()..color = RRColor.ink);
          canvas.drawCircle(Offset(cx + dx + eyeR * 0.3, eyeY - eyeR * 0.35),
              eyeR * 0.32, Paint()..color = Colors.white);
        }
        break;
    }

    // Reading glasses, drawn over the eyes so the expression still reads
    // through the lenses.
    if (glasses) {
      final lensR = eyeR * 2.05;
      final lensPaint = Paint()..color = Colors.white.withOpacity(0.28);
      final framePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.075
        ..strokeCap = StrokeCap.round
        ..color = RRColor.ink;

      for (final dx in [-eyeDx, eyeDx]) {
        final lens = RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx + dx, eyeY),
              width: lensR * 2,
              height: lensR * 1.65),
          Radius.circular(lensR * 0.7),
        );
        canvas.drawRRect(lens, lensPaint);
        canvas.drawRRect(lens, framePaint);
      }

      // Bridge
      canvas.drawLine(
        Offset(cx - eyeDx + lensR, eyeY),
        Offset(cx + eyeDx - lensR, eyeY),
        framePaint,
      );
      // Temple arms
      canvas.drawLine(
        Offset(cx - eyeDx - lensR, eyeY),
        Offset(cx - eyeDx - lensR - r * 0.22, eyeY - r * 0.09),
        framePaint,
      );
      canvas.drawLine(
        Offset(cx + eyeDx + lensR, eyeY),
        Offset(cx + eyeDx + lensR + r * 0.22, eyeY - r * 0.09),
        framePaint,
      );
    }

    // Cheeks
    if (mood != BloomMood.sleepy) {
      for (final dx in [-r * 0.60, r * 0.60]) {
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx + dx, eyeY + r * 0.30),
              width: r * 0.32,
              height: r * 0.22),
          Paint()..color = RRColor.blossomGlow.withOpacity(0.75),
        );
      }
    }

    // Mouth
    final mouthY = cy + r * 0.30;
    if (mood == BloomMood.confused) {
      // A wavy mouth: not a frown. Bloom is working the word out too.
      final w2 = r * 0.46;
      final path = Path()..moveTo(cx - w2 / 2, mouthY);
      path.quadraticBezierTo(cx - w2 * 0.25, mouthY - r * 0.14, cx, mouthY);
      path.quadraticBezierTo(
          cx + w2 * 0.25, mouthY + r * 0.14, cx + w2 / 2, mouthY - r * 0.02);
      canvas.drawPath(path, facePaint);
    } else if (mood == BloomMood.cheer) {
      final mouth = Rect.fromCenter(
          center: Offset(cx, mouthY), width: r * 0.44, height: r * 0.50);
      canvas.drawArc(mouth, 0, math.pi, true, Paint()..color = RRColor.blossomInk);
    } else if (mood == BloomMood.sleepy) {
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(cx, mouthY), width: r * 0.28, height: r * 0.24),
        0,
        math.pi,
        false,
        facePaint,
      );
    } else {
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(cx, mouthY - r * 0.06), width: r * 0.46, height: r * 0.40),
        math.pi * 0.15,
        math.pi * 0.70,
        false,
        facePaint,
      );
    }

    // Sparkles on cheer only — the reward has to look different, not just say so.
    if (mood == BloomMood.cheer) {
      final spark = Paint()
        ..color = RRColor.sunny
        ..strokeWidth = r * 0.08
        ..strokeCap = StrokeCap.round;
      void star(Offset c, double s) {
        canvas.drawLine(Offset(c.dx - s, c.dy), Offset(c.dx + s, c.dy), spark);
        canvas.drawLine(Offset(c.dx, c.dy - s), Offset(c.dx, c.dy + s), spark);
      }

      star(Offset(cx - r * 1.15, cy - r * 0.55), r * 0.20);
      star(Offset(cx + r * 1.18, cy - r * 0.20), r * 0.15);
      star(Offset(cx + r * 0.95, cy - r * 0.95), r * 0.11);
    }
  }

  @override
  bool shouldRepaint(_BloomPainter old) =>
      old.mood != mood || old.glasses != glasses;
}