import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;

  const AppBackButton({super.key, this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Retour',
      icon: Icon(LucideIcons.arrowLeft, size: 20, color: color ?? AppColors.foreground),
      onPressed: onPressed ??
          () {
            if (context.canPop()) {
              context.pop();
            }
          },
    );
  }
}