import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class PageHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final bool showBack;
  final bool showNotification;
  final Widget? rightAction;

  const PageHeader({
    super.key,
    this.title,
    this.subtitle,
    this.showBack = true,
    this.showNotification = false,
    this.rightAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.pageHorizontal,
        right: AppSpacing.pageHorizontal,
        top: AppSpacing.pageTop,
        bottom: 16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBack)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: IconButton(
                icon: const Icon(LucideIcons.arrowLeft, size: 20),
                onPressed: () => context.pop(),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.foreground,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(36, 36),
                ),
              ),
            ),
          if (showBack) const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                      height: 1.2,
                    ),
                  ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (rightAction != null)
            rightAction!
          else if (showNotification)
            const Stack(
              children: [
                Icon(LucideIcons.bell, size: 24, color: AppColors.mutedForeground),
                Positioned(
                  top: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 4,
                    backgroundColor: AppColors.destructive,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
