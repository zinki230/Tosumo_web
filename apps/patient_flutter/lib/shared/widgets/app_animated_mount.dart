import 'package:flutter/material.dart';

class AnimatedMount extends StatefulWidget {
  final Widget child;
  final String animation;
  final int delay;
  final int duration;

  const AnimatedMount({
    super.key,
    required this.child,
    this.animation = 'fadeInUp',
    this.delay = 0,
    this.duration = 400,
  });

  @override
  State<AnimatedMount> createState() => _AnimatedMountState();
}

class _AnimatedMountState extends State<AnimatedMount>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _translate;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.duration),
    );

    final curve = const Cubic(0.34, 1.56, 0.64, 1);

    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    final beginY = widget.animation == 'fadeInUp' ? 12.0 : 0.0;
    _translate = Tween<Offset>(
      begin: Offset(0, beginY),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: curve));

    final beginScale = widget.animation == 'scaleIn' ? 0.8 : 1.0;
    _scale = Tween<double>(begin: beginScale, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: curve),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: _translate.value,
            child: Transform.scale(
              scale: _scale.value,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
