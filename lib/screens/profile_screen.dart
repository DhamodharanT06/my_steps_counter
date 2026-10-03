import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../services/fitness_controller.dart';
import '../services/home_widget_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/app_card.dart';
import '../widgets/count_up_text.dart';
import '../widgets/fade_slide_in.dart';
import 'faq_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.controller});
  final FitnessController controller;

  static final _presets = [5000, 8000, 10000, 12000];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final c = controller;
          return ListView(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              FadeSlideIn(
                key: ValueKey('title'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Make it yours', style: AppText.muted),
                    SizedBox(height: 2),
                    Text('Goals & body', style: AppText.h1),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Appearance
              FadeSlideIn(
                key: ValueKey('appearance'),
                delay: Duration(milliseconds: 40),
                child: ListenableBuilder(
                  listenable: AppThemeController.instance,
                  builder: (context, _) {
                    final dark = AppThemeController.instance.isDark;
                    return AppCard(
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.sun.withAlpha(
                                (255 * 0.15).round(),
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              dark
                                  ? Icons.dark_mode_rounded
                                  : Icons.light_mode_rounded,
                              color: AppColors.sun,
                              size: 22,
                            ),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Appearance', style: AppText.h2),
                                SizedBox(height: 2),
                                Text(
                                  dark ? 'Dark' : 'Light',
                                  style: AppText.muted,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: dark,
                            onChanged: AppThemeController.instance.setDark,
                            thumbColor: WidgetStatePropertyAll(AppColors.text),
                            trackColor: WidgetStateProperty.resolveWith(
                              (s) =>
                                  s.contains(WidgetState.selected)
                                      ? AppColors.ember
                                      : AppColors.surfaceHigh,
                            ),
                            trackOutlineColor: WidgetStatePropertyAll(
                              Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 16),

              // Notifications
              FadeSlideIn(
                key: ValueKey('notifications'),
                delay: Duration(milliseconds: 60),
                child: _NotificationsCard(),
              ),
              SizedBox(height: 20),

              // Goal
              FadeSlideIn(
                key: ValueKey('goal'),
                delay: Duration(milliseconds: 80),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily step goal', style: AppText.h2),
                      SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          CountUpText(
                            value: c.goal,
                            style: AppText.display.copyWith(fontSize: 46),
                            duration: Duration(milliseconds: 350),
                          ),
                          SizedBox(width: 8),
                          Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Text('steps', style: AppText.muted),
                          ),
                        ],
                      ),
                      Slider(
                        value: c.goal.toDouble().clamp(2000, 30000).toDouble(),
                        min: 2000,
                        max: 30000,
                        divisions: 56,
                        onChanged: (v) => c.setGoal(v.round()),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in _presets)
                            _PresetChip(
                              label: fmtInt(p),
                              selected: c.goal == p,
                              onTap: () => c.setGoal(p),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Body
              FadeSlideIn(
                key: ValueKey('body'),
                delay: Duration(milliseconds: 160),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Body metrics', style: AppText.h2),
                      SizedBox(height: 4),
                      Text(
                        'Used to estimate stride length, distance and calories.',
                        style: AppText.muted,
                      ),
                      SizedBox(height: 18),
                      _SliderRow(
                        label: 'Weight',
                        valueText: '${c.weightKg.round()} kg',
                        child: Slider(
                          value: c.weightKg.clamp(35, 150).toDouble(),
                          min: 35,
                          max: 150,
                          divisions: 115,
                          onChanged: (v) => c.setWeight(v.roundToDouble()),
                        ),
                      ),
                      _SliderRow(
                        label: 'Height',
                        valueText: '${c.heightCm.round()} cm',
                        child: Slider(
                          value: c.heightCm.clamp(120, 220).toDouble(),
                          min: 120,
                          max: 220,
                          divisions: 100,
                          onChanged: (v) => c.setHeight(v.roundToDouble()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Sensors
              FadeSlideIn(
                key: ValueKey('sensors'),
                delay: Duration(milliseconds: 240),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sensors', style: AppText.h2),
                      SizedBox(height: 14),
                      _SensorRow(
                        icon: Icons.directions_walk_rounded,
                        title: 'Step counter',
                        subtitle:
                            c.usingFallback
                                ? 'Unavailable, estimating from accelerometer'
                                : c.permission == MotionPermission.granted
                                ? 'Hardware pedometer active'
                                : 'Waiting for motion permission',
                        ok:
                            !c.usingFallback &&
                            c.permission == MotionPermission.granted,
                      ),
                      SizedBox(height: 12),
                      _SensorRow(
                        icon: Icons.vibration_rounded,
                        title: 'Accelerometer',
                        subtitle: 'Live motion and cadence',
                        ok: true,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Background tracking (Android)
              if (Platform.isAndroid) ...[
                FadeSlideIn(
                  key: ValueKey('background'),
                  delay: Duration(milliseconds: 280),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Count in background',
                                style: AppText.h2,
                              ),
                            ),
                            Switch(
                              value: c.backgroundEnabled,
                              onChanged: c.setBackgroundEnabled,
                              thumbColor: WidgetStatePropertyAll(
                                AppColors.text,
                              ),
                              trackColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.selected)
                                        ? AppColors.ember
                                        : AppColors.surfaceHigh,
                              ),
                              trackOutlineColor: WidgetStatePropertyAll(
                                Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Keeps a small notification with today\'s steps. Steps walked while the app is closed are always added when it reopens.',
                          style: AppText.muted,
                        ),
                        SizedBox(height: 16),
                        _SensorRow(
                          icon: Icons.sync_rounded,
                          title: 'Background service',
                          subtitle:
                              c.serviceRunning
                                  ? 'Running'
                                  : c.backgroundEnabled
                                  ? 'Not running yet, allow motion access'
                                  : 'Off',
                          ok: c.serviceRunning || !c.backgroundEnabled,
                        ),
                        SizedBox(height: 12),
                        _SensorRow(
                          icon: Icons.battery_charging_full_rounded,
                          title: 'Battery',
                          subtitle:
                              c.batteryUnrestricted
                                  ? 'Unrestricted, safe from battery cleaners'
                                  : 'Restricted, the system may stop counting',
                          ok: c.batteryUnrestricted,
                        ),
                        if (!c.batteryUnrestricted) ...[
                          SizedBox(height: 14),
                          _ToolButton(
                            label: 'Allow unrestricted battery',
                            onTap: c.requestBatteryUnrestricted,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
              ],

              // Help & FAQ
              FadeSlideIn(
                key: ValueKey('faq-entry'),
                delay: Duration(milliseconds: 20),
                child: GestureDetector(
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const FaqScreen()),
                      ),
                  child: AppCard(
                    color: AppColors.mint,
                    borderColor: AppColors.mint,
                    padding: EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.pine.alp(0.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.quiz_rounded,
                            color: AppColors.pine,
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Help & FAQ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: AppColors.pine,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Answers to common questions about tracking and the widget',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.pine.alp(0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.pine,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Test tools
              /* FadeSlideIn(
                key: ValueKey('tools'),
                delay: Duration(milliseconds: 340),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Test tools', style: AppText.h2),
                      SizedBox(height: 4),
                      Text(
                        'Handy on an emulator where there is no step sensor.',
                        style: AppText.muted,
                      ),
                      SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _ToolButton(
                            label: '+100 steps',
                            onTap: () => c.simulateSteps(100),
                          ),
                          _ToolButton(
                            label: '+1,000 steps',
                            onTap: () => c.simulateSteps(1000),
                          ),
                          _ToolButton(
                            label: '-100 steps',
                            onTap: () => c.simulateSteps(-100),
                          ),
                          _ToolButton(
                            label: '-1,000 steps',
                            onTap: () => c.simulateSteps(-1000),
                          ),
                          SizedBox.shrink(),
                          _ToolButton(
                            label: 'Reset today',
                            onTap: c.resetToday,
                            danger: true,
                          ),
                          if (Platform.isAndroid)
                            _ToolButton(
                              label: 'Refresh home widget now',
                              onTap: () async {
                                final ok = await HomeWidgetService.push(
                                  steps: c.steps,
                                  goal: c.goal,
                                  state:
                                      c.goalReached
                                          ? 'goal'
                                          : c.activityLabel.toLowerCase(),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Widget updated — check your home screen.'
                                            : "No widget found. Long-press your home screen and add FitPulse's widget first.",
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ), */
            ],
          );
        },
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.ember : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(30),
        ),
        child: AnimatedDefaultTextStyle(
          duration: Duration(milliseconds: 300),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13.5,
            color: selected ? AppColors.pine : AppColors.text,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueText,
    required this.child,
  });
  final String label;
  final String valueText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(label, style: AppText.body),
            Spacer(),
            Text(
              valueText,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.sun,
              ),
            ),
          ],
        ),
        child,
      ],
    );
  }
}

class _SensorRow extends StatelessWidget {
  const _SensorRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ok,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.mint : AppColors.sun;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withAlpha((255 * 0.15).round()),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppText.body.copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 2),
              Text(subtitle, style: AppText.muted),
            ],
          ),
        ),
        Icon(
          ok ? Icons.check_circle_rounded : Icons.info_rounded,
          color: color,
          size: 22,
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.label,
    required this.onTap,
    this.danger = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.surfaceHigh,
        foregroundColor: danger ? Color(0xFFFF8A7A) : AppColors.text,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onTap,
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

/// Lets the person opt in to goal-progress notifications and pick which
/// percentages they want alerted about, instead of one fixed always-on
/// notification. Manages its own small bit of local state (the plugin's
/// settings aren't part of FitnessController, since they're independent of
/// the step count itself).
class _NotificationsCard extends StatefulWidget {
  const _NotificationsCard();

  @override
  State<_NotificationsCard> createState() => _NotificationsCardState();
}

class _NotificationsCardState extends State<_NotificationsCard> {
  static const _options = [25, 50, 75, 100, 150];

  @override
  Widget build(BuildContext context) {
    final n = NotificationService.instance;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.mint.alp(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.notifications_rounded,
                  color: AppColors.mint,
                  size: 22,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Goal notifications', style: AppText.h2),
                    SizedBox(height: 2),
                    Text(
                      'A one-off alert when you cross a milestone — not an ongoing notification.',
                      style: AppText.muted,
                    ),
                  ],
                ),
              ),
              Switch(
                value: n.enabled,
                onChanged: (v) async {
                  if (v) await n.requestPermission();
                  await n.setEnabled(v);
                  setState(() {});
                },
                thumbColor: WidgetStatePropertyAll(AppColors.text),
                trackColor: WidgetStateProperty.resolveWith(
                  (s) =>
                      s.contains(WidgetState.selected)
                          ? AppColors.ember
                          : AppColors.surfaceHigh,
                ),
                trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
              ),
            ],
          ),
          if (n.enabled) ...[
            SizedBox(height: 16),
            Text('Notify me at', style: AppText.body),
            SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final pct in _options)
                  _ThresholdChip(
                    label: pct == 100 ? '100% (goal)' : '$pct%',
                    selected: n.thresholds.contains(pct),
                    onTap: () {
                      final next = {...n.thresholds};
                      if (next.contains(pct)) {
                        next.remove(pct);
                      } else {
                        next.add(pct);
                      }
                      n.setThresholds(next);
                      setState(() {});
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ThresholdChip extends StatelessWidget {
  const _ThresholdChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.mint : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13.5,
            color: selected ? AppColors.pine : AppColors.text,
          ),
        ),
      ),
    );
  }
}
