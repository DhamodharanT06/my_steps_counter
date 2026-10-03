import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/services.dart';

import 'main_shell.dart';
import 'services/background_service.dart';
import 'services/fitness_controller.dart';
import 'services/notification_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppThemeController.instance.init();
  await NotificationService.instance.init();
  if (Platform.isAndroid) {
    FlutterForegroundTask.initCommunicationPort();
    BackgroundTracking.init();
  }
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  _applySystemBars();
  runApp(FitPulseApp());
}

/// Re-applied every time the theme toggles (see [FitPulseApp.build]) so the
/// status bar and nav bar icons stay legible in both light and dark mode.
void _applySystemBars() {
  final dark = AppColors.isDark;
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: AppColors.pine,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    ),
  );
}

class FitPulseApp extends StatefulWidget {
  const FitPulseApp({super.key});

  @override
  State<FitPulseApp> createState() => _FitPulseAppState();
}

class _FitPulseAppState extends State<FitPulseApp> with WidgetsBindingObserver {
  final FitnessController _controller = FitnessController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.onResume();
    } else if (state == AppLifecycleState.paused) {
      _controller.flush();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeController.instance,
      builder: (context, _) {
        _applySystemBars();
        return MaterialApp(
          title: 'MySteps',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: ListenableBuilder(
            listenable: _controller,
            builder:
                (context, _) => AnimatedSwitcher(
                  duration: Duration(milliseconds: 600),
                  switchInCurve: Curves.easeOutCubic,
                  child:
                      _controller.ready
                          ? MainShell(
                            key: ValueKey('shell'),
                            controller: _controller,
                          )
                          : _Splash(key: ValueKey('splash')),
                ),
          ),
        );
      },
    );
  }
}

class _Splash extends StatefulWidget {
  const _Splash({super.key});

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pine,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_c.value);
            return Transform.scale(scale: 0.92 + 0.12 * t, child: child);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.ember,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  Icons.directions_run_rounded,
                  size: 46,
                  color: AppColors.pine,
                ),
              ),
              SizedBox(height: 18),
              Text('MySteps', style: AppText.h1),
            ],
          ),
        ),
      ),
    );
  }
}
