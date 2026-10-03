import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StepSnapshot {
  const StepSnapshot(this.steps, this.goal);
  final int steps;
  final int goal;
}

/// Persistent step ledger shared by the UI isolate and the background
/// service isolate (both read/write the same SharedPreferences file).
///
/// The hardware step counter reports a *cumulative* number. [applyRaw] stores
/// the last reading and credits only the difference, so calling it twice with
/// the same reading (from both isolates) never double counts, and steps taken
/// while the app was closed are credited the next time a reading arrives.
class StepStore {
  // Namespaced so these can never collide with a key some other plugin
  // (or a future feature) happens to also store in the same shared,
  // app-wide SharedPreferences file.
  static const kDate = 'fitpulse.date';
  static const kSteps = 'fitpulse.steps';
  static const kRaw = 'fitpulse.lastRaw';
  static const kHistory = 'fitpulse.history';
  static const kGoal = 'fitpulse.goal'; // legacy, kept for one-time migration
  static const kWeight = 'fitpulse.weight'; // legacy
  static const kHeight = 'fitpulse.height'; // legacy
  static const kProfile = 'fitpulse.profile'; // {goal, weight, height} as one write
  static const kActive = 'fitpulse.active';
  static const kBackground = 'fitpulse.background';
  static const kThresholds = 'fitpulse.notifyThresholds';
  static const kNotifiedToday = 'fitpulse.notifiedToday';
  static const kNotifiedDate = 'fitpulse.notifiedDate';

  static String keyFor(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static Map<String, int> decodeHistory(String? raw) {
    final out = <String, int>{};
    if (raw == null) return out;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map.forEach((k, v) => out[k] = (v as num).toInt());
    } catch (_) {}
    return out;
  }

  // Serialise read-modify-write operations inside one isolate.
  static Future<void> _lock = Future<void>.value();
  static Future<T> _guard<T>(Future<T> Function() fn) {
    final completer = Completer<T>();
    _lock = _lock.then((_) async {
      try {
        completer.complete(await fn());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  static Future<SharedPreferences> _fresh() async {
    final p = await SharedPreferences.getInstance();
    await p.reload(); // pick up writes from the other isolate
    return p;
  }

  /// Steps saved for [key], rolling the stored day forward when needed.
  static Future<int> _todayOf(
    SharedPreferences p,
    Map<String, int> history,
    String key,
  ) async {
    final savedDate = p.getString(kDate);
    var steps = p.getInt(kSteps) ?? 0;
    if (savedDate != key) {
      if (savedDate != null) history[savedDate] = steps;
      steps = 0;
      await p.setInt(kActive, 0);
    }
    return steps;
  }

  static Future<void> _write(
    SharedPreferences p,
    Map<String, int> history,
    String key,
    int steps,
  ) async {
    history[key] = steps;
    if (history.length > 90) {
      final keys = history.keys.toList()..sort();
      for (final k in keys.take(history.length - 90)) {
        history.remove(k);
      }
    }
    await p.setString(kDate, key);
    await p.setInt(kSteps, steps);
    await p.setString(kHistory, jsonEncode(history));
  }

  /// Credits a cumulative hardware reading. Returns the steps newly added.
  static Future<int> applyRaw(int raw) => _guard<int>(() async {
        final p = await _fresh();
        final key = keyFor(DateTime.now());
        final history = decodeHistory(p.getString(kHistory));
        var steps = await _todayOf(p, history, key);

        final last = p.getInt(kRaw);
        var delta = 0;
        if (last != null) {
          // raw < last: the counter restarted (phone reboot).
          delta = raw >= last ? raw - last : raw;
        }
        steps += delta;
        await p.setInt(kRaw, raw);
        await _write(p, history, key, steps);
        return delta;
      });

  /// Adds steps counted by the accelerometer fallback. Returns today's total.
  static Future<int> add(int n) => _guard<int>(() async {
        final p = await _fresh();
        final key = keyFor(DateTime.now());
        final history = decodeHistory(p.getString(kHistory));
        final steps = (await _todayOf(p, history, key)) + n;
        await _write(p, history, key, steps);
        return steps;
      });

  static Future<void> resetToday() => _guard<void>(() async {
        final p = await _fresh();
        final key = keyFor(DateTime.now());
        final history = decodeHistory(p.getString(kHistory));
        await _todayOf(p, history, key);
        await p.setInt(kActive, 0);
        await _write(p, history, key, 0);
      });

  static Future<StepSnapshot> snapshot() async {
    final p = await _fresh();
    final key = keyFor(DateTime.now());
    final steps = p.getString(kDate) == key ? (p.getInt(kSteps) ?? 0) : 0;
    return StepSnapshot(steps, (await _loadProfile(p)).$1);
  }

  /// One read instead of three separate ones. Falls back to the old
  /// individual keys once, for anyone updating from a version that used
  /// them, then never touches those old keys again.
  static Future<(int, double, double)> _loadProfile(SharedPreferences p) async {
    final raw = p.getString(kProfile);
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        return (
          (m['goal'] as num).toInt(),
          (m['weight'] as num).toDouble(),
          (m['height'] as num).toDouble(),
        );
      } catch (_) {}
    }
    // Legacy fallback (pre-consolidation installs).
    return (
      p.getInt(kGoal) ?? 8000,
      p.getDouble(kWeight) ?? 70,
      p.getDouble(kHeight) ?? 170,
    );
  }

  static Future<(int, double, double)> loadProfile() async {
    final p = await _fresh();
    return _loadProfile(p);
  }

  /// Single write for all three profile fields, replacing three separate
  /// SharedPreferences writes (each of which is its own disk flush).
  static Future<void> saveProfile({
    required int goal,
    required double weight,
    required double height,
  }) async {
    final p = await _fresh();
    await p.setString(
      kProfile,
      jsonEncode({'goal': goal, 'weight': weight, 'height': height}),
    );
  }
}
