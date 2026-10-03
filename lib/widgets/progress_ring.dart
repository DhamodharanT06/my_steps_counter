import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// Circular goal ring. Sweeps to the new value with an ease-out curve
/// every time [progress] changes.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.child,
    this.size = 240,
    this.stroke = 22,
  });

  final double progress;
  final double size;
  final double stroke;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0,
              end: progress.clamp(0.0, 1.0).toDouble(),
            ),
            duration: Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder:
                (context, v, _) => CustomPaint(
                  size: Size.square(size),
                  painter: _RingPainter(v, stroke),
                ),
          ),
          child,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.stroke);
  final double progress;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.surfaceHigh.alp(0),
    );

    // Fine tick marks around the track (like a stopwatch bezel)
    final tick =
        Paint()
          ..color = AppColors.outline
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
    final inner = radius - stroke / 2 - 10;
    for (var i = 0; i < 60; i++) {
      final ang = i * 2 * math.pi / 60;
      final len = i % 5 == 0 ? 8.0 : 4.0;
      canvas.drawLine(
        center + Offset(math.cos(ang), math.sin(ang)) * inner,
        center + Offset(math.cos(ang), math.sin(ang)) * (inner - len),
        tick,
      );
    }

    if (progress <= 0) return;
    final sweep = 2 * math.pi * progress;

    // Soft glow
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..color = AppColors.ember.withAlpha((255 * 0.45).round())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Progress arc: sun -> ember
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.max(sweep, 0.2),
          colors: [AppColors.sun, AppColors.ember],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );

    // Head knob
    if (progress > 0.02) {
      final ang = -math.pi / 2 + sweep;
      final head = center + Offset(math.cos(ang), math.sin(ang)) * radius;
      canvas.drawCircle(head, stroke * 0.22, Paint()..color = AppColors.pine);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.stroke != stroke;
}
