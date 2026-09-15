import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

class AppDialog {
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirmer',
    String cancelText = 'Annuler',
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              cancelText,
              style: const TextStyle(color: AppColors.mutedForeground),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              confirmText,
              style: TextStyle(
                color: destructive ? AppColors.destructive : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> info(
    BuildContext context, {
    required String title,
    required String message,
    String okText = 'OK',
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(okText),
          ),
        ],
      ),
    );
  }
}
