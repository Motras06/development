import 'package:flutter/material.dart';

class AnimatedScaleScale extends StatelessWidget {
  final double scale;
  final Widget child;
  final Duration duration;

  const AnimatedScaleScale({
    super.key,
    required this.scale,
    required this.child,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: scale,
      duration: duration,
      curve: Curves.easeOutBack,
      child: child,
    );
  }
}