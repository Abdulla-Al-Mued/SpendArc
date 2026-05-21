import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paints the circular arc gauge that shows the expense/income ratio.
class ArcMeterPainter extends CustomPainter {
  final double value;

  const ArcMeterPainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.1;
    final rect =
        Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final start = math.pi * 0.78;
    final sweep = math.pi * 1.44;

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = const Color(0xFFE2E5DD);

    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..shader = const SweepGradient(
        colors: [Color(0xFF0E7C7B), Color(0xFFF08A4B), Color(0xFF0E7C7B)],
      ).createShader(rect);

    canvas.drawArc(rect, start, sweep, false, base);
    canvas.drawArc(rect, start, sweep * value.clamp(0, 1), false, active);
  }

  @override
  bool shouldRepaint(covariant ArcMeterPainter oldDelegate) =>
      oldDelegate.value != value;
}
