import 'dart:math';
import 'package:flutter/material.dart';

class RadarPainter extends CustomPainter {
  final double angle;


  RadarPainter({
    required this.angle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw the radar circle
    final paint = Paint()
      ..color = Colors.green.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);

    // Draw the radar line
    final radarPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2.0;
    final lineEnd = Offset(
      center.dx + radius * cos(angle),
      center.dy + radius * sin(angle),
    );
    canvas.drawLine(center, lineEnd, radarPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
