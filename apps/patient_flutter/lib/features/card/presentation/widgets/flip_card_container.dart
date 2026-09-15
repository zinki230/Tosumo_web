import 'package:flutter/material.dart';

class FlipCardContainer extends StatefulWidget {
  final Widget front;
  final Widget back;
  final double aspectRatio;
  final bool initiallyFlipped;
  final ValueNotifier<bool>? flipNotifier;

  const FlipCardContainer({
    super.key,
    required this.front,
    required this.back,
    this.aspectRatio = 1.6,
    this.initiallyFlipped = false,
    this.flipNotifier,
  });

  @override
  State<FlipCardContainer> createState() => _FlipCardContainerState();
}

class _FlipCardContainerState extends State<FlipCardContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotation;
  late Animation<double> _scale;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _isFlipped = widget.initiallyFlipped;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _rotation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));
    if (_isFlipped) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void flip() {
    if (_controller.isAnimating) return;
    if (_isFlipped) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    _isFlipped = !_isFlipped;
    widget.flipNotifier?.value = _isFlipped;
  }

  bool get isFlipped => _isFlipped;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final rotationValue = _rotation.value;
        final isBack = rotationValue > 0.5;
        final scaleValue = _isFlipped
            ? 1.0 - (1.0 - _scale.value)
            : _scale.value;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..setEntry(0, 0, scaleValue)
            ..setEntry(1, 1, scaleValue)
            ..rotateY(rotationValue * 3.14159265),
          child: isBack ? widget.back : widget.front,
        );
      },
    );
  }
}
