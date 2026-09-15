import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/localization.dart';

class BottomNav extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final VoidCallback onCenterAction;

  const BottomNav({
    super.key,
    required this.navigationShell,
    required this.onCenterAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));

    return locAsync.when(
      data: (loc) => _buildNav(context, loc.t),
      loading: () => _buildNav(context, (key, {params}) => key),
      error: (_, _) => _buildNav(context, (key, {params}) => key),
    );
  }

  Widget _buildNav(BuildContext context, String Function(String, {Map<String, String>? params}) t) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: const [AppShadows.nav],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(0, LucideIcons.home, t('nav.home'), context),
          _navItem(1, LucideIcons.fileText, t('nav.booklet'), context),
          _centerButton(context),
          _navItem(2, LucideIcons.messageCircle, t('nav.chat'), context),
          _navItem(3, LucideIcons.user, t('nav.profile'), context),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, BuildContext context) {
    final isActive = navigationShell.currentIndex == index;

    return GestureDetector(
      onTap: () => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: isActive ? AppColors.primary : AppColors.mutedForeground,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isActive ? AppColors.primary : AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _centerButton(BuildContext context) {
    return GestureDetector(
      onTap: onCenterAction,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: const [AppShadows.soft],
        ),
        child: const Icon(
          LucideIcons.plus,
          color: AppColors.white,
          size: 24,
        ),
      ),
    );
  }
}
