import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/patient_summary.dart';
import '../../../domain/models/prescription.dart';
import '../../../domain/models/medication_item.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/error_mapper.dart';
import '../../../shared/widgets/patient_search_picker.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_button.dart';

class PrescriptionsScreen extends ConsumerStatefulWidget {
  final PatientSummary? initialPatient;

  const PrescriptionsScreen({super.key, this.initialPatient});

  @override
  ConsumerState<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends ConsumerState<PrescriptionsScreen> {
  PatientSummary? _selectedPatient;
  List<_MedicationEntry> _medications = [];
  final _notesController = TextEditingController();
  bool _isRenewed = false;
  bool _isCreating = false;
  bool _isSaving = false;
  bool _loadingPrescriptions = false;
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 30));
  List<Prescription> _prescriptions = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPatient;
    if (initial != null) {
      Future.microtask(() {
        if (mounted) _selectPatient(initial);
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPrescriptions(String patientId) async {
    setState(() => _loadingPrescriptions = true);
    try {
      final prescriptions = await ref.read(prescriptionRepositoryProvider).getPatientPrescriptions(patientId);
      if (mounted) setState(() { _prescriptions = prescriptions; _loadingPrescriptions = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingPrescriptions = false);
    }
  }

  void _addMedication() {
    setState(() {
      _medications.add(_MedicationEntry(
        drugNameController: TextEditingController(),
        dosageController: TextEditingController(),
        frequencyController: TextEditingController(),
        durationController: TextEditingController(),
        routeController: TextEditingController(text: 'oral'),
        instructionsController: TextEditingController(),
        warnings: [],
        interactions: [],
      ));
    });
  }

  void _removeMedication(int index) {
    setState(() {
      _medications[index].dispose();
      _medications.removeAt(index);
    });
  }

  void _selectPatient(PatientSummary patient) {
    setState(() {
      _selectedPatient = patient;
      _isCreating = false;
    });
    _loadPrescriptions(patient.id);
  }

  void _startNewPrescription(PatientSummary patient) {
    setState(() {
      _selectedPatient = patient;
      _isCreating = true;
      _medications = [];
      _notesController.clear();
      _isRenewed = false;
      _expiryDate = DateTime.now().add(const Duration(days: 30));
    });
    _loadPrescriptions(patient.id);
  }

  Future<void> _savePrescription() async {
    if (_selectedPatient == null || _medications.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final medications = _medications.map((m) => MedicationItem(
        drugName: m.drugNameController.text,
        dosage: m.dosageController.text,
        frequency: m.frequencyController.text,
        duration: m.durationController.text,
        route: m.routeController.text,
        instructions: m.instructionsController.text,
        warnings: m.warnings,
        interactions: m.interactions,
      )).toList();

      final prescription = Prescription(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        patientId: _selectedPatient!.id,
        doctorId: ref.read(currentDoctorIdProvider) ?? '',
        consultationId: '',
        medications: medications,
        notes: _notesController.text,
        issueDate: DateTime.now(),
        expiryDate: _expiryDate,
        isRenewed: _isRenewed,
        status: 'active',
        createdAt: DateTime.now(),
      );

      await ref.read(prescriptionRepositoryProvider).createPrescription(prescription);
      if (mounted) {
        setState(() {
          _isCreating = false;
          _selectedPatient = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prescription enregistrée')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMapper.fromException(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCreating && _selectedPatient != null) {
      return _buildPrescriptionForm();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(
              title: 'Prescriptions',
              subtitle: 'Créez et gérez vos prescriptions',
              showBack: false,
              showNotification: true,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
              child: _buildPatientSelector(),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
              child: const SectionHeader(title: 'Prescriptions récentes'),
            ),
            _buildPrescriptionHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientSelector() {
    return PatientSearchPicker(
      onSelected: (patient) => _startNewPrescription(patient),
    );
  }

  Widget _buildPrescriptionHistory() {
    final patientId = _selectedPatient?.id;
    if (patientId == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
        child: EmptyState(
          icon: LucideIcons.pill,
          message: 'Sélectionnez un patient pour voir ses prescriptions',
        ),
      );
    }

    if (_loadingPrescriptions) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
        child: ListSkeleton(count: 3),
      );
    }

    if (_prescriptions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
        child: EmptyState(
          icon: LucideIcons.pill,
          message: 'Aucune prescription pour ce patient',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
      child: Column(
        children: _prescriptions.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.calendar, size: 14, color: AppColors.mutedForeground),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('dd/MM/yyyy').format(p.issueDate),
                      style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: p.status == 'active'
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.muted,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        p.status == 'active' ? 'Actif' : 'Inactif',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: p.status == 'active' ? AppColors.success : AppColors.mutedForeground,
                        ),
                      ),
                    ),
                    if (p.isRenewed) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: const Text(
                          'Renouvelé',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                ...p.medications.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.pill, size: 14, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${m.drugName} - ${m.dosage}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                      Text(
                        '${m.frequency} x ${m.duration}',
                        style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                )),
                if (p.notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    p.notes,
                    style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildPrescriptionForm() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Prescription - ${_selectedPatient!.name}'),
        leading: IconButton(
          icon: const Icon(LucideIcons.x, size: 20),
          onPressed: () => setState(() {
            _isCreating = false;
            _selectedPatient = null;
          }),
          color: AppColors.foreground,
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Renouveler une prescription',
                  style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
                ),
                const Spacer(),
                Switch(
                  value: _isRenewed,
                  onChanged: (v) => setState(() => _isRenewed = v),
                  activeThumbColor: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const SectionHeader(title: 'Médicaments'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addMedication,
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
            if (_medications.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                ),
                child: const Center(
                  child: Text(
                    'Ajoutez au moins un médicament',
                    style: TextStyle(fontSize: 14, color: AppColors.mutedForeground),
                  ),
                ),
              )
            else
              ...List.generate(_medications.length, (index) {
                final med = _medications[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MedicationFormCard(
                    entry: med,
                    index: index + 1,
                    onRemove: () => _removeMedication(index),
                  ),
                );
              }),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Notes'),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Instructions supplémentaires...',
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Durée de validité'),
            Row(
              children: [
                const Icon(LucideIcons.calendar, size: 16, color: AppColors.mutedForeground),
                const SizedBox(width: 8),
                Text(
                  'Expire le: ${DateFormat('dd/MM/yyyy').format(_expiryDate)}',
                  style: const TextStyle(fontSize: 14, color: AppColors.foreground),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _showDatePicker(),
                  child: const Text('Modifier'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Enregistrer brouillon',
                    variant: ButtonVariant.secondary,
                    loading: _isSaving,
                    onPressed: _savePrescription,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Prescrire',
                    loading: _isSaving,
                    onPressed: _savePrescription,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }
}

class _MedicationEntry {
  final TextEditingController drugNameController;
  final TextEditingController dosageController;
  final TextEditingController frequencyController;
  final TextEditingController durationController;
  final TextEditingController routeController;
  final TextEditingController instructionsController;
  List<String> warnings;
  List<String> interactions;

  _MedicationEntry({
    required this.drugNameController,
    required this.dosageController,
    required this.frequencyController,
    required this.durationController,
    required this.routeController,
    required this.instructionsController,
    this.warnings = const [],
    this.interactions = const [],
  });

  void dispose() {
    drugNameController.dispose();
    dosageController.dispose();
    frequencyController.dispose();
    durationController.dispose();
    routeController.dispose();
    instructionsController.dispose();
  }
}

class _MedicationFormCard extends StatelessWidget {
  final _MedicationEntry entry;
  final int index;
  final VoidCallback onRemove;

  const _MedicationFormCard({
    required this.entry,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Médicament',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(LucideIcons.trash, size: 18, color: AppColors.destructive),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: entry.drugNameController,
            decoration: const InputDecoration(
              labelText: 'Nom du médicament',
              hintText: 'Ex: Amoxicilline',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: entry.dosageController,
                  decoration: const InputDecoration(
                    labelText: 'Dosage',
                    hintText: 'Ex: 500mg',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: entry.frequencyController,
                  decoration: const InputDecoration(
                    labelText: 'Fréquence',
                    hintText: 'Ex: 3x/jour',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: entry.durationController,
                  decoration: const InputDecoration(
                    labelText: 'Durée',
                    hintText: 'Ex: 7 jours',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: entry.routeController,
                  decoration: const InputDecoration(
                    labelText: 'Voie',
                    hintText: 'Ex: oral',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: entry.instructionsController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Instructions',
              hintText: 'Instructions supplémentaires...',
            ),
          ),
          if (entry.warnings.isNotEmpty || entry.interactions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.alert.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.alert.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.warnings.isNotEmpty) ...[
                    const Row(
                      children: [
                        Icon(LucideIcons.alertTriangle, size: 14, color: AppColors.alert),
                        SizedBox(width: 6),
                        Text(
                          'Avertissements',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.alert,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...entry.warnings.map((w) => Padding(
                      padding: const EdgeInsets.only(left: 20, top: 2),
                      child: Text(
                        w,
                        style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                      ),
                    )),
                  ],
                  if (entry.interactions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(LucideIcons.pill, size: 14, color: AppColors.alert),
                        SizedBox(width: 6),
                        Text(
                          'Interactions',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.alert,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...entry.interactions.map((i) => Padding(
                      padding: const EdgeInsets.only(left: 20, top: 2),
                      child: Text(
                        i,
                        style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                      ),
                    )),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
