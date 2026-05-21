import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/transaction.dart';

/// Paints the daily-spend line chart with a gradient fill.
class SpendLineChartPainter extends CustomPainter {
  final List<DailySpend> points;

  const SpendLineChartPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    // Horizontal grid lines
    final axisPaint = Paint()
      ..color = const Color(0xFFE3E5DE)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), axisPaint);
    }

    if (points.isEmpty) return;

    final maxAmount = points
        .map((p) => p.amount)
        .reduce(math.max)
        .clamp(1, double.infinity);

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? size.width / 2
          : i * size.width / (points.length - 1);
      final y =
          size.height - (points[i].amount / maxAmount * size.height * 0.86) - 8;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Gradient fill under the line
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x550E7C7B), Color(0x000E7C7B)],
        ).createShader(Offset.zero & size),
    );

    // Line stroke
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF0E7C7B)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant SpendLineChartPainter oldDelegate) =>
      oldDelegate.points != points;
}
