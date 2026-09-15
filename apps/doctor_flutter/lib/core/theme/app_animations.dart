import 'package:flutter/animation.dart';

class AppAnimations {
  AppAnimations._();

  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration cardFlip = Duration(milliseconds: 600);

  static const Curve defaultCurve = Cubic(0.34, 1.56, 0.64, 1);
}
