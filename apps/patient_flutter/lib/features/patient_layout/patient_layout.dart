import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/network/online_status.dart';
import '../../shared/widgets/bottom_nav.dart';

class PatientLayout extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const PatientLayout({super.key, required this.navigationShell});

  @override
  ConsumerState<PatientLayout> createState() => _PatientLayoutState();
}

class _PatientLayoutState extends ConsumerState<PatientLayout> {
  bool _showQuickActions = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(syncStatusProvider.notifier).start();
      }
    });
  }

  void _toggleQuickActions() {
    setState(() => _showQuickActions = !_showQuickActions);
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(syncStatusProvider);
    return PopScope(
      canPop: !_showQuickActions,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showQuickActions) _toggleQuickActions();
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: SafeArea(
        top: false,
        child: BottomNav(
          navigationShell: widget.navigationShell,
          onCenterAction: _toggleQuickActions,
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (syncStatus == SyncStatus.offline)
                SafeArea(
                  bottom: false,
                  child: _OfflineBanner(),
                ),
              Expanded(
                child: widget.navigationShell,
              ),
            ],
          ),
          if (_showQuickActions)
            GestureDetector(
              onTap: _toggleQuickActions,
              child: Container(
                color: Colors.black.withAlpha(128),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 48,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppColors.muted,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Actions rapides',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _quickActionButton(
                              icon: LucideIcons.calendar,
                              label: 'Prendre rendez-vous',
                              color: AppColors.primary,
                              onTap: () {
                                _toggleQuickActions();
                                context.push('/patient/doctor-search');
                              },
                            ),
                            const SizedBox(height: 12),
                            _quickActionButton(
                              icon: LucideIcons.shield,
                              label: 'Voir les demandes d\'accès',
                              color: AppColors.accent,
                              onTap: () {
                                _toggleQuickActions();
                                context.push('/patient/access');
                              },
                            ),
                            const SizedBox(height: 12),
                            _quickActionButton(
                              icon: LucideIcons.alertTriangle,
                              label: 'Signaler une carte perdue',
                              color: AppColors.destructive,
                              onTap: () {
                                _toggleQuickActions();
                                context.push('/patient/card/manage');
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withAlpha(13),
          foregroundColor: color,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 16),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.warning.withAlpha(51),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.wifiOff, size: 14, color: Color(0xFFB45309)),
          SizedBox(width: 8),
          Text(
            'Hors ligne · les données affichées peuvent être mises en cache',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFB45309),
            ),
          ),
        ],
      ),
    );
  }
}
