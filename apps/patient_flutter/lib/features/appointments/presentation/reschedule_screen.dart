import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/domain/repositories/patient_repository.dart';
import '../../../../core/data/repositories/repository_providers.dart';
import '../../../../core/providers/patient_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/localization.dart';
import '../../../../shared/widgets/app_back_button.dart';

class RescheduleScreen extends ConsumerStatefulWidget {
  final String appointmentId;
  final String doctorId;
  const RescheduleScreen({
    super.key,
    required this.appointmentId,
    required this.doctorId,
  });

  @override
  ConsumerState<RescheduleScreen> createState() => _RescheduleScreenState();
}

class _RescheduleScreenState extends ConsumerState<RescheduleScreen> {
  PatientRepository get _repo => ref.read(patientRepositoryProvider);

  DateTime? _selectedDate;
  String? _selectedSlot;
  List<Map<String, dynamic>> _slots = [];
  bool _loadingSlots = false;
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          t?.t('appointments.rescheduleTitle') ?? '',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t?.t('appointments.chooseDate') ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(LucideIcons.calendar, size: 18),
                label: Text(
                  _selectedDate == null
                      ? (t?.t('appointments.selectDate') ?? '')
                      : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.destructive)),
            ],
            const SizedBox(height: 20),
            Text(t?.t('appointments.availableTimes') ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Expanded(
              child: _loadingSlots
                  ? const Center(child: CircularProgressIndicator())
                  : _slots.isEmpty
                      ? Center(
                          child: Text(
                            t?.t('appointments.noSlots') ?? '',
                            style: const TextStyle(color: AppColors.mutedForeground),
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 2.2,
                          ),
                          itemCount: _slots.length,
                          itemBuilder: (context, index) {
                            final slot = _slots[index];
                            final start = slot['startTime'] as String? ?? '';
                            final selected = start == _selectedSlot;
                            return InkWell(
                              onTap: () => setState(() => _selectedSlot = start),
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  color: selected ? AppColors.primary : AppColors.card,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected ? AppColors.primary : AppColors.border,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    start,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: selected ? AppColors.primaryForeground : AppColors.foreground,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy || _selectedSlot == null ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(t?.t('appointments.confirmReschedule') ?? ''),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? first,
      firstDate: first,
      lastDate: first.add(const Duration(days: 60)),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _selectedSlot = null;
      _slots = [];
      _error = null;
    });
    await _loadSlots();
  }

  Future<void> _loadSlots() async {
    final date = _selectedDate;
    if (date == null) return;
    setState(() {
      _loadingSlots = true;
      _error = null;
    });
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final slots = await _repo.getAvailableSlots(widget.doctorId, dateStr);
      if (!mounted) return;
      setState(() {
        _slots = slots;
        _loadingSlots = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _slots = [];
        _loadingSlots = false;
        _error = 'Failed to load available slots';
      });
    }
  }

  Future<void> _submit() async {
    final date = _selectedDate;
    final slot = _selectedSlot;
    if (date == null || slot == null) return;
    setState(() => _busy = true);
    final slots = _slots;
    Map<String, dynamic>? current;
    for (final s in slots) {
      if ((s['startTime'] as String?) == slot) {
        current = s;
        break;
      }
    }
    final endTime = current?['endTime'] as String? ?? _computeEndTime(slot);
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      await ref.read(patientProvider.notifier).rescheduleAppointment(
        widget.appointmentId,
        date: dateStr,
        startTime: slot,
        endTime: endTime,
      );
      if (!mounted) return;
      context.pop({'done': true});
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Failed to reschedule';
      });
    }
  }

  String _computeEndTime(String start) {
    final parts = start.split(':');
    if (parts.length != 2) return '30';
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final total = h * 60 + m + 30;
    return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
  }
}