import 'dart:math';
import 'package:flutter/material.dart';

/// Analog Wall Clock Widget for TimeTalk
/// A beautiful, accessible analog clock with classic wall clock design
/// 
/// Features:
/// - Classic wall clock styling
/// - Hour, minute, and second hands
/// - Roman or Arabic numerals
/// - Tick marks for all 60 minutes
/// - Smooth second hand animation

class AnalogClock extends StatelessWidget {
  final DateTime time;
  final double size;
  final bool isDarkMode;

  const AnalogClock({
    super.key,
    required this.time,
    this.size = 300,
    this.isDarkMode = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: ClockPainter(
          time: time,
          isDarkMode: isDarkMode,
        ),
      ),
    );
  }
}

class ClockPainter extends CustomPainter {
  final DateTime time;
  final bool isDarkMode;

  ClockPainter({
    required this.time,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    // Colors based on theme
    final clockFaceColor = isDarkMode 
        ? const Color(0xFF1A2332) 
        : const Color(0xFFFAFAFA);
    final clockBorderColor = isDarkMode 
        ? const Color(0xFF00BFA5)
        : const Color(0xFF00796B);
    final hourHandColor = isDarkMode 
        ? const Color(0xFFE0E0E0)
        : const Color(0xFF37474F);
    final minuteHandColor = isDarkMode 
        ? const Color(0xFFBDBDBD)
        : const Color(0xFF455A64);
    final secondHandColor = const Color(0xFFFF5252);
    final numberColor = isDarkMode 
        ? const Color(0xFFE0E0E0)
        : const Color(0xFF37474F);
    final tickColor = isDarkMode 
        ? const Color(0xFF4DB6AC)
        : const Color(0xFF00796B);

    // Draw outer glow/shadow
    final glowPaint = Paint()
      ..color = clockBorderColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center, radius * 0.92, glowPaint);

    // Draw clock face background
    final facePaint = Paint()
      ..color = clockFaceColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.88, facePaint);

    // Draw outer border ring
    final borderPaint = Paint()
      ..color = clockBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.04;
    canvas.drawCircle(center, radius * 0.90, borderPaint);

    // Draw inner decorative ring
    final innerRingPaint = Paint()
      ..color = clockBorderColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.01;
    canvas.drawCircle(center, radius * 0.82, innerRingPaint);

    // Draw minute tick marks
    for (int i = 0; i < 60; i++) {
      final angle = (i * 6) * pi / 180 - pi / 2;
      final isHourMark = i % 5 == 0;
      
      final tickLength = isHourMark ? radius * 0.12 : radius * 0.05;
      final tickWidth = isHourMark ? radius * 0.025 : radius * 0.012;
      
      final outerPoint = Offset(
        center.dx + cos(angle) * radius * 0.78,
        center.dy + sin(angle) * radius * 0.78,
      );
      final innerPoint = Offset(
        center.dx + cos(angle) * (radius * 0.78 - tickLength),
        center.dy + sin(angle) * (radius * 0.78 - tickLength),
      );

      final tickPaint = Paint()
        ..color = isHourMark ? clockBorderColor : tickColor.withOpacity(0.6)
        ..strokeWidth = tickWidth
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(outerPoint, innerPoint, tickPaint);
    }

    // Draw hour numbers
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    for (int i = 1; i <= 12; i++) {
      final angle = (i * 30) * pi / 180 - pi / 2;
      final numberRadius = radius * 0.60;
      
      final position = Offset(
        center.dx + cos(angle) * numberRadius,
        center.dy + sin(angle) * numberRadius,
      );

      textPainter.text = TextSpan(
        text: i.toString(),
        style: TextStyle(
          color: numberColor,
          fontSize: radius * 0.14,
          fontWeight: FontWeight.bold,
          fontFamily: 'serif',
        ),
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          position.dx - textPainter.width / 2,
          position.dy - textPainter.height / 2,
        ),
      );
    }

    // Calculate hand angles
    final secondAngle = (time.second * 6) * pi / 180 - pi / 2;
    final minuteAngle = (time.minute * 6 + time.second * 0.1) * pi / 180 - pi / 2;
    final hourAngle = (time.hour % 12 * 30 + time.minute * 0.5) * pi / 180 - pi / 2;

    // Draw hour hand (thick, short)
    _drawHand(
      canvas: canvas,
      center: center,
      angle: hourAngle,
      length: radius * 0.45,
      width: radius * 0.055,
      color: hourHandColor,
      hasShadow: true,
    );

    // Draw minute hand (thinner, longer)
    _drawHand(
      canvas: canvas,
      center: center,
      angle: minuteAngle,
      length: radius * 0.65,
      width: radius * 0.04,
      color: minuteHandColor,
      hasShadow: true,
    );

    // Draw second hand (thin, red)
    _drawHand(
      canvas: canvas,
      center: center,
      angle: secondAngle,
      length: radius * 0.72,
      width: radius * 0.015,
      color: secondHandColor,
      hasShadow: false,
      hasCounter: true,
      counterLength: radius * 0.15,
    );

    // Draw center cap
    final centerCapGradient = RadialGradient(
      colors: [
        clockBorderColor,
        clockBorderColor.withOpacity(0.8),
      ],
    );
    final centerCapPaint = Paint()
      ..shader = centerCapGradient.createShader(
        Rect.fromCircle(center: center, radius: radius * 0.08),
      );
    canvas.drawCircle(center, radius * 0.08, centerCapPaint);

    // Draw center dot
    final centerDotPaint = Paint()
      ..color = secondHandColor;
    canvas.drawCircle(center, radius * 0.04, centerDotPaint);
  }

  void _drawHand({
    required Canvas canvas,
    required Offset center,
    required double angle,
    required double length,
    required double width,
    required Color color,
    bool hasShadow = false,
    bool hasCounter = false,
    double counterLength = 0,
  }) {
    // Draw shadow first
    if (hasShadow) {
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
      
      final shadowOffset = const Offset(2, 2);
      final endPoint = Offset(
        center.dx + cos(angle) * length + shadowOffset.dx,
        center.dy + sin(angle) * length + shadowOffset.dy,
      );
      canvas.drawLine(center + shadowOffset, endPoint, shadowPaint);
    }

    // Draw the hand
    final handPaint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    final endPoint = Offset(
      center.dx + cos(angle) * length,
      center.dy + sin(angle) * length,
    );

    canvas.drawLine(center, endPoint, handPaint);

    // Draw counter-balance for second hand
    if (hasCounter && counterLength > 0) {
      final counterAngle = angle + pi;
      final counterPoint = Offset(
        center.dx + cos(counterAngle) * counterLength,
        center.dy + sin(counterAngle) * counterLength,
      );
      canvas.drawLine(center, counterPoint, handPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ClockPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.isDarkMode != isDarkMode;
  }
}

