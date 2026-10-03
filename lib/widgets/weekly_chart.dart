import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/fitness_controller.dart';
import '../theme.dart';
import '../utils.dart';

/// 7-day bar chart. Bars grow with a staggered ease-out; tap a bar to inspect.
class WeeklyChart extends StatefulWidget {
  const WeeklyChart({super.key, required this.days, required this.goal});
  final List<DayStat> days;
  final int goal;

  @override
  State<WeeklyChart> createState() => _WeeklyChartState();
}

class _WeeklyChartState extends State<WeeklyChart> {
  static double _areaH = 170;
  static double _labelReserve = 26;
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    final peak = days.map((d) => d.steps).fold<int>(0, math.max);
    final maxV = math.max(widget.goal, peak) * 1.12;
    final barArea = _areaH - _labelReserve;

    return Column(
      children: [
        SizedBox(
          height: _areaH,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GoalLinePainter(
                    fraction: widget.goal / maxV,
                    reserve: _labelReserve,
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < days.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap:
                            () => setState(
                              () => _selected = _selected == i ? null : i,
                            ),
                        child: _bar(i, days[i], maxV, barArea, days.length),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < days.length; i++)
              Expanded(
                child: Center(
                  child: Text(
                    weekdayLetters[days[i].date.weekday - 1],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          i == days.length - 1
                              ? FontWeight.w800
                              : FontWeight.w600,
                      color:
                          i == days.length - 1
                              ? AppColors.sun
                              : AppColors.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _bar(int i, DayStat d, double maxV, double barArea, int total) {
    final met = d.steps >= widget.goal;
    final isToday = i == total - 1;
    final selected = _selected == i;
    final color =
        selected
            ? AppColors.sun
            : met
            ? AppColors.ember
            : isToday
            ? AppColors.sun.withAlpha((255 * 0.8).round())
            : Color(0xFF2F6350);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AnimatedOpacity(
          duration: Duration(milliseconds: 250),
          curve: Curves.easeOut,
          opacity: selected ? 1 : 0,
          child: SizedBox(
            height: _labelReserve - 4,
            child: Center(
              child: Text(
                compactInt(d.steps),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: d.steps / maxV),
          duration: Duration(milliseconds: 700 + i * 90),
          curve: Curves.easeOutCubic,
          builder:
              (context, v, _) => Container(
                width: 24,
                height: math.max(6, v * barArea),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
        ),
      ],
    );
  }
}

class _GoalLinePainter extends CustomPainter {
  _GoalLinePainter({required this.fraction, required this.reserve});
  final double fraction;
  final double reserve;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height - (size.height - reserve) * fraction;
    final paint =
        Paint()
          ..color = AppColors.sun.withAlpha((255 * 0.55).round())
          ..strokeWidth = 1.5;
    for (double x = 0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GoalLinePainter old) =>
      old.fraction != fraction || old.reserve != reserve;
}
