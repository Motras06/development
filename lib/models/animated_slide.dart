import 'package:flutter/material.dart';

class AnimatedSlide extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Offset offset;
  final Curve curve;

  const AnimatedSlide({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.offset = const Offset(0, 0.2),
    this.curve = Curves.easeOut,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween(begin: offset, end: Offset.zero),
      duration: duration,
      curve: curve,
      builder: (context, offset, child) {
        return Transform.translate(
          offset: Offset(0, 100 * offset.dy),
          child: Opacity(
            opacity: 1 - offset.dy.abs(),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}