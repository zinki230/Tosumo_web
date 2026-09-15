import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/localization.dart';

class AppBackButton extends ConsumerWidget {
  final VoidCallback? onPressed;
  final Color? color;

  const AppBackButton({super.key, this.onPressed, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final tooltip = locAsync.asData?.value.t('common.back') ?? 'Back';

    return IconButton(
      tooltip: tooltip,
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