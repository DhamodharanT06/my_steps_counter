import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'background_service.dart';
import 'home_widget_service.dart';
import 'notification_service.dart';
import 'step_store.dart';

enum MotionPermission { unknown, granted, denied, permanentlyDenied }

class DayStat {
  const DayStat(this.date, this.steps);
  final DateTime date;
  final int steps;
}

/// UI-side brain of the app.
///
/// Where the step count comes from
///  * Hardware pedometer (used whenever it's available and permission is
///    granted): this is the SAME sensor your phone's own step-counter app
///    reads, so the total tracks it directly — no separate guessing on top.
///    Readings are written to [StepStore] (also done by the background
///    service so counting continues while the app is closed) and this
///    controller just mirrors whatever is on disk.
///  * Accelerometer fallback (only when there is no hardware pedometer, e.g.
///    an emulator, or permission was denied): steps are estimated from a
///    rhythm detector, since there is no better source available.
///
/// The accelerometer is always running, but while the hardware pedometer is
/// active its step-like "pulses" only feed the cadence/activity-state
/// display (the walking/running/resting icon and the motion bars) — they
/// never get added to the count on top of the pedometer. Two sources voting
/// on one number is exactly what caused the app's total to drift away from
/// the phone's own counter and from the home-screen widget.
class FitnessController extends ChangeNotifier {
  late SharedPreferences _prefs;
  bool ready = false;
  bool _disposed = false;

  // Profile
  int goal = 8000;
  double weightKg = 70;
  double heightCm = 170;

  // Background service
  bool backgroundEnabled = true;
  bool serviceRunning = false;
  bool batteryUnrestricted = true;

  // Steps
  int _stored = 0; // mirror of the persistent store (hardware-confirmed)
  int _unsaved = 0; // fallback-mode steps counted locally, not flushed yet
  bool _flushing = false;
  final Map<String, int> _history = {};
  String _dateKey = StepStore.keyFor(DateTime.now());
  int activeSeconds = 0;

  // Sensors
  MotionPermission permission = MotionPermission.unknown;
  bool usingFallback = false;
  String pedestrianStatus = 'unknown';
  int cadence = 0; // steps per minute
  final ValueNotifier<double> motion = ValueNotifier<double>(0);

  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<PedestrianStatus>? _statusSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  Timer? _ticker;
  Timer? _saveTimer;
  bool _pedometerStarted = false;
  final List<DateTime> _stepTimes = []; // for cadence only, not the count

  // Accelerometer detector state
  double _gx = 0, _gy = 0, _gz = 0;
  bool _hasGravity = false;
  DateTime? _lastEvent;
  double _smooth = 0;
  double _f = 0, _f1 = 0, _f2 = 0;
  DateTime _lastPeak = DateTime.fromMillisecondsSinceEpoch(0);
  int _lastInterval = 0;
  int _seq = 0;
  DateTime _lastMotionPush = DateTime.fromMillisecondsSinceEpoch(0);

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  /// Today's step count. This is the one number shown everywhere (ring,
  /// widget, history) — there is no separate "live" vs "confirmed" value
  /// anymore, so the app, the widget and the phone's own counter all read
  /// from the same underlying total.
  int get steps => _stored + _unsaved;

  bool get _hardwareActive =>
      permission == MotionPermission.granted &&
      _pedometerStarted &&
      !usingFallback;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _prefs.reload();
    final (loadedGoal, loadedWeight, loadedHeight) = await StepStore.loadProfile();
    goal = loadedGoal;
    weightKg = loadedWeight;
    heightCm = loadedHeight;
    backgroundEnabled = _prefs.getBool(StepStore.kBackground) ?? true;

    await _syncFromStore();
    if (_prefs.getString(StepStore.kDate) == _dateKey) {
      activeSeconds = _prefs.getInt(StepStore.kActive) ?? 0;
    }

    ready = true;
    notifyListeners();

    if (BackgroundTracking.supported) {
      FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), _tick);
    await requestPermission();
    _pushWidget();
  }

  void _onTaskData(Object data) {
    // The background service credited steps: refresh from the shared store.
    _syncFromStore().then((_) {
      notifyListeners();
      _pushWidget();
    });
  }

  Future<void> onResume() async {
    if (!ready) return;
    _rolloverIfNeeded();
    await _syncFromStore();
    if (permission != MotionPermission.granted) {
      final status = await _permissionType.status;
      if (status.isGranted) await requestPermission();
    } else {
      await _maybeStartService();
    }
    await _refreshBackgroundStatus();
    notifyListeners();
    _pushWidget();
  }

  Future<void> flush() => _flushAll();

  @override
  void dispose() {
    _disposed = true;
    if (BackgroundTracking.supported) {
      FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    }
    _stepSub?.cancel();
    _statusSub?.cancel();
    _accelSub?.cancel();
    _ticker?.cancel();
    _saveTimer?.cancel();
    motion.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Permission + sensors
  // ---------------------------------------------------------------------------

  Permission get _permissionType =>
      Platform.isIOS ? Permission.sensors : Permission.activityRecognition;

  bool _requesting = false;

  Future<void> requestPermission() async {
    if (_requesting) return;
    _requesting = true;
    try {
      await _requestPermissionImpl();
    } finally {
      _requesting = false;
    }
  }

  Future<void> _requestPermissionImpl() async {
    var status = await _permissionType.status;
    if (!status.isGranted) status = await _permissionType.request();

    if (status.isGranted) {
      permission = MotionPermission.granted;
    } else if (status.isPermanentlyDenied) {
      permission = MotionPermission.permanentlyDenied;
    } else {
      permission = MotionPermission.denied;
    }

    _startAccelerometer();
    if (permission == MotionPermission.granted) {
      _startPedometer();
      await _maybeStartService();
    } else {
      usingFallback = true;
    }
    await _refreshBackgroundStatus();
    notifyListeners();
  }

  Future<void> openSettings() => openAppSettings();

  void _startPedometer() {
    if (_pedometerStarted) return;
    _pedometerStarted = true;
    usingFallback = false;

    _stepSub = Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: (_) {
        usingFallback = true; // no hardware counter -> use accelerometer
        notifyListeners();
      },
      cancelOnError: false,
    );
    _statusSub = Pedometer.pedestrianStatusStream.listen(
      (e) {
        pedestrianStatus = e.status;
        notifyListeners();
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> _onStepCount(StepCount event) async {
    if (usingFallback) usingFallback = false;
    await StepStore.applyRaw(event.steps); // no-op if the service did it first
    await _syncFromStore();
    notifyListeners();
    _pushWidget(); // push the moment the real count changes, not just on a timer
  }

  // ---------------------------------------------------------------------------
  // Background service
  // ---------------------------------------------------------------------------

  Future<void> _maybeStartService() async {
    if (!BackgroundTracking.supported) return;
    if (backgroundEnabled && permission == MotionPermission.granted) {
      await BackgroundTracking.start();
    }
  }

  Future<void> _refreshBackgroundStatus() async {
    serviceRunning = await BackgroundTracking.isRunning();
    batteryUnrestricted = await BackgroundTracking.isBatteryUnrestricted();
  }

  Future<void> setBackgroundEnabled(bool value) async {
    backgroundEnabled = value;
    await _prefs.setBool(StepStore.kBackground, value);
    if (value) {
      await _maybeStartService();
    } else {
      await BackgroundTracking.stop();
    }
    await _refreshBackgroundStatus();
    notifyListeners();
  }

  Future<void> requestBatteryUnrestricted() async {
    await BackgroundTracking.requestBatteryUnrestricted();
    await _refreshBackgroundStatus();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Accelerometer: live motion + cadence/activity-state, and fallback steps
  // ---------------------------------------------------------------------------

  void _startAccelerometer() {
    if (_accelSub != null) return;
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_onAccel, onError: (_) {}, cancelOnError: false);
  }

  void _onAccel(AccelerometerEvent e) {
    final now = DateTime.now();
    final last = _lastEvent;
    final dt = last == null
        ? 0.02
        : (now.difference(last).inMicroseconds / 1e6)
            .clamp(0.001, 0.2)
            .toDouble();
    _lastEvent = now;

    if (!_hasGravity) {
      _gx = e.x;
      _gy = e.y;
      _gz = e.z;
      _hasGravity = true;
    }
    // Track gravity with a slow low-pass (time constant 0.5 s).
    final ag = math.exp(-dt / 0.5);
    _gx = ag * _gx + (1 - ag) * e.x;
    _gy = ag * _gy + (1 - ag) * e.y;
    _gz = ag * _gz + (1 - ag) * e.z;

    final lx = e.x - _gx, ly = e.y - _gy, lz = e.z - _gz;
    final gmag = math.sqrt(_gx * _gx + _gy * _gy + _gz * _gz);
    if (gmag < 1) return;

    // Component along gravity = vertical bounce: swings once per footstep.
    final vertical = (lx * _gx + ly * _gy + lz * _gz) / gmag;
    final dyn = math.sqrt(lx * lx + ly * ly + lz * lz);

    final as = math.exp(-dt / 0.3);
    _smooth = as * _smooth + (1 - as) * dyn;

    _detectStep(vertical, dt, now);

    if (now.difference(_lastMotionPush).inMilliseconds >= 90) {
      _lastMotionPush = now;
      motion.value = ((_smooth - 0.15) / 2.0).clamp(0.0, 1.0).toDouble();
    }
  }

  /// Rhythm detector: peaks must arrive 0.25 - 1.3 s apart with similar
  /// spacing before they count as a step, so fidgeting while sitting is
  /// ignored. While a hardware pedometer is running, detected steps only
  /// drive the cadence/activity-state display (see [_onRhythmDetected]) —
  /// they are never added to the count, since that would double up with the
  /// pedometer and is exactly what made the total drift from the truth.
  static const _needSeq = 4;

  void _detectStep(double vertical, double dt, DateTime now) {
    final af = math.exp(-dt / 0.04);
    _f2 = _f1;
    _f1 = _f;
    _f = af * _f + (1 - af) * vertical;

    final isPeak = _f1 > _f2 && _f1 >= _f && _f1 > 0.9 && _f1 < 12;
    if (!isPeak) return;

    final gap = now.difference(_lastPeak).inMilliseconds;
    if (gap < 250) return;
    _lastPeak = now;

    if (gap > 1300) {
      _seq = 1;
      _lastInterval = 0;
      return;
    }

    final regular = _lastInterval == 0 ||
        (gap - _lastInterval).abs() <= _lastInterval * 0.5;
    _lastInterval = gap;
    if (!regular) {
      _seq = 1;
      return;
    }

    _seq++;
    if (_seq == _needSeq) {
      _onRhythmDetected(_needSeq);
    } else if (_seq > _needSeq) {
      _onRhythmDetected(1);
    }
  }

  void _onRhythmDetected(int n) {
    final now = DateTime.now();
    for (var i = 0; i < n && i < 40; i++) {
      _stepTimes.add(now); // cadence + activity-state only
    }
    if (!_hardwareActive) {
      // No real sensor available — this rhythm guess IS the step count.
      _addSteps(n);
    } else {
      notifyListeners(); // refresh the walking/running icon promptly
    }
  }

  // ---------------------------------------------------------------------------
  // Step bookkeeping
  // ---------------------------------------------------------------------------

  /// Fallback-mode steps only (no hardware pedometer available).
  void _addSteps(int n) {
    _rolloverIfNeeded();
    _unsaved += n;
    _scheduleSave();
    notifyListeners();
    _pushWidget();
  }

  Future<void>? _syncInFlight;

  /// Mirror the shared store. Guarded so overlapping calls (hardware
  /// reading, service ping, resume, tick-driven rollover can all trigger
  /// this) never interleave and undo each other's work.
  Future<void> _syncFromStore() {
    final prior = _syncInFlight ?? Future<void>.value();
    final run = prior.then((_) => _syncFromStoreImpl());
    _syncInFlight = run;
    return run;
  }

  Future<void> _syncFromStoreImpl() async {
    await _prefs.reload();
    final key = StepStore.keyFor(DateTime.now());
    final savedDate = _prefs.getString(StepStore.kDate);
    final stored = savedDate == key ? (_prefs.getInt(StepStore.kSteps) ?? 0) : 0;
    final hist = StepStore.decodeHistory(_prefs.getString(StepStore.kHistory));
    if (kDebugMode) {
      debugPrint('[FitPulse] sync: savedDate=$savedDate today=$key '
          'storedSteps=$stored rawBaseline=${_prefs.getInt(StepStore.kRaw)}');
    }

    if (_dateKey != key) {
      _dateKey = key;
      activeSeconds = 0;
    }
    _stored = stored;
    _history
      ..clear()
      ..addAll(hist);
  }

  bool _rolloverIfNeeded() {
    final key = StepStore.keyFor(DateTime.now());
    if (key == _dateKey) return false;
    _dateKey = key;
    _stored = 0;
    _unsaved = 0;
    activeSeconds = 0;
    _syncFromStore().then((_) {
      notifyListeners();
      _pushWidget();
    });
    return true;
  }

  void _tick(Timer _) {
    var changed = _rolloverIfNeeded();
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(seconds: 15));
    _stepTimes.removeWhere((t) => t.isBefore(cutoff));

    final c = _stepTimes.length * 4;
    if (c != cadence) {
      cadence = c;
      changed = true;
    }
    // A second counts as "active" while cadence is at least 60 steps/min.
    if (cadence >= 60) {
      activeSeconds++;
      if (activeSeconds % 60 == 0) {
        changed = true;
        _scheduleSave();
      }
    }
    // The home-screen widget only needs a refresh every couple of seconds
    // for state-icon changes; real step changes push immediately elsewhere.
    if (now.second % 2 == 0) _pushWidget();
    if (now.second % 3 == 0) {
      NotificationService.instance.checkProgress(
        steps: steps,
        goal: goal,
        progressPercent: goal == 0 ? 0 : steps * 100 / goal,
      );
    }
    if (changed) notifyListeners();
  }

  String _widgetStateName(ActivityStateForWidget s) => switch (s) {
        ActivityStateForWidget.goal => 'goal',
        ActivityStateForWidget.running => 'running',
        ActivityStateForWidget.walking => 'walking',
        ActivityStateForWidget.resting => 'resting',
      };

  void _pushWidget() {
    final s = goalReached
        ? ActivityStateForWidget.goal
        : cadence >= 130
            ? ActivityStateForWidget.running
            : (cadence >= 40 || pedestrianStatus == 'walking')
                ? ActivityStateForWidget.walking
                : ActivityStateForWidget.resting;
    HomeWidgetService.push(steps: steps, goal: goal, state: _widgetStateName(s));
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 1500), _flushAll);
  }

  Future<void> _flushAll() async {
    if (!ready) return;
    await _flushUnsaved();
    await StepStore.saveProfile(goal: goal, weight: weightKg, height: heightCm);
    await _prefs.setInt(StepStore.kActive, activeSeconds);
  }

  Future<void> _flushUnsaved() async {
    final n = _unsaved;
    if (n == 0 || _flushing) return;
    _flushing = true;
    try {
      final total = await StepStore.add(n);
      _stored = total;
      _unsaved -= n;
    } finally {
      _flushing = false;
    }
    if (_unsaved > 0) _scheduleSave();
  }

  // ---------------------------------------------------------------------------
  // Derived metrics
  // ---------------------------------------------------------------------------

  double get progress => goal == 0 ? 0 : (steps / goal).clamp(0.0, 1.0).toDouble();
  bool get goalReached => steps >= goal;
  int get remaining => math.max(0, goal - steps);

  double _strideM() => heightCm * 0.415 / 100; // metres per step
  double distanceFor(int s) => s * _strideM() / 1000; // km
  double caloriesFor(int s) => distanceFor(s) * weightKg * 0.57; // kcal

  double get distanceKm => distanceFor(steps);
  double get calories => caloriesFor(steps);
  int get activeMinutes => activeSeconds ~/ 60;

  /// Average steps/day over the last 7 days, including today so far.
  int get weeklyAverage {
    final days = lastDays(7);
    if (days.isEmpty) return 0;
    final total = days.fold<int>(0, (s, d) => s + d.steps);
    return total ~/ days.length;
  }

  /// Total steps over the last 7 days, including today so far.
  int get weeklyTotal =>
      lastDays(7).fold<int>(0, (s, d) => s + d.steps);

  /// Minutes remaining to reach today's goal, estimated from your current
  /// walking pace. Null when the goal is already met or you're standing
  /// still (there's no pace to estimate from).
  int? get etaMinutesToGoal {
    if (goalReached || cadence <= 0) return null;
    return (remaining / cadence).ceil();
  }

  /// Minutes to walk one kilometre at the current pace. Null while resting.
  double? get paceMinPerKm {
    if (cadence <= 0) return null;
    final kmPerMin = cadence * _strideM() / 1000;
    if (kmPerMin <= 0) return null;
    return 1 / kmPerMin;
  }

  String get activityLabel {
    if (cadence >= 130) return 'Running';
    if (cadence >= 40 || pedestrianStatus == 'walking') return 'Walking';
    return 'Resting';
  }

  int _stepsFor(DateTime d) {
    final key = StepStore.keyFor(d);
    return key == _dateKey ? steps : (_history[key] ?? 0);
  }

  int get streak {
    var d = DateTime.now();
    var s = 0;
    if (_stepsFor(d) < goal) d = DateTime(d.year, d.month, d.day - 1);
    while (s < 365 && _stepsFor(d) >= goal) {
      s++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return s;
  }

  List<DayStat> lastDays(int n) {
    final now = DateTime.now();
    return [
      for (var i = n - 1; i >= 0; i--)
        () {
          final d = DateTime(now.year, now.month, now.day - i);
          return DayStat(d, _stepsFor(d));
        }()
    ];
  }

  // ---------------------------------------------------------------------------
  // Mutations from UI
  // ---------------------------------------------------------------------------

  void setGoal(int value) {
    goal = value;
    _scheduleSave();
    notifyListeners();
    _pushWidget();
  }

  void setWeight(double kg) {
    weightKg = kg;
    _scheduleSave();
    notifyListeners();
  }

  void setHeight(double cm) {
    heightCm = cm;
    _scheduleSave();
    notifyListeners();
  }

  /// For emulators / demos.
  void simulateSteps(int n) => _addSteps(n);

  Future<void> resetToday() async {
    _unsaved = 0;
    _stepTimes.clear();
    activeSeconds = 0;
    await StepStore.resetToday();
    _stored = 0;
    notifyListeners();
    _pushWidget();
  }
}

enum ActivityStateForWidget { resting, walking, running, goal }
