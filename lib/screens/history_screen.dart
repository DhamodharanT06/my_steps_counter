import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../services/fitness_controller.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/app_card.dart';
import '../widgets/count_up_text.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/weekly_chart.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.controller});
  final FitnessController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final c = controller;
          final week = c.lastDays(7);
          final total = week.fold<int>(0, (s, d) => s + d.steps);
          final avg = total ~/ 7;
          final best = week.map((d) => d.steps).fold<int>(0, math.max);
          final recent = c.lastDays(14).reversed.toList();

          return ListView(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              FadeSlideIn(
                key: ValueKey('title'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your week', style: AppText.muted),
                    SizedBox(height: 2),
                    Text('Activity', style: AppText.h1),
                  ],
                ),
              ),
              SizedBox(height: 20),
              FadeSlideIn(
                key: ValueKey('summary'),
                delay: Duration(milliseconds: 80),
                child: Row(
                  children: [
                    Expanded(child: _Summary(label: 'Total', value: total)),
                    SizedBox(width: 12),
                    Expanded(child: _Summary(label: 'Daily avg', value: avg)),
                    SizedBox(width: 12),
                    Expanded(child: _Summary(label: 'Best day', value: best)),
                  ],
                ),
              ),
              SizedBox(height: 16),
              FadeSlideIn(
                key: ValueKey('chart'),
                delay: Duration(milliseconds: 160),
                child: AppCard(
                  padding: EdgeInsets.fromLTRB(18, 20, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Steps per day', style: AppText.h2),
                          Spacer(),
                          Container(
                            width: 18,
                            height: 2,
                            color: AppColors.sun.withAlpha((255 * 0.7).round()),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Goal ${compactInt(c.goal)}',
                            style: AppText.small,
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      WeeklyChart(days: week, goal: c.goal),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              FadeSlideIn(
                key: ValueKey('recent'),
                delay: Duration(milliseconds: 240),
                child: AppCard(
                  padding: EdgeInsets.fromLTRB(18, 20, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recent days', style: AppText.h2),
                      SizedBox(height: 8),
                      for (var i = 0; i < recent.length; i++)
                        _DayRow(
                          index: i,
                          stat: recent[i],
                          goal: c.goal,
                          km: c.distanceFor(recent[i].steps),
                          isLast: i == recent.length - 1,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 22,
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.small),
          SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: CountUpText(
              value: value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.index,
    required this.stat,
    required this.goal,
    required this.km,
    required this.isLast,
  });

  final int index;
  final DayStat stat;
  final int goal;
  final double km;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final met = stat.steps >= goal;
    final frac =
        goal == 0 ? 0.0 : (stat.steps / goal).clamp(0.0, 1.0).toDouble();
    final color = met ? AppColors.ember : AppColors.sun;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border:
            isLast
                ? null
                : Border(
                  bottom: BorderSide(
                    color: AppColors.outline.withAlpha((255 * 0.45).round()),
                  ),
                ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shortWeekday(stat.date),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
                Text(dayMonth(stat.date), style: AppText.small),
              ],
            ),
          ),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: frac),
              duration: Duration(milliseconds: 800 + index * 50),
              curve: Curves.easeOutCubic,
              builder:
                  (context, v, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Container(height: 9, color: AppColors.surfaceHigh),
                        FractionallySizedBox(
                          widthFactor: v,
                          child: Container(height: 9, color: color),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
          SizedBox(width: 14),
          SizedBox(
            width: 74,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmtInt(stat.steps),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
                Text('${km.toStringAsFixed(1)} km', style: AppText.small),
              ],
            ),
          ),
          SizedBox(
            width: 28,
            child:
                met
                    ? Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: AppColors.mint,
                    )
                    : null,
          ),
        ],
      ),
    );
  }
}
