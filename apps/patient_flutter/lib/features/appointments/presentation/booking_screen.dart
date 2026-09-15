import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/data/repositories/repository_providers.dart';
import '../../../../core/domain/repositories/patient_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/localization.dart';
import '../../../../shared/models/doctor_profile.dart';
import '../../../../shared/widgets/app_back_button.dart';

class BookingScreen extends ConsumerStatefulWidget {
  final DoctorProfile doctor;
  const BookingScreen({super.key, required this.doctor});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  PatientRepository get _repo => ref.read(patientRepositoryProvider);

  DateTime? _selectedDate;
  String? _selectedSlot;
  final TextEditingController _reasonController = TextEditingController();
  List<Map<String, dynamic>> _slots = [];
  bool _loadingSlots = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

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
          t?.t('booking.title') ?? '',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          widget.doctor.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.doctor.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(widget.doctor.specialty, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t?.t('booking.chooseDate') ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(LucideIcons.calendar, size: 18),
                      label: Text(
                        _selectedDate == null
                            ? (t?.t('booking.selectDate') ?? '')
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
                  Text(t?.t('booking.availableTimes') ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (_loadingSlots)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_selectedDate != null && _slots.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          t?.t('booking.noSlots') ?? '',
                          style: const TextStyle(color: AppColors.mutedForeground),
                        ),
                      ),
                    )
                  else if (_slots.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
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
                  const SizedBox(height: 20),
                  Text(t?.t('booking.reason') ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: t?.t('booking.reasonHint') ?? '',
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _selectedSlot == null ? null : _continue,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryForeground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  icon: const Icon(LucideIcons.arrowRight, size: 18),
                  label: Text(t?.t('booking.continue') ?? ''),
                ),
              ),
            ),
          ),
        ],
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
      final slots = await _repo.getAvailableSlots(widget.doctor.id, dateStr);
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

  void _continue() {
    final date = _selectedDate;
    final slot = _selectedSlot;
    if (date == null || slot == null) return;
    String endTime = '';
    for (final s in _slots) {
      if ((s['startTime'] as String?) == slot) {
        endTime = s['endTime'] as String? ?? '';
        break;
      }
    }
    context.push('/patient/payment', extra: {
      'doctorName': widget.doctor.name,
      'specialty': widget.doctor.specialty,
      'location': widget.doctor.hospital,
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'doctorId': widget.doctor.id,
      'startTime': slot,
      'endTime': endTime,
      'reason': _reasonController.text,
    });
  }
}