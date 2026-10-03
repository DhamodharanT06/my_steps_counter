import 'package:flutter/material.dart';
import '../utils.dart';

/// Animates a number from its previous value to the new one (ease-out).
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    this.decimals = 0,
    this.style,
    this.duration = const Duration(milliseconds: 900),
    this.suffix = '',
  });

  final num value;
  final int decimals;
  final TextStyle? style;
  final Duration duration;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final text = decimals == 0 ? fmtInt(v.round()) : v.toStringAsFixed(decimals);
        return Text('$text$suffix', style: style);
      },
    );
  }
}
