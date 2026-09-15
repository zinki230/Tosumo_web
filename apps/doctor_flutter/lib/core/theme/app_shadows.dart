import 'package:flutter/material.dart';

class AppShadows {
  AppShadows._();

  static const soft = BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 20,
    offset: Offset(0, 4),
  );

  static const card = BoxShadow(
    color: Color(0x10000000),
    blurRadius: 16,
    offset: Offset(0, 2),
  );

  static const nav = BoxShadow(
    color: Color(0x10000000),
    blurRadius: 20,
    offset: Offset(0, -2),
  );

  static const elevated = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 32,
    offset: Offset(0, 8),
  );

  static const premium = BoxShadow(
    color: Color(0x263B82F6),
    blurRadius: 40,
    offset: Offset(0, 8),
  );
}
