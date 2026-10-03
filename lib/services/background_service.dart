import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pedometer/pedometer.dart';

import '../utils.dart';
import 'home_widget_service.dart';
import 'notification_service.dart';
import 'step_store.dart';

/// Entry point of the background isolate (must be top-level).
@pragma('vm:entry-point')
void stepServiceCallback() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(StepTaskHandler());
}

/// Runs inside the foreground service. It keeps listening to the hardware
/// step counter even when the UI is closed, writes every reading to the
/// shared [StepStore], keeps the home-screen widget live, checks goal
/// notification thresholds, and shows today's steps in the notification.
///
/// This is what makes the widget update on its own while the app is closed —
/// without this, the widget only ever refreshed when the app itself was open
/// and ticking, which is why it looked "stuck" the rest of the time.
class StepTaskHandler extends TaskHandler {
  StreamSubscription<StepCount>? _sub;
  bool _notificationsReady = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      await NotificationService.instance.init();
      _notificationsReady = true;
    } catch (_) {
      // Notifications are a nice-to-have here; counting must not depend on it.
    }
    _sub = Pedometer.stepCountStream.listen(
      _onStep,
      onError: (_) {},
      cancelOnError: false,
    );
    await _refresh();
  }

  Future<void> _onStep(StepCount event) async {
    await StepStore.applyRaw(event.steps);
    await _refresh();
    FlutterForegroundTask.sendDataToMain({'sync': true});
  }

  Future<void> _refresh() async {
    final s = await StepStore.snapshot();
    final pct = s.goal == 0 ? 0 : (s.steps * 100 ~/ s.goal).clamp(0, 999);
    await FlutterForegroundTask.updateService(
      notificationTitle: '${fmtInt(s.steps)} steps today',
      notificationText: '$pct% of your ${fmtInt(s.goal)} step goal',
    );

    // Push the moment a real step lands, not on a timer — this is the part
    // that keeps the widget live while the app is closed.
    await HomeWidgetService.push(
      steps: s.steps,
      goal: s.goal,
      state: s.steps >= s.goal ? 'goal' : 'resting',
    );

    if (_notificationsReady) {
      await NotificationService.instance.checkProgress(
        steps: s.steps,
        goal: s.goal,
        progressPercent: s.goal == 0 ? 0 : s.steps * 100 / s.goal,
      );
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _sub?.cancel();
    _sub = null;
  }
}

/// UI-side helper to configure / start / stop the foreground service.
class BackgroundTracking {
  static bool get supported => Platform.isAndroid;

  static void init() {
    if (!supported) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'fitpulse_steps',
        channelName: 'Step tracking',
        channelDescription:
            'Shows today\'s steps while FitPulse counts in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  static Future<void> _ensureNotificationPermission() async {
    final p = await FlutterForegroundTask.checkNotificationPermission();
    if (p != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  /// Starts the service (call only after motion permission is granted).
  static Future<bool> start() async {
    if (!supported) return false;
    try {
      await _ensureNotificationPermission();
      if (!await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.startService(
          serviceId: 4711,
          notificationTitle: 'FitPulse',
          notificationText: 'Counting your steps',
          callback: stepServiceCallback,
        );
      }
      return await FlutterForegroundTask.isRunningService;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    if (!supported) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }

  static Future<bool> isRunning() async {
    if (!supported) return false;
    try {
      return await FlutterForegroundTask.isRunningService;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isBatteryUnrestricted() async {
    if (!supported) return true;
    try {
      return await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestBatteryUnrestricted() async {
    if (!supported) return;
    try {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    } catch (_) {}
  }
}
