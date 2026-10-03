import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils.dart';

/// Shows the value instantly (no counting animation) and gives it a small
/// "tick" bump every time it changes, so each step is felt as it happens.
class LiveStepNumber extends StatefulWidget {
  const LiveStepNumber({super.key, required this.value, required this.style});
  final int value;
  final TextStyle style;

  @override
  State<LiveStepNumber> createState() => _LiveStepNumberState();
}

class _LiveStepNumberState extends State<LiveStepNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  @override
  void didUpdateWidget(LiveStepNumber old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Transform.scale(
          scale: 1 + 0.07 * math.sin(math.pi * t),
          child: child,
        );
      },
      child: SizedBox(
        width: 190,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(fmtInt(widget.value), style: widget.style),
        ),
      ),
    );
  }
}
