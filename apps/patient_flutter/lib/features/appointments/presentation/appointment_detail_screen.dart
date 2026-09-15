import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/data/response_mapper.dart';
import '../../../../core/services/appointment_service.dart';
import '../../../../core/providers/patient_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/localization.dart';
import '../../../../shared/widgets/app_back_button.dart';

class AppointmentDetailScreen extends ConsumerStatefulWidget {
  final String appointmentId;
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  @override
  ConsumerState<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends ConsumerState<AppointmentDetailScreen> {
  Appointment? _appointment;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final svc = ref.read(appointmentServiceProvider);
      final raw = await svc.getAppointment(widget.appointmentId);
      _appointment = ResponseMapper.appointmentFromBackend(raw);
    } catch (_) {
      _appointment = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      await ref.read(patientProvider.notifier).confirmAppointment(widget.appointmentId);
      await ref.read(patientProvider.notifier).loadAppointments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.t('appointments.confirmed')), backgroundColor: AppColors.accent),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.t('appointments.actionFailed')), backgroundColor: AppColors.destructive),
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _cancel({String? reason}) async {
    setState(() => _busy = true);
    try {
      await ref.read(patientProvider.notifier).cancelAppointment(widget.appointmentId, reason: reason);
      await ref.read(patientProvider.notifier).loadAppointments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.t('appointments.cancelled')), backgroundColor: AppColors.accent),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.t('appointments.actionFailed')), backgroundColor: AppColors.destructive),
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  AppLocalization get _t =>
      ref.read(localizationProvider(ref.read(localeProvider))).asData?.value ??
      AppLocalization(const {}, 'fr');

  Future<void> _confirmCancel() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t.t('appointments.cancelTitle')),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: _t.t('appointments.cancelReasonHint'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t.t('common.cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t.t('common.confirm')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _cancel(reason: reasonController.text);
    }
    reasonController.dispose();
  }

  Future<void> _openReschedule() async {
    if (_appointment == null) return;
    final result = await context.push<Map<String, String>>(
      '/appointment/${widget.appointmentId}/reschedule',
      extra: {'doctorId': _appointment!.doctorId},
    );
    if (result != null) {
      await ref.read(patientProvider.notifier).loadAppointments();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;

    final a = _appointment;
    final date = a == null ? null : DateTime.tryParse(a.date);
    final dateLabel = date == null
        ? ''
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          t?.t('appointments.details') ?? '',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : a == null
              ? const Center(child: Text('Appointment not found'))
              : SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1a2a6c), Color(0xFF2348D4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      date == null ? '--' : date.day.toString(),
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                                    ),
                                    Text(
                                      date == null ? '' : _monthShort(date.month),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.doctorName,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${a.specialty} · $dateLabel',
                                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        _statusLabel(t, a.status),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _infoRow(t, LucideIcons.calendar, t?.t('appointments.date') ?? '', dateLabel),
                        _infoRow(t, LucideIcons.clock, t?.t('appointments.time') ?? '',
                            a.startTime.isNotEmpty ? '${a.startTime} - ${a.endTime}' : ''),
                        _infoRow(t, LucideIcons.hospital, t?.t('appointments.location') ?? '', a.location),
                        _infoRow(t, LucideIcons.stethoscope, t?.t('appointments.type') ?? '', a.specialty),
                        if (a.reason.isNotEmpty)
                          _infoRow(t, LucideIcons.fileText, t?.t('appointments.reason') ?? '', a.reason),
                        const SizedBox(height: 24),
                        if (a.status == 'approved') ...[
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _busy ? null : _confirm,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                              ),
                              child: Text(t?.t('appointments.confirmNow') ?? ''),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (const {'pending', 'approved', 'confirmed', 'rescheduled'}.contains(a.status)) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _busy ? null : _openReschedule,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                              ),
                              child: Text(t?.t('appointments.reschedule') ?? ''),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _busy ? null : _confirmCancel,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.destructive,
                                side: BorderSide(color: AppColors.destructive.withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                              ),
                              child: Text(t?.t('appointments.cancelAppointment') ?? ''),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _infoRow(AppLocalization? t, IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  String _monthShort(int month) {
    const names = ['', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return names[month];
  }
}

String _statusLabel(AppLocalization? t, String status) {
  final key = 'appointments.status.$status';
  final value = t?.t(key) ?? '';
  return value == key ? status : value;
}