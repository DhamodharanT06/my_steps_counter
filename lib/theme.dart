import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Pine & Ember" (dark) and "Chalk & Ember" (light) — deep forest green /
/// paper white, with ember orange + sun yellow accents. Deliberately no
/// blue or purple in either mode.
///
/// Fields are mutable static values (not `const`) so [AppThemeController]
/// can repaint the whole app instantly when the person switches modes,
/// without every widget needing to look up a theme object.
class AppColors {
  static Color pine = _dark.pine;
  static Color surface = _dark.surface;
  static Color surfaceHigh = _dark.surfaceHigh;
  static Color outline = _dark.outline;
  static Color ember = _dark.ember;
  static Color sun = _dark.sun;
  static Color mint = _dark.mint;
  static Color text = _dark.text;
  static Color muted = _dark.muted;

  static bool isDark = true;

  static void apply(bool dark) {
    final p = dark ? _dark : _light;
    isDark = dark;
    pine = p.pine;
    surface = p.surface;
    surfaceHigh = p.surfaceHigh;
    outline = p.outline;
    ember = p.ember;
    sun = p.sun;
    mint = p.mint;
    text = p.text;
    muted = p.muted;
  }
}

class _Palette {
  const _Palette({
    required this.pine,
    required this.surface,
    required this.surfaceHigh,
    required this.outline,
    required this.ember,
    required this.sun,
    required this.mint,
    required this.text,
    required this.muted,
  });
  final Color pine,
      surface,
      surfaceHigh,
      outline,
      ember,
      sun,
      mint,
      text,
      muted;
}

const _dark = _Palette(
  pine: Color(0xFF0B2019),
  surface: Color(0xFF12332A),
  surfaceHigh: Color(0xFF1B4536),
  outline: Color(0xFF2A5A48),
  ember: Color(0xFFFF6B3D),
  sun: Color(0xFFFFC93C),
  mint: Color(0xFF7CE3B0),
  text: Color(0xFFF1F5E9),
  muted: Color(0xFF8FB0A0),
);

// Light mode: true white/black-ink background, same ember/sun/mint accents
// so the brand still reads as the same app.
const _light = _Palette(
  pine: Color(0xFFFFFFFF), // page background (name kept for drop-in compat)
  surface: Color(0xFFFFFFFF), // cards
  surfaceHigh: Color(0xFFEFEDE6), // tracks, chips
  outline: Color(0xFFDDD8CC),
  ember: Color(0xFFE85A2A),
  sun: Color(0xFFE0A400),
  mint: Color(0xFF1E9E64),
  text: Color(0xFF14100B), // near-black ink
  muted: Color(0xFF6B6459),
);

extension ColorAlpha on Color {
  /// Opacity helper that avoids deprecated `withOpacity`.
  Color alp(double opacity) =>
      withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
}

/// Text styles are getters (not `const`) so they always pick up the
/// current [AppColors.text] / [AppColors.muted] on every rebuild.
class AppText {
  static TextStyle get display => const TextStyle(
    fontSize: 56,
    height: 1.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -2,
  ).copyWith(color: AppColors.text);
  static TextStyle get h1 => const TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
  ).copyWith(color: AppColors.text);
  static TextStyle get h2 => const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
  ).copyWith(color: AppColors.text);
  static TextStyle get value => const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  ).copyWith(color: AppColors.text);
  static TextStyle get body => const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
  ).copyWith(color: AppColors.text);
  static TextStyle get muted => const TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
  ).copyWith(color: AppColors.muted);
  static TextStyle get small => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
  ).copyWith(color: AppColors.muted);
}

/// Persists and broadcasts the light/dark choice. Call [AppThemeController.
/// instance.init] once at startup, then wrap the app in a [ListenableBuilder]
/// listening to it so every screen repaints when [toggle] runs.
class AppThemeController extends ChangeNotifier {
  AppThemeController._();
  static final AppThemeController instance = AppThemeController._();

  static const _kKey = 'darkMode';
  bool _dark = true;
  bool get isDark => _dark;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _dark = prefs.getBool(_kKey) ?? true;
    AppColors.apply(_dark);
  }

  Future<void> setDark(bool value) async {
    _dark = value;
    AppColors.apply(value);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKey, value);
  }
}

ThemeData buildTheme() {
  final dark = AppColors.isDark;
  final scheme =
      dark
          ? const ColorScheme.dark(
            primary: _Colors.emberDark,
            onPrimary: _Colors.pineDark,
            secondary: _Colors.sunDark,
            onSecondary: _Colors.pineDark,
            surface: _Colors.surfaceDark,
            onSurface: _Colors.textDark,
            error: Color(0xFFFF6B5E),
          )
          : const ColorScheme.light(
            primary: _Colors.emberLight,
            onPrimary: Colors.white,
            secondary: _Colors.sunLight,
            onSecondary: Colors.black,
            surface: _Colors.surfaceLight,
            onSurface: _Colors.textLight,
            error: Color(0xFFC62828),
          );

  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.pine,
    textTheme: (dark ? ThemeData.dark() : ThemeData.light()).textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    splashFactory: InkRipple.splashFactory,
    sliderTheme: SliderThemeData(
      trackHeight: 8,
      activeTrackColor: AppColors.ember,
      inactiveTrackColor: AppColors.surfaceHigh,
      thumbColor: AppColors.sun,
      overlayColor: AppColors.sun.withAlpha((255 * 0.18).round()),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
      trackShape: const RoundedRectSliderTrackShape(),
    ),
  );
}

// Compile-time constants purely so ColorScheme (which requires const in
// some call shapes) has fixed values independent of the mutable AppColors.
class _Colors {
  static const pineDark = Color(0xFF0B2019);
  static const surfaceDark = Color(0xFF12332A);
  static const textDark = Color(0xFFF1F5E9);
  static const emberDark = Color(0xFFFF6B3D);
  static const sunDark = Color(0xFFFFC93C);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const textLight = Color(0xFF14100B);
  static const emberLight = Color(0xFFE85A2A);
  static const sunLight = Color(0xFFE0A400);
}
