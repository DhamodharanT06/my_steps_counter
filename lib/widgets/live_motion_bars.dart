import 'package:flutter/material.dart';
import '../theme.dart';

/// Scrolling equaliser driven by the live accelerometer magnitude.
class LiveMotionBars extends StatefulWidget {
  const LiveMotionBars({super.key, required this.motion});
  final ValueNotifier<double> motion;

  @override
  State<LiveMotionBars> createState() => _LiveMotionBarsState();
}

class _LiveMotionBarsState extends State<LiveMotionBars> {
  static const _count = 36;
  final List<double> _samples = List<double>.filled(
    _count,
    0.0,
    growable: true,
  );

  @override
  void initState() {
    super.initState();
    widget.motion.addListener(_onSample);
  }

  @override
  void dispose() {
    widget.motion.removeListener(_onSample);
    super.dispose();
  }

  void _onSample() {
    if (!mounted) return;
    setState(() {
      _samples.removeAt(0);
      _samples.add(widget.motion.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size(double.infinity, 64),
        painter: _BarsPainter(List<double>.of(_samples)),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.samples);
  final List<double> samples;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 4.0;
    final n = samples.length;
    final w = (size.width - gap * (n - 1)) / n;
    for (var i = 0; i < n; i++) {
      final v = samples[i];
      final h = 5 + v * (size.height - 5);
      final x = i * (w + gap);
      final fade = 0.25 + 0.75 * (i / (n - 1));
      final color = Color.lerp(
        AppColors.mint,
        AppColors.ember,
        v,
      )!.withAlpha((255 * fade).round());
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, w, h),
          Radius.circular(w / 2),
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => true;
}
