import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../domain/models/dashboard_stats.dart';
import '../../../domain/models/appointment.dart';
import '../../../domain/models/doctor.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/services/error_mapper.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/avatar.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isAvailable = true;

  String? get _doctorId => ref.read(currentDoctorIdProvider);

  Doctor? _doctor;
  DashboardStats? _stats;
  List<Appointment>? _appointments;
  List<Appointment>? _pendingAppointments;

  bool _loadingDoctor = true;
  bool _loadingStats = true;
  bool _loadingAppointments = true;
  bool _loadingPending = true;

  String? _doctorError;
  String? _statsError;
  String? _appointmentsError;
  String? _pendingError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadDoctor(),
      _loadStats(),
      _loadAppointments(),
      _loadPendingAppointments(),
    ]);
  }

  Future<void> _loadDoctor() async {
    final doctorId = _doctorId ?? '';
    setState(() => _loadingDoctor = true);
    try {
      final doctor = await ref.read(doctorRepositoryProvider).getProfile(doctorId)
          .timeout(const Duration(seconds: 15), onTimeout: () => throw Exception('Délai d\'attente dépassé. Vérifiez votre connexion.'));
      if (mounted) setState(() { _doctor = doctor; _isAvailable = doctor.isAvailable; _loadingDoctor = false; _doctorError = null; });
    } catch (e) {
      if (mounted) setState(() { _doctorError = ErrorMapper.fromException(e).message; _loadingDoctor = false; });
    }
  }

  Future<void> _loadStats() async {
    final doctorId = _doctorId ?? '';
    setState(() => _loadingStats = true);
    try {
      final stats = await ref.read(doctorRepositoryProvider).getDashboardStats(doctorId)
          .timeout(const Duration(seconds: 15), onTimeout: () => throw Exception('Délai d\'attente dépassé. Vérifiez votre connexion.'));
      if (mounted) setState(() { _stats = stats; _loadingStats = false; _statsError = null; });
    } catch (e) {
      if (mounted) setState(() { _statsError = ErrorMapper.fromException(e).message; _loadingStats = false; });
    }
  }

  Future<void> _loadAppointments() async {
    final doctorId = _doctorId ?? '';
    setState(() => _loadingAppointments = true);
    try {
      final appointments = await ref.read(doctorRepositoryProvider).getTodayAppointments(doctorId)
          .timeout(const Duration(seconds: 15), onTimeout: () => throw Exception('Délai d\'attente dépassé. Vérifiez votre connexion.'));
      if (mounted) setState(() { _appointments = appointments; _loadingAppointments = false; _appointmentsError = null; });
    } catch (e) {
      if (mounted) setState(() { _appointmentsError = ErrorMapper.fromException(e).message; _loadingAppointments = false; });
    }
  }

  Future<void> _loadPendingAppointments() async {
    final doctorId = _doctorId ?? '';
    setState(() => _loadingPending = true);
    try {
      final pending = await ref.read(appointmentRepositoryProvider).getAppointments(
        doctorId,
        status: 'pending',
      ).timeout(const Duration(seconds: 15), onTimeout: () => throw Exception('Délai d\'attente dépassé. Vérifiez votre connexion.'));
      if (mounted) setState(() { _pendingAppointments = pending; _loadingPending = false; _pendingError = null; });
    } catch (e) {
      if (mounted) setState(() { _pendingError = ErrorMapper.fromException(e).message; _loadingPending = false; });
    }
  }

  Future<void> _refresh() async => _loadData();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAppBar(),
              _loadingStats
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                      child: Row(
                        children: List.generate(3, (_) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Skeleton(height: 88, borderRadius: AppRadius.lg),
                          ),
                        )),
                      ),
                    )
                  : _statsError != null
                      ? const SizedBox.shrink()
                      : _buildStatsRow(_stats!),
              const SizedBox(height: AppSpacing.lg),
              _buildQuickActions(),
              const SizedBox(height: AppSpacing.lg),
              _loadingPending
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: 'Demandes en attente'),
                          const ListSkeleton(count: 2),
                        ],
                      ),
                    )
                  : _pendingError != null
                      ? const SizedBox.shrink()
                      : _buildPendingSection(_pendingAppointments ?? const []),
              const SizedBox(height: AppSpacing.lg),
              _loadingAppointments
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: "Rendez-vous d'aujourd'hui"),
                          const ListSkeleton(count: 3),
                        ],
                      ),
                    )
                  : _appointmentsError != null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SectionHeader(title: "Rendez-vous d'aujourd'hui"),
                              EmptyState(
                                icon: LucideIcons.alertCircle,
                                message: 'Erreur de chargement',
                                actionLabel: 'Réessayer',
                                onAction: _refresh,
                              ),
                            ],
                          ),
                        )
                      : _buildAppointmentsSection(_appointments!),
              const SizedBox(height: AppSpacing.lg),
              _loadingStats
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: 'Prochains rendez-vous'),
                          const ListSkeleton(count: 3),
                        ],
                      ),
                    )
                  : _statsError != null
                      ? const SizedBox.shrink()
                      : _buildUpcomingSection(_stats!),
              const SizedBox(height: AppSpacing.lg),
              _loadingStats
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                      child: const Skeleton(height: 140),
                    )
                  : _statsError != null
                      ? const SizedBox.shrink()
                      : _buildTotalSection(_stats!),
              const SizedBox(height: AppSpacing.lg),
              _buildAvailabilityToggle(),
              const SizedBox(height: AppSpacing.lg),
              _loadingDoctor
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
                      child: const Skeleton(height: 80, borderRadius: AppRadius.lg),
                    )
                  : _doctorError != null
                      ? const SizedBox.shrink()
                      : _buildHospitalInfo(_doctor!),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.pageHorizontal,
        right: AppSpacing.pageHorizontal,
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 8,
      ),
      child: _loadingDoctor
          ? const Row(
              children: [
                Skeleton(width: 48, height: 48, borderRadius: AppRadius.full),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(width: 100, height: 12),
                      SizedBox(height: 4),
                      Skeleton(width: 140, height: 16),
                    ],
                  ),
                ),
              ],
            )
          : _doctorError != null
              ? Row(
                  children: [
                    const Avatar(initials: 'DR', size: 48),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dr.',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.foreground,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Avatar(
                      initials: _getInitials(_doctor!.name),
                      photoUrl: _doctor!.photoUrl,
                      size: 48,
                      online: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonjour,',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          Text(
                            'Dr. ${_doctor!.name}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.bell, size: 24),
                          onPressed: () => context.go('/notifications'),
                          color: AppColors.mutedForeground,
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.destructive,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatsRow(DashboardStats stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
      child: Row(
        children: [
          _StatCard(
            icon: LucideIcons.calendarCheck,
            label: 'Aujourd\'hui',
            value: '${stats.todayAppointments}',
            color: AppColors.primary,
            onTap: () => context.go('/appointments'),
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: LucideIcons.clock,
            label: 'En attente',
            value: '${stats.pendingApprovals}',
            color: AppColors.accent,
            onTap: () => context.go('/appointments', extra: 'pending'),
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: LucideIcons.users,
            label: 'Patients',
            value: '${stats.totalPatients}',
            color: AppColors.success,
            onTap: () => context.go('/patients'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Actions rapides'),
          Row(
            children: [
              _QuickActionButton(
                icon: LucideIcons.qrCode,
                label: 'Scanner QR',
                color: AppColors.primary,
                onTap: () => context.go('/scan'),
              ),
              const SizedBox(width: 12),
              _QuickActionButton(
                icon: LucideIcons.fileText,
                label: 'Consultation',
                color: AppColors.success,
                onTap: () => context.go('/consultations'),
              ),
              const SizedBox(width: 12),
              _QuickActionButton(
                icon: LucideIcons.messageSquare,
                label: 'Messages',
                color: AppColors.accent,
                onTap: () => context.go('/chat'),
              ),
              const SizedBox(width: 12),
              _QuickActionButton(
                icon: LucideIcons.ambulance,
                label: 'Urgence',
                color: AppColors.destructive,
                onTap: () => context.go('/emergency'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSection(List<Appointment> pending) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Demandes en attente',
            actionLabel: pending.isEmpty ? null : 'Voir tout',
            onAction: pending.isEmpty ? null : () => context.go('/appointments', extra: 'pending'),
          ),
          if (pending.isEmpty)
            const EmptyState(
              icon: LucideIcons.inbox,
              message: 'Aucune demande d\'approbation',
            )
          else
            Column(
              children: pending.take(3).map((appt) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AppointmentCard(appointment: appt),
              )).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsSection(List<Appointment> appointments) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: "Rendez-vous d'aujourd'hui",
            actionLabel: 'Voir tout',
            onAction: () => context.go('/appointments'),
          ),
          if (appointments.isEmpty)
            const EmptyState(
              icon: LucideIcons.calendarX,
              message: 'Aucun rendez-vous aujourd\'hui',
            )
          else
            Column(
              children: () {
                final sorted = List<Appointment>.from(appointments)
                  ..sort((a, b) => a.timeSlot.compareTo(b.timeSlot));
                return sorted.take(3).map((appt) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AppointmentCard(appointment: appt),
                )).toList();
              }(),
            ),
        ],
      ),
    );
  }

  Widget _buildUpcomingSection(DashboardStats stats) {
    final upcoming = stats.upcomingAppointments;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Prochains rendez-vous',
            actionLabel: 'Voir tout',
            onAction: () => context.go('/appointments'),
          ),
          if (upcoming.isEmpty)
            const EmptyState(
              icon: LucideIcons.calendarClock,
              message: 'Aucun rendez-vous à venir',
            )
          else
            Column(
              children: upcoming.take(3).map((appt) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AppointmentCard(appointment: appt),
              )).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTotalSection(DashboardStats stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Vue d\'ensemble'),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    icon: LucideIcons.calendarDays,
                    label: 'Rendez-vous',
                    value: '${stats.totalAppointments}',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryTile(
                    icon: LucideIcons.users,
                    label: 'Patients',
                    value: '${stats.totalPatients}',
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isAvailable
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.muted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                _isAvailable ? LucideIcons.checkCircle : LucideIcons.xCircle,
                color: _isAvailable ? AppColors.success : AppColors.mutedForeground,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isAvailable ? 'Disponible' : 'Indisponible',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isAvailable
                        ? 'Vous êtes visible pour les patients'
                        : 'Vous n\'apparaissez pas dans les recherches',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isAvailable,
              onChanged: (v) {
                setState(() => _isAvailable = v);
                ref.read(settingsRepositoryProvider).updateAvailability(v);
              },
              activeThumbColor: AppColors.success,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHospitalInfo(Doctor doctor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
      child: AppCard(
        color: AppColors.primary,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(LucideIcons.hospital, color: AppColors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor.hospitalName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    doctor.specialty,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: AppColors.white, size: 20),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'D';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.mutedForeground,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.foreground,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;

  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final isUpcoming = appointment.status == 'confirmed' || appointment.status == 'pending';
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: isUpcoming ? AppColors.primary : AppColors.mutedForeground,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Avatar(
            initials: _getInitials(appointment.patientName),
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.patientName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(LucideIcons.clock, size: 12, color: AppColors.mutedForeground),
                    const SizedBox(width: 4),
                    Text(
                      appointment.timeSlot,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor(appointment.status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        _statusLabel(appointment.status),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _statusColor(appointment.status),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.mutedForeground),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.accent;
      case 'confirmed':
        return AppColors.primary;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.mutedForeground;
      default:
        return AppColors.mutedForeground;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'confirmed':
        return 'Confirmé';
      case 'completed':
        return 'Terminé';
      case 'cancelled':
        return 'Annulé';
      default:
        return status;
    }
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'P';
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
