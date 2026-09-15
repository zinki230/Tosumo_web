import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/error_mapper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/appointment.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_button.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  final String? initialTab;

  const AppointmentsScreen({super.key, this.initialTab});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Tous', 'En attente', 'Confirmés', 'Terminés', 'Annulés'];

  String? get _doctorId => ref.read(currentDoctorIdProvider);

  List<Appointment>? _appointments;
  bool _loadingAppointments = true;
  String? _appointmentsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    final initialIndex = _tabs.indexOf(widget.initialTab ?? '');
    if (initialIndex > 0) _tabController.index = initialIndex;
    _loadAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    final doctorId = _doctorId ?? '';
    setState(() => _loadingAppointments = true);
    try {
      final appts = await ref.read(appointmentRepositoryProvider).getAppointments(
        doctorId,
        page: 1,
        limit: 50,
      );
      if (mounted) setState(() { _appointments = appts; _loadingAppointments = false; _appointmentsError = null; });
    } catch (e) {
      final failure = ErrorMapper.fromException(e);
      if (mounted) setState(() { _appointmentsError = failure.message; _loadingAppointments = false; });
    }
  }

  Future<void> _refresh() async => _loadAppointments();

  String? _statusForTab(int index) {
    switch (index) {
      case 0: return null;
      case 1: return 'pending';
      case 2: return 'confirmed';
      case 3: return 'completed';
      case 4: return 'cancelled';
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: PageHeader(
              title: 'Rendez-vous',
              subtitle: 'Gérez vos rendez-vous',
              showBack: false,
              showNotification: true,
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.mutedForeground,
                tabs: _tabs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final t = entry.value;
                  final status = _statusForTab(index);
                  final filtered = _appointments == null
                      ? <Appointment>[]
                      : status == null
                          ? _appointments!
                          : _appointments!.where((a) => a.status == status).toList();
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t),
                        if (filtered.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              '${filtered.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
              color: AppColors.background,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: List.generate(_tabs.length, (index) {
            final status = _statusForTab(index);
            return _buildAppointmentList(status);
          }),
        ),
      ),
    );
  }

  Widget _buildAppointmentList(String? statusFilter) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      child: _loadingAppointments
          ? const ListSkeleton(count: 5)
          : _appointmentsError != null
              ? ListView(
                  children: [
                    const SizedBox(height: 80),
                    EmptyState(
                      icon: LucideIcons.alertCircle,
                      message: 'Erreur de chargement',
                      actionLabel: 'Réessayer',
                      onAction: _refresh,
                    ),
                  ],
                )
              : _buildListContent(statusFilter),
    );
  }

  Widget _buildListContent(String? statusFilter) {
    final filtered = statusFilter == null
        ? _appointments!
        : _appointments!.where((a) => a.status == statusFilter).toList();
    final sorted = List<Appointment>.from(filtered)
      ..sort((a, b) => a.date.compareTo(b.date));
    if (sorted.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          EmptyState(
            icon: LucideIcons.calendarX,
            message: 'Aucun rendez-vous',
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final appointment = sorted[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _AppointmentDetailCard(
            appointment: appointment,
            onRefresh: _refresh,
          ),
        );
      },
    );
  }
}

class _AppointmentDetailCard extends ConsumerStatefulWidget {
  final Appointment appointment;
  final VoidCallback onRefresh;

  const _AppointmentDetailCard({
    required this.appointment,
    required this.onRefresh,
  });

  @override
  ConsumerState<_AppointmentDetailCard> createState() => _AppointmentDetailCardState();
}

class _AppointmentDetailCardState extends ConsumerState<_AppointmentDetailCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _statusColor(a.status),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.patientName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(LucideIcons.clock, size: 12, color: AppColors.mutedForeground),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${DateFormat('dd/MM').format(a.date)} - ${a.timeSlot}',
                              style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(LucideIcons.tag, size: 12, color: AppColors.mutedForeground),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              a.type,
                              style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(a.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    _statusLabel(a.status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _statusColor(a.status),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 18,
                  color: AppColors.mutedForeground,
                ),
              ],
            ),
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            if (a.reason.isNotEmpty) ...[
              _DetailRow(label: 'Motif', value: a.reason),
              const SizedBox(height: 8),
            ],
            if (a.notes.isNotEmpty) ...[
              _DetailRow(label: 'Notes', value: a.notes),
              const SizedBox(height: 8),
            ],
            _DetailRow(
              label: 'Urgent',
              value: a.isUrgent ? 'Oui' : 'Non',
              valueColor: a.isUrgent ? AppColors.destructive : null,
            ),
            const SizedBox(height: 12),
            _buildActionButtons(a),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(Appointment a) {
    switch (a.status) {
      case 'pending':
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await ref.read(appointmentRepositoryProvider).approveAppointment(a.id);
                        } catch (_) {}
                        widget.onRefresh();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Approuver', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton(
                      onPressed: () async {
                        try {
                          await ref.read(appointmentRepositoryProvider).rejectAppointment(a.id);
                        } catch (_) {}
                        widget.onRefresh();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.destructive,
                        side: const BorderSide(color: AppColors.destructive),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Refuser', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton(
                      onPressed: () => _showRescheduleDialog(a),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Reporter', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton(
                onPressed: () async {
                  try {
                    await ref.read(appointmentRepositoryProvider).markNoShow(a.id);
                  } catch (_) {}
                  widget.onRefresh();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.mutedForeground,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: const Text('Marquer absent', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        );
      case 'confirmed':
      case 'approved':
      case 'rescheduled':
        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await ref.read(appointmentRepositoryProvider).completeAppointment(a.id);
                    } catch (_) {}
                    widget.onRefresh();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Terminer', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 36,
                child: OutlinedButton(
                  onPressed: () async {
                    try {
                      await ref.read(appointmentRepositoryProvider).cancelAppointment(a.id);
                    } catch (_) {}
                    widget.onRefresh();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.destructive,
                    side: const BorderSide(color: AppColors.destructive),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Annuler', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 36,
                child: OutlinedButton(
                  onPressed: () => _showRescheduleDialog(a),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Reporter', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ),
            ),
          ],
        );
      case 'completed':
        return SizedBox(
          width: double.infinity,
          height: 36,
          child: OutlinedButton(
            onPressed: () => _showDetailsSheet(a),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text('Voir les détails', style: TextStyle(fontSize: 12)),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _showDetailsSheet(Appointment a) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      a.patientName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(a.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      _statusLabel(a.status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _statusColor(a.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailRow(label: 'Date', value: DateFormat('dd/MM/yyyy').format(a.date)),
              const SizedBox(height: 8),
              _DetailRow(label: 'Heure', value: a.timeSlot),
              const SizedBox(height: 8),
              _DetailRow(label: 'Type', value: a.type),
              const SizedBox(height: 8),
              _DetailRow(label: 'Motif', value: a.reason.isEmpty ? '—' : a.reason),
              const SizedBox(height: 8),
              _DetailRow(label: 'Notes', value: a.notes.isEmpty ? '—' : a.notes),
              const SizedBox(height: 8),
              _DetailRow(
                label: 'Urgent',
                value: a.isUrgent ? 'Oui' : 'Non',
                valueColor: a.isUrgent ? AppColors.destructive : null,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Fermer',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRescheduleDialog(Appointment a) async {
    final date = await showDatePicker(
      context: context,
      initialDate: a.date.isAfter(DateTime.now()) ? a.date : DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) => Theme(
        data: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    final formattedTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    try {
      await ref.read(appointmentRepositoryProvider).rescheduleAppointment(
        a.id,
        date,
        formattedTime,
      );
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rendez-vous reprogrammé')),
        );
      }
    } catch (e) {
      final failure = ErrorMapper.fromException(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return AppColors.accent;
      case 'approved':
      case 'confirmed':
      case 'rescheduled': return AppColors.primary;
      case 'completed': return AppColors.success;
      case 'no-show':
      case 'cancelled': return AppColors.mutedForeground;
      default: return AppColors.mutedForeground;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending': return 'En attente';
      case 'approved': return 'Approuvé';
      case 'confirmed': return 'Confirmé';
      case 'rescheduled': return 'Reprogrammé';
      case 'completed': return 'Terminé';
      case 'no-show': return 'Absent';
      case 'cancelled': return 'Annulé';
      default: return status;
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: valueColor ?? AppColors.foreground,
            ),
          ),
        ),
      ],
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color color;

  _TabBarDelegate(this.tabBar, {required this.color});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: color, child: tabBar);
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
