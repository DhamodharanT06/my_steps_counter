import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

enum ActivityState { resting, walking, running, goalReached }

/// The big icon above the step count. Distinct per state, each with its own
/// motion and color, so the state reads at a glance:
///  - resting: a sleep glyph that breathes slowly (nothing is happening)
///  - walking: a striding figure that rocks side to side
///  - running: the same figure, faster and with a bit of lift
///  - goalReached: a burst of little rays behind a star, celebrating
class ActivityStatusIcon extends StatefulWidget {
  const ActivityStatusIcon({super.key, required this.state, this.size = 64});
  final ActivityState state;
  final double size;

  @override
  State<ActivityStatusIcon> createState() => _ActivityStatusIconState();
}

class _ActivityStatusIconState extends State<ActivityStatusIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _durationFor(widget.state),
  )..repeat();

  Duration _durationFor(ActivityState s) => switch (s) {
    ActivityState.resting => const Duration(milliseconds: 2600),
    ActivityState.walking => const Duration(milliseconds: 900),
    ActivityState.running => const Duration(milliseconds: 480),
    ActivityState.goalReached => const Duration(milliseconds: 1400),
  };

  @override
  void didUpdateWidget(ActivityStatusIcon old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      _c.duration = _durationFor(widget.state);
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder:
          (child, anim) => ScaleTransition(
            scale: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
      child: SizedBox(
        key: ValueKey(widget.state),
        width: size,
        height: size,
        child: AnimatedBuilder(
          animation: _c,
          builder:
              (context, _) =>
                  CustomPaint(painter: _StatusPainter(widget.state, _c.value)),
        ),
      ),
    );
  }
}

class _StatusPainter extends CustomPainter {
  _StatusPainter(this.state, this.t);
  final ActivityState state;
  final double t; // 0..1 looping progress

  @override
  void paint(Canvas canvas, Size size) {
    switch (state) {
      case ActivityState.resting:
        _paintBackdrop(canvas, size, [
          AppColors.surfaceHigh,
          AppColors.surface,
        ]);
        _paintResting(canvas, size);
      case ActivityState.walking:
        _paintBackdrop(canvas, size, [
          AppColors.mint.alp(0.32),
          AppColors.mint.alp(0.05),
        ]);
        _paintFigure(canvas, size, speed: 1);
      case ActivityState.running:
        _paintBackdrop(canvas, size, [
          AppColors.ember.alp(0.34),
          AppColors.ember.alp(0.05),
        ]);
        _paintFigure(canvas, size, speed: 1.9, lean: true);
      case ActivityState.goalReached:
        _paintBackdrop(canvas, size, [
          AppColors.sun.alp(0.45),
          AppColors.ember.alp(0.10),
        ]);
        _paintCelebrate(canvas, size);
    }
  }

  /// A soft gradient plate + drop shadow behind the figure, so each state
  /// reads as a small badge rather than a bare line drawing.
  void _paintBackdrop(Canvas canvas, Size size, List<Color> colors) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.48;
    canvas.drawCircle(
      c + const Offset(0, 3),
      r,
      Paint()
        ..color = Colors.black.alp(0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: colors,
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void _paintResting(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    // Slow breathing scale on the base circle.
    final breathe = 1 + 0.05 * math.sin(t * 2 * math.pi);
    final r = size.width * 0.30 * breathe;
    canvas.drawCircle(
      c,
      r,
      Paint()..color = AppColors.muted.withAlpha((255 * 0.18).round()),
    );
    // Crescent "sleep" glyph: one disc minus an off-center disc.
    final glyphPaint =
        Paint()
          ..color = AppColors.muted
          ..style = PaintingStyle.fill;
    final disc =
        Path()..addOval(Rect.fromCircle(center: c, radius: size.width * 0.15));
    final bite =
        Path()..addOval(
          Rect.fromCircle(
            center: c + Offset(size.width * 0.09, -size.width * 0.06),
            radius: size.width * 0.15,
          ),
        );
    canvas.drawPath(
      Path.combine(PathOperation.difference, disc, bite),
      glyphPaint,
    );
    // Drifting "z"s.
    final zStyle = TextStyle(
      color: AppColors.muted.withAlpha((255 * 0.9).round()),
      fontSize: size.width * 0.16,
      fontWeight: FontWeight.w800,
    );
    for (var i = 0; i < 3; i++) {
      final local = ((t + i / 3) % 1.0);
      final dy = -local * size.height * 0.55;
      final dx = local * size.width * 0.32;
      final opacity = (1 - local).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: 'z',
          style: zStyle.copyWith(
            color: zStyle.color!.withAlpha((255 * opacity).round()),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        c +
            Offset(size.width * 0.18 + dx, -size.width * 0.05 + dy) -
            Offset(tp.width / 2, tp.height / 2),
      );
    }
  }

  void _paintFigure(
    Canvas canvas,
    Size size, {
    double speed = 1,
    bool lean = false,
  }) {
    final c = size.center(Offset.zero);
    final w = size.width;
    final color = lean ? AppColors.ember : AppColors.mint;

    // Halo ring that pulses with the stride.
    final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi * speed);
    canvas.drawCircle(
      c,
      w * 0.46,
      Paint()..color = color.withAlpha((255 * (0.10 + 0.06 * pulse)).round()),
    );

    final swing = math.sin(t * 2 * math.pi * speed); // -1..1
    final bob = math.sin(t * 4 * math.pi * speed).abs(); // 0..1, double freq
    final bodyLean = lean ? -0.12 : 0.0;

    canvas.save();
    canvas.translate(c.dx, c.dy - bob * w * 0.05);
    canvas.rotate(bodyLean);

    final stroke =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.07
          ..strokeCap = StrokeCap.round;

    // Head, with a small shine so it doesn't read as a flat dot.
    canvas.drawCircle(Offset(0, -w * 0.30), w * 0.10, Paint()..color = color);
    canvas.drawCircle(
      Offset(-w * 0.025, -w * 0.325),
      w * 0.028,
      Paint()..color = Colors.white.alp(0.55),
    );
    // Torso.
    final hipY = w * 0.04;
    canvas.drawLine(
      Offset(0, -w * 0.20),
      Offset(w * 0.03 * swing, hipY),
      stroke,
    );
    // Arms swing opposite to legs.
    canvas.drawLine(
      Offset(0, -w * 0.16),
      Offset(-swing * w * 0.18, w * 0.02),
      stroke,
    );
    canvas.drawLine(
      Offset(0, -w * 0.16),
      Offset(swing * w * 0.18, -w * 0.06),
      stroke,
    );
    // Legs: opposite phase, front leg lifts more when running.
    final lift = lean ? 0.16 : 0.10;
    canvas.drawLine(
      Offset(w * 0.03 * swing, hipY),
      Offset(
        swing * w * 0.20,
        hipY + w * 0.20 - (swing > 0 ? swing : 0) * w * lift,
      ),
      stroke,
    );
    canvas.drawLine(
      Offset(w * 0.03 * swing, hipY),
      Offset(
        -swing * w * 0.20,
        hipY + w * 0.20 - (swing < 0 ? -swing : 0) * w * lift,
      ),
      stroke,
    );
    canvas.restore();

    if (lean) {
      // Speed lines behind a runner.
      final lineP =
          Paint()
            ..color = color.withAlpha((255 * 0.5).round())
            ..strokeWidth = w * 0.02
            ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 3; i++) {
        final off = (t * 2 + i * 0.3) % 1.0;
        final x = -w * 0.30 - off * w * 0.18;
        canvas.drawLine(
          Offset(x, -w * 0.06 + i * w * 0.10),
          Offset(x - w * 0.10, -w * 0.06 + i * w * 0.10),
          lineP,
        );
      }
    }
  }

  void _paintCelebrate(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final w = size.width;
    final spin = t * 2 * math.pi;
    final pop = 0.9 + 0.1 * math.sin(t * 2 * math.pi * 2);

    // Radiating rays.
    final rayPaint =
        Paint()
          ..color = AppColors.sun
          ..strokeWidth = w * 0.045
          ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 10; i++) {
      final ang = spin + i * (2 * math.pi / 10);
      final inner = w * 0.34;
      final outer = w * (0.44 + 0.05 * math.sin(t * 2 * math.pi * 3 + i));
      canvas.drawLine(
        c + Offset(math.cos(ang), math.sin(ang)) * inner,
        c + Offset(math.cos(ang), math.sin(ang)) * outer,
        rayPaint,
      );
    }

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(pop);
    // Star badge.
    final path = Path();
    const spikes = 5;
    final rOuter = w * 0.28;
    final rInner = w * 0.12;
    for (var i = 0; i < spikes * 2; i++) {
      final r = i.isEven ? rOuter : rInner;
      final ang = -math.pi / 2 + i * math.pi / spikes;
      final p = Offset(math.cos(ang) * r, math.sin(ang) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.sun, AppColors.ember],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: rOuter)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StatusPainter old) => old.t != t || old.state != state;
}
