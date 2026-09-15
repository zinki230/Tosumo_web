import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:tosumo_doctor/core/theme/app_colors.dart';

void main() {
  test('AppColors primary and destructive are opaque', () {
    expect(AppColors.primary, const Color(0xFF1677D2));
    expect(AppColors.destructive, const Color(0xFFEF4444));
    expect(AppColors.primary.a, greaterThan(0));
    expect(AppColors.background.a, greaterThan(0));
    expect(AppColors.destructive.a, greaterThan(0));
  });

  test('AppColors card and primaryForeground are white', () {
    expect(AppColors.card, equals(const Color(0xFFFFFFFF)));
    expect(AppColors.primaryForeground, equals(const Color(0xFFFFFFFF)));
    expect(AppColors.foreground.a, greaterThan(0));
  });
}
