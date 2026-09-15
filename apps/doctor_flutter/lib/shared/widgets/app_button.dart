import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool fullWidth;
  final ButtonVariant variant;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.fullWidth = true,
    this.variant = ButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final style = variant == ButtonVariant.primary
        ? ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.primaryForeground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          )
        : variant == ButtonVariant.secondary
            ? OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              )
            : ElevatedButton.styleFrom(
                backgroundColor: AppColors.destructive,
                foregroundColor: AppColors.destructiveForeground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              );

    if (fullWidth) {
      return SizedBox(
        width: double.infinity,
        child: _buildButton(style),
      );
    }

    return _buildButton(style);
  }

  Widget _buildButton(ButtonStyle style) {
    if (loading) {
      return ElevatedButton(
        onPressed: null,
        style: style,
        child: const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.white,
          ),
        ),
      );
    }

    if (variant == ButtonVariant.secondary) {
      return OutlinedButton(
        onPressed: onPressed,
        style: style,
        child: Text(label),
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: style,
      child: Text(label),
    );
  }
}

enum ButtonVariant { primary, secondary, destructive }
