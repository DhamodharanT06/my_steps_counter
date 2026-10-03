import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Pushes the current step count to the single, resizable Android
/// home-screen widget (`StepWidgetProvider`, in
/// android/app/src/main/kotlin/.../StepWidgetProvider.kt).
///
/// Important: home_widget stores data under the exact key you pass to
/// [HomeWidget.saveWidgetData] — it does NOT add a "flutter." prefix (that
/// convention belongs to a different plugin, `shared_preferences`, and an
/// earlier version of this file mistakenly read the Android side as if it
/// did). Reading the wrong key silently returns nothing, so the widget kept
/// falling back to its hardcoded defaults — which is exactly why it always
/// showed 0 steps and the placeholder goal. The keys below now match exactly
/// what the Kotlin provider reads.
///
/// RemoteViews (what a native Android widget is made of) can't run a Flutter
/// animation loop — the system redraws it only when [updateWidget] is
/// called. So instead of a continuous animation, the widget shows a state
/// icon (walking / running / resting / goal-reached) that changes as your
/// activity changes.
class HomeWidgetService {
  static const _qualifiedProvider =
      'app.dynamicdragon.mystepcounter.StepWidgetProvider';

  static bool get supported => Platform.isAndroid;

  static Future<bool> push({
    required int steps,
    required int goal,
    required String state, // 'resting' | 'walking' | 'running' | 'goal'
  }) async {
    if (!supported) return false;
    try {
      await HomeWidget.saveWidgetData<int>('steps', steps);
      await HomeWidget.saveWidgetData<int>('goal', goal);
      await HomeWidget.saveWidgetData<String>('state', state);

      final result = await HomeWidget.updateWidget(
        qualifiedAndroidName: _qualifiedProvider,
      );

      if (kDebugMode) {
        debugPrint(
          '[FitPulse] widget push steps=$steps goal=$goal '
          'state=$state result=$result',
        );
      }
      return result ?? false;
    } catch (e) {
      // A pinned-widget lookup failing is normal if no widget has been
      // added to the home screen yet. Anything else is worth seeing.
      if (kDebugMode) debugPrint('[FitPulse] widget push failed: $e');
      return false;
    }
  }
}
