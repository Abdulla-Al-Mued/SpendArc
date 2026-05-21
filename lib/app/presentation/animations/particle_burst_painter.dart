import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paints an expanding ring of particles originating from [origin].
/// Driven by a 0→1 [progress] value from an [AnimationController].
class ParticleBurstPainter extends CustomPainter {
  final double progress;
  final Offset origin;

  const ParticleBurstPainter({required this.progress, required this.origin});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0 || origin == Offset.zero) return;

    final paint = Paint()
      ..color = Colors.redAccent.withValues(alpha: 1 - progress);

    for (var i = 0; i < 18; i++) {
      final angle = (math.pi * 2 / 18) * i;
      final distance = 8 + 46 * Curves.easeOut.transform(progress);
      final offset =
          origin + Offset(math.cos(angle), math.sin(angle)) * distance;
      canvas.drawCircle(offset, 4 * (1 - progress), paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticleBurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.origin != origin;
}
