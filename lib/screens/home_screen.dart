import 'package:flutter/material.dart';

import '../services/fitness_controller.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/app_card.dart';
import '../widgets/count_up_text.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/live_motion_bars.dart';
import '../widgets/live_step_number.dart';
import '../widgets/activity_status_icon.dart';
import '../widgets/progress_ring.dart';
import '../widgets/pulse_dot.dart';

ActivityState _stateFor(FitnessController c) {
  if (c.goalReached) return ActivityState.goalReached;
  if (c.activityLabel == 'Running') return ActivityState.running;
  if (c.activityLabel == 'Walking') return ActivityState.walking;
  return ActivityState.resting;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});
  final FitnessController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final c = controller;
          final showBanner =
              c.permission == MotionPermission.denied ||
              c.permission == MotionPermission.permanentlyDenied;
          return ListView(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              FadeSlideIn(key: ValueKey('header'), child: _Header(c)),
              SizedBox(height: 20),
              if (showBanner) ...[
                FadeSlideIn(
                  key: ValueKey('banner'),
                  delay: Duration(milliseconds: 60),
                  child: _PermissionBanner(c),
                ),
                SizedBox(height: 16),
              ],
              FadeSlideIn(
                key: ValueKey('ring'),
                delay: Duration(milliseconds: 100),
                child: _RingCard(c),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FadeSlideIn(
                      key: ValueKey('kcal'),
                      delay: Duration(milliseconds: 200),
                      child: _StatTile(
                        icon: Icons.local_fire_department_rounded,
                        color: AppColors.ember,
                        value: c.calories,
                        decimals: 0,
                        label: 'kcal burned',
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: FadeSlideIn(
                      key: ValueKey('dist'),
                      delay: Duration(milliseconds: 260),
                      child: _StatTile(
                        icon: Icons.route_rounded,
                        color: AppColors.sun,
                        value: c.distanceKm,
                        decimals: 2,
                        label: 'km covered',
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: FadeSlideIn(
                      key: ValueKey('mins'),
                      delay: Duration(milliseconds: 320),
                      child: _StatTile(
                        icon: Icons.timer_rounded,
                        color: AppColors.mint,
                        value: c.activeMinutes,
                        decimals: 0,
                        label: 'active min',
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              FadeSlideIn(
                key: ValueKey('week'),
                delay: Duration(milliseconds: 350),
                child: _WeekAndPaceCard(c),
              ),
              SizedBox(height: 16),
              FadeSlideIn(
                key: ValueKey('live'),
                delay: Duration(milliseconds: 380),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Live motion', style: AppText.h2),
                          Spacer(),
                          Icon(
                            Icons.sensors_rounded,
                            size: 18,
                            color: AppColors.mint.withAlpha(
                              (255 * 0.9).round(),
                            ),
                          ),
                          SizedBox(width: 6),
                          Text('accelerometer', style: AppText.small),
                        ],
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        height: 64,
                        child: LiveMotionBars(motion: c.motion),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              FadeSlideIn(
                key: ValueKey('tip'),
                delay: Duration(milliseconds: 440),
                child: _InsightCard(c),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.c);
  final FitnessController c;

  @override
  Widget build(BuildContext context) {
    final streak = c.streak;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting(), style: AppText.muted),
              SizedBox(height: 2),
              Text('Today', style: AppText.h1),
              SizedBox(height: 2),
              Text(longDate(DateTime.now()), style: AppText.muted),
            ],
          ),
        ),
        AnimatedContainer(
          duration: Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: (streak > 0 ? AppColors.sun : AppColors.muted).withAlpha(
              (255 * 0.14).round(),
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: (streak > 0 ? AppColors.sun : AppColors.muted).withAlpha(
                (255 * 0.4).round(),
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bolt_rounded,
                size: 20,
                color: streak > 0 ? AppColors.sun : AppColors.muted,
              ),
              SizedBox(width: 4),
              Text(
                streak == 1 ? '1 day streak' : '$streak day streak',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: streak > 0 ? AppColors.sun : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner(this.c);
  final FitnessController c;

  @override
  Widget build(BuildContext context) {
    final permanent = c.permission == MotionPermission.permanentlyDenied;
    return AppCard(
      borderColor: AppColors.ember.withAlpha((255 * 0.6).round()),
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.directions_walk_rounded, color: AppColors.ember),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              permanent
                  ? 'Motion access is blocked. Open settings to allow it. Steps are estimated from the accelerometer meanwhile.'
                  : 'Motion access is off, so steps are estimated from the accelerometer. No permission dialog? Add ACTIVITY_RECOGNITION to AndroidManifest.xml and reinstall.',
              style: AppText.muted,
            ),
          ),
          SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ember,
              foregroundColor: AppColors.pine,
            ),
            onPressed: permanent ? c.openSettings : c.requestPermission,
            child: Text(permanent ? 'Settings' : 'Allow'),
          ),
        ],
      ),
    );
  }
}

class _RingCard extends StatelessWidget {
  const _RingCard(this.c);
  final FitnessController c;

  @override
  Widget build(BuildContext context) {
    final walking = c.cadence > 0;
    return AppCard(
      padding: EdgeInsets.fromLTRB(20, 26, 20, 22),
      child: Column(
        children: [
          ProgressRing(
            progress: c.progress,
            size: 300, //262,
            stroke: 16, //22,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ActivityStatusIcon(state: _stateFor(c), size: 96),
                SizedBox(height: 4),
                LiveStepNumber(value: c.steps, style: AppText.display),
                SizedBox(height: 6),
                Text('of ${fmtInt(c.goal)} steps', style: AppText.muted),
              ],
            ),
          ),
          SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _Pill(
                leading: PulseDot(
                  color: walking ? AppColors.mint : AppColors.muted,
                  active: walking,
                  size: 8,
                ),
                text: '${c.activityLabel}  ${c.cadence} spm',
              ),
              AnimatedSwitcher(
                duration: Duration(milliseconds: 450),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder:
                    (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(scale: anim, child: child),
                    ),
                child:
                    c.goalReached
                        ? _Pill(
                          key: ValueKey('done'),
                          leading: Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: AppColors.pine,
                          ),
                          text: 'Goal reached',
                          filled: true,
                        )
                        : _Pill(
                          key: ValueKey('togo'),
                          leading: Icon(
                            Icons.flag_rounded,
                            size: 18,
                            color: AppColors.sun,
                          ),
                          text: '${fmtInt(c.remaining)} to go',
                        ),
              ),
            ],
          ),
          if (c.usingFallback) ...[
            SizedBox(height: 14),
            Text(
              'Accelerometer mode: counts may be approximate',
              style: AppText.small,
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.leading,
    required this.text,
    this.filled = false,
  });
  final Widget leading;
  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: filled ? AppColors.mint : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: filled ? AppColors.pine : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekAndPaceCard extends StatelessWidget {
  const _WeekAndPaceCard(this.c);
  final FitnessController c;

  @override
  Widget build(BuildContext context) {
    final eta = c.etaMinutesToGoal;
    final pace = c.paceMinPerKm;
    final paceText =
        pace == null
            ? '—'
            : '${pace.floor()}:${((pace - pace.floor()) * 60).round().toString().padLeft(2, '0')} /km';
    final etaText = eta == null ? '—' : '$eta min';

    return AppCard(
      radius: 24,
      child: Row(
        children: [
          Expanded(
            child: _MiniStat(
              label: '7-day avg',
              value: fmtInt(c.weeklyAverage),
              suffix: 'steps/day',
            ),
          ),
          Container(width: 1, height: 34, color: AppColors.outline.alp(0.5)),
          Expanded(
            child: _MiniStat(label: 'Pace', value: paceText, suffix: ''),
          ),
          Container(width: 1, height: 34, color: AppColors.outline.alp(0.5)),
          Expanded(
            child: _MiniStat(label: 'To goal', value: etaText, suffix: ''),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.suffix,
  });
  final String label;
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppText.small),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppColors.text,
          ),
        ),
        if (suffix.isNotEmpty) Text(suffix, style: AppText.small),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.decimals,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final num value;
  final int decimals;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.fromLTRB(14, 16, 14, 16),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withAlpha((255 * 0.16).round()),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 21, color: color),
          ),
          SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: CountUpText(
              value: value,
              decimals: decimals,
              style: AppText.value,
              duration: Duration(milliseconds: 250),
            ),
          ),
          SizedBox(height: 2),
          Text(label, style: AppText.small),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard(this.c);
  final FitnessController c;

  @override
  Widget build(BuildContext context) {
    final text =
        c.goalReached
            ? 'Goal done. Everything from here is a bonus, so keep the pace easy.'
            : 'About ${c.remaining ~/ 100} min of brisk walking gets you to ${fmtInt(c.goal)} steps.';
    return AppCard(
      color: AppColors.ember,
      borderColor: AppColors.ember,
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.pine.withAlpha((255 * 0.16).round()),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.trending_up_rounded, color: AppColors.pine),
          ),
          SizedBox(width: 14),
          Expanded(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 400),
              child: Text(
                text,
                key: ValueKey(c.goalReached),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: AppColors.pine,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
