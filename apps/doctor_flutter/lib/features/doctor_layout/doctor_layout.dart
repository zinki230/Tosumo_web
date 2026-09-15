import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_colors.dart';

class DoctorLayout extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const DoctorLayout({super.key, required this.navigationShell});

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 82,
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(12),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _item(LucideIcons.layoutDashboard, 'Accueil', 0),
              _item(LucideIcons.users, 'Patients', 1),
              _center(),
              _item(LucideIcons.calendarDays, 'RDV', 3),
              _item(LucideIcons.userCircle, 'Profil', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(IconData icon, String label, int index) {
    final active = navigationShell.currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: active ? AppColors.primary : AppColors.mutedForeground,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: active ? AppColors.primary : AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _center() {
    final active = navigationShell.currentIndex == 2;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTap(2),
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(90),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(LucideIcons.scan, color: AppColors.white, size: 26),
        ),
      ),
    );
  }
}
