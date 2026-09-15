import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/providers/patient_provider.dart';
import '../../../core/utils/localization.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/doctor_profile.dart';
import '../../../shared/widgets/app_animated_mount.dart';
import '../../../shared/widgets/app_back_button.dart';

class DoctorSearchScreen extends ConsumerStatefulWidget {
  const DoctorSearchScreen({super.key});

  @override
  ConsumerState<DoctorSearchScreen> createState() => _DoctorSearchScreenState();
}

class _DoctorSearchScreenState extends ConsumerState<DoctorSearchScreen> {
  final _searchController = TextEditingController();
  final _specialtyKeys = ['all', 'cardiologist', 'generalist', 'pediatrician', 'gynecologist', 'ophthalmologist', 'dermatologist'];
  String _selectedSpecialtyKey = 'all';
  String _query = '';

  bool _matches(DoctorProfile doctor) {
    if (_selectedSpecialtyKey != 'all' && !_matchesSpecialty(_selectedSpecialtyKey, doctor.specialty)) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return doctor.name.toLowerCase().contains(q) ||
        (doctor.specialty.toLowerCase().contains(q)) ||
        doctor.hospital.toLowerCase().contains(q) ||
        doctor.hospitalLocation.toLowerCase().contains(q);
  }

  bool _matchesSpecialty(String key, String specialty) {
    final s = specialty.toLowerCase();
    switch (key) {
      case 'cardiologist': return s.contains('cardio');
      case 'generalist': return s.contains('génér') || s.contains('general') || s.contains('family') || s.contains('médecine') || s.contains('medecin');
      case 'pediatrician': return s.contains('pédiatr') || s.contains('pediatr') || s.contains('enfant') || s.contains('child');
      case 'gynecologist': return s.contains('gynéco') || s.contains('gyneco');
      case 'ophthalmologist': return s.contains('ophtalmo') || s.contains('ophtha') || s.contains('eye');
      case 'dermatologist': return s.contains('dermat');
      default: return true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;
    final state = ref.watch(patientProvider);
    final allDoctors = state.doctors;
    final doctors = allDoctors.where(_matches).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(t?.t('doctorSearch.title') ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            color: AppColors.white,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: t?.t('doctorSearch.searchPlaceholder') ?? '',
                      prefixIcon: const Icon(LucideIcons.search, size: 20),
                      suffixIcon: Icon(LucideIcons.slidersHorizontal, size: 20, color: AppColors.primary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 44,
            color: AppColors.white,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _specialtyKeys.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final key = _specialtyKeys[index];
                final selected = key == _selectedSpecialtyKey;
                final label = t?.t('doctorSearch.specialties.$key') ?? key;
                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (v) => setState(() => _selectedSpecialtyKey = key),
                  selectedColor: AppColors.primaryLight,
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? AppColors.primary : AppColors.foreground),
                  side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: doctors.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.stethoscope, size: 48, color: AppColors.mutedForeground.withAlpha(77)),
                        const SizedBox(height: 16),
                        Text(t?.t('doctorSearch.noDoctors') ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: doctors.length,
                    itemBuilder: (context, index) {
                      final doctor = doctors[index];
                      return _DoctorCard(doctor: doctor, onTap: () => context.push('/patient/doctor-profile', extra: doctor));
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final DoctorProfile doctor;
  final VoidCallback onTap;
  const _DoctorCard({required this.doctor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedMount(
      animation: 'fadeInUp',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      doctor.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase(),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctor.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(doctor.specialty, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(LucideIcons.hospital, size: 14, color: AppColors.mutedForeground),
                          const SizedBox(width: 4),
                          Expanded(child: Text(doctor.hospital, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.star, size: 14, color: AppColors.gold),
                        const SizedBox(width: 2),
                        Text(doctor.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('(${doctor.reviewCount})', style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.mutedForeground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
