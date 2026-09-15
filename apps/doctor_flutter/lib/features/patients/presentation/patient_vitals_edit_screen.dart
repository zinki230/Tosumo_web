import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/emergency_contact_info.dart';
import '../../../domain/models/patient_detail.dart';
import '../../../domain/models/patient_vitals_update.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/services/error_mapper.dart';

class PatientVitalsEditScreen extends ConsumerStatefulWidget {
  final PatientDetail patient;

  const PatientVitalsEditScreen({super.key, required this.patient});

  @override
  ConsumerState<PatientVitalsEditScreen> createState() => _PatientVitalsEditScreenState();
}

class _PatientVitalsEditScreenState extends ConsumerState<PatientVitalsEditScreen> {
  final _bloodTypes = const [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  late String? _bloodType;
  final List<String> _allergies = [];
  final List<String> _chronicConditions = [];
  final List<String> _currentMeds = [];
  final _ecName = TextEditingController();
  final _ecRelationship = TextEditingController();
  final _ecPhone = TextEditingController();
  final _allergyController = TextEditingController();
  final _chronicController = TextEditingController();
  final _medsController = TextEditingController();
  bool _signed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.patient;
    _bloodType = p.bloodType.isNotEmpty ? p.bloodType : null;
    _allergies.addAll(p.allergies);
    _chronicConditions.addAll(p.chronicConditions);
    _currentMeds.addAll(p.currentMeds);
    _ecName.text = p.emergencyContact?.name ?? '';
    _ecRelationship.text = p.emergencyContact?.relationship ?? '';
    _ecPhone.text = p.emergencyContact?.phone ?? '';
  }

  @override
  void dispose() {
    _ecName.dispose();
    _ecRelationship.dispose();
    _ecPhone.dispose();
    _allergyController.dispose();
    _chronicController.dispose();
    _medsController.dispose();
    super.dispose();
  }

  void _addChip(List<String> list, TextEditingController controller, StateSetter set) {
    final value = controller.text.trim();
    if (value.isNotEmpty && !list.contains(value)) {
      set(() => list.add(value));
      controller.clear();
    }
  }

  Future<void> _save() async {
    final doctor = ref.read(authProvider).doctor;
    final update = PatientVitalsUpdate(
      bloodType: _bloodType,
      allergies: _allergies,
      chronicConditions: _chronicConditions,
      currentMeds: _currentMeds,
      emergencyContact: EmergencyContactInfo(
        name: _ecName.text.trim(),
        relationship: _ecRelationship.text.trim(),
        phone: _ecPhone.text.trim(),
      ),
      signedByDoctorId: doctor?.id ?? ref.read(currentDoctorIdProvider),
      signedByDoctorName: doctor?.name ?? '',
      signed: _signed,
    );
    setState(() => _saving = true);
    try {
      final updated = await ref
          .read(patientRepositoryProvider)
          .updatePatientVitals(widget.patient.id, update)
          .timeout(const Duration(seconds: 15), onTimeout: () => throw Exception('Délai d\'attente dépassé. Vérifiez votre connexion.'));
      if (!mounted) return;
      final merged = widget.patient.copyWith(
        bloodType: updated.bloodType,
        allergies: updated.allergies,
        chronicConditions: updated.chronicConditions,
        currentMeds: updated.currentMeds,
        emergencyContact: updated.emergencyContact ?? widget.patient.emergencyContact,
        verified: _signed,
      );
      context.pop(merged);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        final failure = ErrorMapper.fromException(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = ref.watch(authProvider).doctor;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Informations vitales'),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saisissez les informations médicales du patient non renseignées lors de l\'inscription. Ces données seront signées par le médecin.',
              style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground, height: 1.4),
            ),
            const SizedBox(height: 24),
            _SectionTitle(label: 'Groupe sanguin'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _bloodType,
              hint: const Text('Sélectionner'),
              items: _bloodTypes
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (v) => setState(() => _bloodType = v),
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 20),
            _ChipField(
              title: 'Allergies',
              controller: _allergyController,
              items: _allergies,
              onAdd: () => setState(() => _addChip(_allergies, _allergyController, setState)),
              onRemove: (i) => setState(() => _allergies.removeAt(i)),
            ),
            const SizedBox(height: 20),
            _ChipField(
              title: 'Conditions chroniques',
              controller: _chronicController,
              items: _chronicConditions,
              onAdd: () => setState(() => _addChip(_chronicConditions, _chronicController, setState)),
              onRemove: (i) => setState(() => _chronicConditions.removeAt(i)),
            ),
            const SizedBox(height: 20),
            _ChipField(
              title: 'Traitements en cours',
              controller: _medsController,
              items: _currentMeds,
              onAdd: () => setState(() => _addChip(_currentMeds, _medsController, setState)),
              onRemove: (i) => setState(() => _currentMeds.removeAt(i)),
            ),
            const SizedBox(height: 20),
            _SectionTitle(label: 'Contact d\'urgence'),
            const SizedBox(height: 8),
            _TextField(controller: _ecName, label: 'Nom', icon: LucideIcons.user),
            const SizedBox(height: 12),
            _TextField(controller: _ecRelationship, label: 'Lien', icon: LucideIcons.users),
            const SizedBox(height: 12),
            _TextField(controller: _ecPhone, label: 'Téléphone', icon: LucideIcons.phone, keyboardType: TextInputType.phone),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.penLine, size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Signature du médecin',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.foreground),
                        ),
                      ),
                      Switch(
                        value: _signed,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) => setState(() => _signed = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _signed
                        ? 'Signé par ${doctor?.name.isNotEmpty == true ? doctor!.name : 'le médecin connecté'}. La carte du patient sera marquée comme vérifiée.'
                        : 'Activez pour signer et vérifier la carte du patient.',
                    style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryForeground,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                ),
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Enregistrer et signer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.xl), borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.xl), borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.xl), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.foreground),
      );
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  const _TextField({required this.controller, required this.label, required this.icon, this.keyboardType});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 16, color: AppColors.foreground),
          filled: true,
          fillColor: AppColors.card,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.xl), borderSide: BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.xl), borderSide: BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.xl), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      );
}

class _ChipField extends StatelessWidget {
  final String title;
  final TextEditingController controller;
  final List<String> items;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  const _ChipField({
    required this.title,
    required this.controller,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(label: title),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onSubmitted: (_) => onAdd(),
                  decoration: InputDecoration(
                    hintText: 'Ajouter…',
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.xl), borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.xl), borderSide: BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.xl), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: onAdd,
                icon: const Icon(LucideIcons.plus, size: 18),
                style: IconButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.primaryForeground),
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: items.asMap().entries.map((e) {
                return Chip(
                  label: Text(e.value, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(LucideIcons.x, size: 14),
                  onDeleted: () => onRemove(e.key),
                  backgroundColor: AppColors.primary.withAlpha(20),
                  side: BorderSide.none,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ],
      );
}
