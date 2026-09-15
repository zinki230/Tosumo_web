import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/data/response_mapper.dart';
import '../../../../core/providers/patient_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/localization.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/app_back_button.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  bool _upcomingTab = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(patientProvider.notifier).loadAppointments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;
    final state = ref.watch(patientProvider);
    final all = state.appointments;

    final shown = all.where((a) => _upcomingTab ? a.isUpcoming : !a.isUpcoming).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a.date);
        final db = DateTime.tryParse(b.date);
        final ca = da?.millisecondsSinceEpoch ?? 0;
        final cb = db?.millisecondsSinceEpoch ?? 0;
        return _upcomingTab ? ca.compareTo(cb) : cb.compareTo(ca);
      });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          t?.t('appointments.title') ?? '',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            color: AppColors.white,
            child: Row(
              children: [
                Expanded(
                  child: _tabButton(
                    label: t?.t('appointments.upcoming') ?? '',
                    selected: _upcomingTab,
                    onTap: () => setState(() => _upcomingTab = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _tabButton(
                    label: t?.t('appointments.past') ?? '',
                    selected: !_upcomingTab,
                    onTap: () => setState(() => _upcomingTab = false),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? EmptyState(
                    icon: LucideIcons.calendar,
                    message: t?.t('appointments.empty') ?? '',
                    actionLabel: t?.t('appointments.bookNow') ?? '',
                    onAction: () => context.push('/patient/doctor-search'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: shown.length,
                    itemBuilder: (context, index) =>
                        _AppointmentCard(appointment: shown[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.primaryForeground : AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends ConsumerWidget {
  final Appointment appointment;
  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;
    final date = DateTime.tryParse(appointment.date);
    final dateLabel = date == null
        ? ''
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final timeLabel = appointment.startTime.isNotEmpty ? appointment.startTime : '';
    final statusColor = _statusColor(appointment.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => context.push('/appointment/${appointment.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      date == null ? '--' : date.day.toString().padLeft(2, '0'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                    Text(
                      date == null ? '' : _monthNames(date.month),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.doctorName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appointment.specialty,
                      style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (timeLabel.isNotEmpty) ...[
                          const Icon(LucideIcons.clock, size: 13, color: AppColors.mutedForeground),
                          const SizedBox(width: 4),
                          Text(timeLabel, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                          const SizedBox(width: 12),
                        ],
                        Text(dateLabel, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(t, appointment.status),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }

  String _monthNames(int month) {
    const names = ['', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return names[month];
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'pending':
      return AppColors.warning;
    case 'approved':
      return AppColors.primary;
    case 'confirmed':
      return AppColors.accent;
    case 'rescheduled':
      return const Color(0xFF8B5CF6);
    case 'cancelled':
      return AppColors.destructive;
    case 'completed':
      return const Color(0xFF059669);
    case 'no_show':
      return AppColors.mutedForeground;
    default:
      return AppColors.mutedForeground;
  }
}

String _statusLabel(AppLocalization? t, String status) {
  final key = 'appointments.status.$status';
  final value = t?.t(key) ?? '';
  return value == key ? status : value;
}