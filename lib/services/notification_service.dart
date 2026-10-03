import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'step_store.dart';

/// One-time, dismissible progress notifications — separate from the
/// always-on foreground-service notification used for background counting.
///
/// The person picks which percentages of their daily goal they want to hear
/// about (25%, 50%, 100%, ...). Each threshold fires at most once per day,
/// the moment progress crosses it, and never repeats until the next day.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'fitpulse_goal';
  static const defaultThresholds = <int>[50, 100];

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool enabled = true;
  Set<int> thresholds = {...defaultThresholds};

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    const channel = AndroidNotificationChannel(
      _channelId,
      'Goal progress',
      description: 'A one-off alert when you cross a step-goal milestone.',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    _ready = true;

    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool('${StepStore.kThresholds}.enabled') ?? true;
    final raw = prefs.getString(StepStore.kThresholds);
    if (raw != null) {
      try {
        thresholds = (jsonDecode(raw) as List).map((e) => e as int).toSet();
      } catch (_) {}
    }

    // `enabled` defaults to true, but on Android 13+ that means nothing
    // until the OS permission is actually granted — without this call,
    // every notification below was being silently dropped by the system,
    // with no error anywhere, which is exactly why thresholds "never fired".
    if (enabled) await requestPermission();
  }

  Future<bool> requestPermission() async {
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${StepStore.kThresholds}.enabled', value);
  }

  Future<void> setThresholds(Set<int> value) async {
    thresholds = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StepStore.kThresholds, jsonEncode(value.toList()));
  }

  /// Call this whenever progress changes. Fires at most one notification per
  /// threshold per day, only for thresholds the person has turned on, and
  /// only for ones just reached (never re-fires on later ticks).
  Future<void> checkProgress({
    required int steps,
    required int goal,
    required double progressPercent, // 0..100+
  }) async {
    if (!_ready || !enabled || thresholds.isEmpty || goal <= 0) return;

    final prefs = await SharedPreferences.getInstance();
    final today = StepStore.keyFor(DateTime.now());
    final notifiedDate = prefs.getString(StepStore.kNotifiedDate);
    var alreadyFired = <int>{};
    if (notifiedDate == today) {
      final raw = prefs.getStringList(StepStore.kNotifiedToday) ?? const [];
      alreadyFired = raw.map(int.parse).toSet();
    } else {
      // New day: nothing has fired yet.
      await prefs.setString(StepStore.kNotifiedDate, today);
      await prefs.setStringList(StepStore.kNotifiedToday, []);
    }

    final crossed = thresholds
        .where((t) => progressPercent >= t && !alreadyFired.contains(t))
        .toList()
      ..sort();
    if (crossed.isEmpty) return;

    // If several thresholds were crossed in one jump (e.g. a big batch of
    // confirmed steps landed at once), only the highest one is worth telling
    // the person about.
    final t = crossed.last;
    alreadyFired.addAll(crossed);
    await prefs.setStringList(
        StepStore.kNotifiedToday, alreadyFired.map((e) => '$e').toList());

    final title = t >= 100 ? "Goal reached! 🎉" : '$t% of your goal';
    final body = t >= 100
        ? "You've hit ${_fmt(goal)} steps today. Nicely done."
        : "${_fmt(steps)} of ${_fmt(goal)} steps so far.";

    await _plugin.show(
      1000 + t,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Goal progress',
          channelDescription:
              'A one-off alert when you cross a step-goal milestone.',
          importance: Importance.high,
          priority: Priority.high,
          autoCancel: true,
          category: AndroidNotificationCategory.status,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
}
