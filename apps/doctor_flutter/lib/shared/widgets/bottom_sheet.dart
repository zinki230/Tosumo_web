import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

class AppBottomSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool dismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      enableDrag: dismissible,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (title != null) ...[
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
              ] else
                const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.all(16),
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }
}
