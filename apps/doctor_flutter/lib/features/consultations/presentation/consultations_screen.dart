import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/consultation.dart';
import '../../../domain/models/patient_summary.dart';
import '../../../domain/models/vital_signs.dart';
import '../../../domain/models/lab_request.dart';
import '../../../domain/models/prescription.dart';
import '../../../domain/models/medication_item.dart';
import '../../../core/services/error_mapper.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/patient_search_picker.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_button.dart';

class ConsultationsScreen extends ConsumerStatefulWidget {
  final PatientSummary? initialPatient;

  const ConsultationsScreen({super.key, this.initialPatient});

  @override
  ConsumerState<ConsultationsScreen> createState() => _ConsultationsScreenState();
}

class _ConsultationsScreenState extends ConsumerState<ConsultationsScreen> {
  PatientSummary? _selectedPatient;
  final _symptomsController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _clinicalNotesController = TextEditingController();
  final _followUpController = TextEditingController();

  final _facilityController = TextEditingController();
  final _chiefComplaintController = TextEditingController();
  final _recommendationsController = TextEditingController();

  final _bpSystolicController = TextEditingController();
  final _bpDiastolicController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _respiratoryRateController = TextEditingController();
  final _oxygenSatController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  String _severity = 'mild';
  String _consultationType = 'Routine';
  bool _isCreating = false;
  bool _isSaving = false;

  List<Consultation> _consultations = [];
  bool _loadingConsultations = true;
  String? _consultationsError;

  List<Map<String, dynamic>> _orderedExams = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPatient != null) {
      _startNewConsultation(widget.initialPatient!);
    } else {
      _loadConsultations();
    }
  }

  @override
  void dispose() {
    _symptomsController.dispose();
    _diagnosisController.dispose();
    _clinicalNotesController.dispose();
    _followUpController.dispose();
    _facilityController.dispose();
    _chiefComplaintController.dispose();
    _recommendationsController.dispose();
    _bpSystolicController.dispose();
    _bpDiastolicController.dispose();
    _heartRateController.dispose();
    _temperatureController.dispose();
    _respiratoryRateController.dispose();
    _oxygenSatController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _loadConsultations() async {
    setState(() => _loadingConsultations = true);
    try {
      final consultations = await ref.read(consultationRepositoryProvider).getMyConsultations()
          .timeout(const Duration(seconds: 15), onTimeout: () => throw Exception('Délai d\'attente dépassé'));
      if (mounted) setState(() { _consultations = consultations; _loadingConsultations = false; _consultationsError = null; });
    } catch (e) {
      final failure = ErrorMapper.fromException(e);
      if (mounted) setState(() { _consultationsError = failure.message; _loadingConsultations = false; });
    }
  }

  void _startNewConsultation(PatientSummary patient) {
    setState(() {
      _selectedPatient = patient;
      _isCreating = true;
      _symptomsController.clear();
      _diagnosisController.clear();
      _clinicalNotesController.clear();
      _followUpController.clear();
      _facilityController.clear();
      _chiefComplaintController.clear();
      _recommendationsController.clear();
      _bpSystolicController.clear();
      _bpDiastolicController.clear();
      _heartRateController.clear();
      _temperatureController.clear();
      _respiratoryRateController.clear();
      _oxygenSatController.clear();
      _weightController.clear();
      _heightController.clear();
      _severity = 'mild';
      _consultationType = 'Routine';
      _orderedExams = [];
    });
  }

  Map<String, dynamic> _buildSignature() {
    final doctor = ref.read(authProvider).doctor;
    if (doctor == null) return {};
    return {
      'doctorName': doctor.name,
      'licenseId': doctor.licenseNumber,
      'hospitalName': doctor.hospitalName,
      'signedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _saveConsultation() async {
    if (_selectedPatient == null) return;
    setState(() => _isSaving = true);
    try {
      final vitals = VitalSigns(
        bloodPressureSystolic: int.tryParse(_bpSystolicController.text) ?? 0,
        bloodPressureDiastolic: int.tryParse(_bpDiastolicController.text) ?? 0,
        heartRate: int.tryParse(_heartRateController.text) ?? 0,
        temperature: double.tryParse(_temperatureController.text) ?? 0,
        respiratoryRate: int.tryParse(_respiratoryRateController.text) ?? 0,
        oxygenSaturation: double.tryParse(_oxygenSatController.text) ?? 0,
        weight: double.tryParse(_weightController.text) ?? 0,
        height: double.tryParse(_heightController.text) ?? 0,
      );

      final signature = _buildSignature();

      final consultation = Consultation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        patientId: _selectedPatient!.id,
        doctorId: ref.read(currentDoctorIdProvider) ?? '',
        appointmentId: '',
        date: DateTime.now(),
        symptoms: _symptomsController.text.isNotEmpty
            ? _symptomsController.text.split(',').map((e) => e.trim()).toList()
            : [],
        diagnosis: _diagnosisController.text,
        clinicalNotes: _clinicalNotesController.text,
        vitals: vitals,
        followUpPlan: _followUpController.text,
        orderedExams: _orderedExams,
        severity: _severity,
        consultationType: _consultationType,
        facility: _facilityController.text,
        chiefComplaint: _chiefComplaintController.text,
        recommendations: _recommendationsController.text,
        signature: signature,
        status: 'finalized',
        signedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await ref.read(consultationRepositoryProvider).createConsultation(consultation)
          .timeout(const Duration(seconds: 15), onTimeout: () => throw Exception('Délai d\'attente dépassé. Vérifiez votre connexion.'));
      if (mounted) {
        setState(() {
          _selectedPatient = null;
          _isCreating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consultation signée et enregistrée')),
        );
        _loadConsultations();
      }
    } catch (e) {
      final failure = ErrorMapper.fromException(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCreating && _selectedPatient != null) {
      return _buildConsultationForm();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const PageHeader(
            title: 'Consultations',
            subtitle: 'Créez et gérez vos consultations',
            showBack: false,
            showNotification: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
            child: _buildPatientSelector(),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildConsultationList(null),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientSelector() {
    return PatientSearchPicker(
      onSelected: (patient) => _startNewConsultation(patient),
    );
  }

  Widget _buildConsultationList(String? statusFilter) {
    return RefreshIndicator(
      onRefresh: () async => _loadConsultations(),
      color: AppColors.primary,
      child: _loadingConsultations
          ? const ListSkeleton(count: 4)
          : _consultationsError != null
              ? ListView(
                  children: [
                    const SizedBox(height: 60),
                    EmptyState(
                      icon: LucideIcons.alertCircle,
                      message: 'Erreur de chargement',
                      actionLabel: 'Réessayer',
                      onAction: () => _loadConsultations(),
                    ),
                  ],
                )
              : _buildConsultationListContent(statusFilter),
    );
  }

  Widget _buildConsultationListContent(String? statusFilter) {
    final filtered = statusFilter == null
        ? _consultations
        : _consultations.where((c) => c.status == statusFilter).toList();
    if (filtered.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 60),
          EmptyState(
            icon: LucideIcons.fileText,
            message: 'Aucune consultation',
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final c = filtered[index];
        return Padding(
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
                      DateFormat('dd/MM/yyyy HH:mm').format(c.date),
                      style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _severityColor(c.severity).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        _severityLabel(c.severity),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _severityColor(c.severity),
                        ),
                      ),
                    ),
                  ],
                ),
                if (c.diagnosis.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    c.diagnosis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.foreground,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (c.symptoms.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: c.symptoms.take(3).map((s) => Chip(
                      label: Text(s, style: const TextStyle(fontSize: 10)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                      backgroundColor: AppColors.muted,
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConsultationForm() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Consultation - ${_selectedPatient!.name}'),
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
            const SectionHeader(title: 'Symptômes'),
            TextField(
              controller: _symptomsController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Décrivez les symptômes (séparés par des virgules)',
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Type de consultation'),
            Wrap(
              spacing: 8,
              children: ['Routine', 'Suivi', 'Urgence'].map((t) {
                final isSelected = _consultationType == t;
                final color = t == 'Urgence' ? AppColors.alert : AppColors.primary;
                return ChoiceChip(
                  label: Text(t),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _consultationType = t),
                  selectedColor: color.withValues(alpha: 0.15),
                  backgroundColor: AppColors.card,
                  labelStyle: TextStyle(
                    color: isSelected ? color : AppColors.foreground,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  side: BorderSide(color: isSelected ? color : AppColors.border),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Établissement'),
            TextField(
              controller: _facilityController,
              decoration: const InputDecoration(
                hintText: 'Hôpital / clinique',
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Motif / Plainte principale'),
            TextField(
              controller: _chiefComplaintController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Raison principale de la consultation',
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Signes vitaux'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _VitalField(
                          label: 'TA Systolique',
                          hint: '120',
                          controller: _bpSystolicController,
                          suffix: 'mmHg',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _VitalField(
                          label: 'TA Diastolique',
                          hint: '80',
                          controller: _bpDiastolicController,
                          suffix: 'mmHg',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _VitalField(
                          label: 'Température',
                          hint: '37.0',
                          controller: _temperatureController,
                          suffix: '°C',
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _VitalField(
                          label: 'Poids',
                          hint: '70',
                          controller: _weightController,
                          suffix: 'kg',
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Diagnostic'),
            TextField(
              controller: _diagnosisController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Entrez le diagnostic',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionHeader(title: 'Examens demandés'),
                TextButton.icon(
                  onPressed: _showAddExamSheet,
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
            if (_orderedExams.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                ),
                child: Text(
                  'Aucun examen demandé. Ajoutez les tests à effectuer par le patient.',
                  style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                ),
              )
            else
              Column(
                children: List.generate(_orderedExams.length, (index) {
                  final exam = _orderedExams[index];
                  final files = (exam['resultFiles'] as List<dynamic>?) ?? <dynamic>[];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                            Expanded(
                              child: Text(
                                exam['name'] as String? ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.foreground,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeExam(index),
                              icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.destructive),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Supprimer',
                            ),
                          ],
                        ),
                        if ((exam['note'] as String? ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            exam['note'] as String,
                            style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                          ),
                        ],
                        const SizedBox(height: 10),
                        if (files.isNotEmpty) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: files.map((f) {
                              final url = f as String;
                              return InkWell(
                                onTap: () => _openUrl(url),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(LucideIcons.fileText, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        _fileName(url),
                                        style: const TextStyle(fontSize: 12, color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isUploading ? null : () => _uploadExamResult(index),
                            icon: _isUploading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(LucideIcons.upload, size: 16),
                            label: Text(files.isEmpty ? 'Joindre un résultat' : 'Ajouter un résultat'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Sévérité'),
            Wrap(
              spacing: 8,
              children: ['mild', 'moderate', 'severe', 'critical'].map((s) {
                final isSelected = _severity == s;
                final color = _severityColor(s);
                return ChoiceChip(
                  label: Text(_severityLabel(s)),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _severity = s),
                  selectedColor: color.withValues(alpha: 0.15),
                  backgroundColor: AppColors.card,
                  labelStyle: TextStyle(
                    color: isSelected ? color : AppColors.foreground,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  side: BorderSide(
                    color: isSelected ? color : AppColors.border,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Plan de suivi'),
            TextField(
              controller: _followUpController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Plan de suivi recommandé',
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Recommandations'),
            TextField(
              controller: _recommendationsController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Conseils et recommandations au patient',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => _showLabRequestSheet(),
                      icon: const Icon(LucideIcons.beaker, size: 18),
                      label: const Text('Analyse labo', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => _showPrescriptionSheet(),
                      icon: const Icon(LucideIcons.pill, size: 18),
                      label: const Text('Prescription', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: const BorderSide(color: AppColors.success),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            AppButton(
              label: 'Enregistrer et signer',
              loading: _isSaving,
              onPressed: _saveConsultation,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showLabRequestSheet() {
    final nameController = TextEditingController();
    final typeController = TextEditingController();
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24, right: 24, top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Demande d\'analyse',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nom du test'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: typeController,
              decoration: const InputDecoration(labelText: 'Type de test'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _submitLabRequest(nameController.text, typeController.text, notesController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Envoyer la demande'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ).whenComplete(() {
      nameController.dispose();
      typeController.dispose();
      notesController.dispose();
    });
  }

  Future<void> _submitLabRequest(String testName, String testType, String notes) async {
    if (_selectedPatient == null) return;
    if (testName.trim().isEmpty) return _toast('Renseignez le nom du test');
    if (mounted) Navigator.pop(context);
    try {
      await ref.read(laboratoryRepositoryProvider).createLabRequest(
        LabRequest(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          patientId: _selectedPatient!.id,
          doctorId: ref.read(currentDoctorIdProvider) ?? '',
          consultationId: '',
          testName: testName.trim(),
          testType: testType.trim().isEmpty ? 'sang' : testType.trim(),
          notes: notes.trim(),
          orderedAt: DateTime.now(),
          signature: _buildSignature(),
          signedAt: DateTime.now(),
        ),
      ).timeout(const Duration(seconds: 15), onTimeout: () => throw Exception('Délai d\'attente dépassé'));
      _toast('Analyse demandée');
    } catch (e) {
      _toast(ErrorMapper.fromException(e).message);
    }
  }

  void _showPrescriptionSheet() {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final frequencyController = TextEditingController();
    final durationController = TextEditingController();
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24, right: 24, top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nouvelle prescription',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Médicament'),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: dosageController,
                    decoration: const InputDecoration(labelText: 'Posologie'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: frequencyController,
                    decoration: const InputDecoration(labelText: 'Fréquence'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: durationController,
                    decoration: const InputDecoration(labelText: 'Durée'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Instructions'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _submitPrescription(nameController.text, dosageController.text, frequencyController.text, durationController.text, notesController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Enregistrer la prescription'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ).whenComplete(() {
      nameController.dispose();
      dosageController.dispose();
      frequencyController.dispose();
      durationController.dispose();
      notesController.dispose();
    });
  }

  Future<void> _submitPrescription(String name, String dosage, String frequency, String duration, String instructions) async {
    if (_selectedPatient == null) return;
    if (name.trim().isEmpty) return _toast('Renseignez le médicament');
    if (mounted) Navigator.pop(context);
    try {
      await ref.read(prescriptionRepositoryProvider).createPrescription(
        Prescription(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          patientId: _selectedPatient!.id,
          doctorId: ref.read(currentDoctorIdProvider) ?? '',
          consultationId: '',
          medications: [
            MedicationItem(
              drugName: name.trim(),
              dosage: dosage.trim().isEmpty ? '1' : dosage.trim(),
              frequency: frequency.trim().isEmpty ? '1x/jour' : frequency.trim(),
              duration: duration.trim().isEmpty ? '7 jours' : duration.trim(),
              instructions: instructions.trim(),
            ),
          ],
          notes: instructions.trim(),
          issueDate: DateTime.now(),
          expiryDate: DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime.now(),
          signature: _buildSignature(),
          signedAt: DateTime.now(),
        ),
      ).timeout(const Duration(seconds: 15), onTimeout: () => throw Exception('Délai d\'attente dépassé'));
      _toast('Prescription enregistrée');
    } catch (e) {
      _toast(ErrorMapper.fromException(e).message);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showAddExamSheet() {
    final nameController = TextEditingController();
    final noteController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('Ajouter un examen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nom de l\'examen'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Note (optionnel)'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return _toast('Renseignez le nom de l\'examen');
                  if (mounted) Navigator.pop(context);
                  setState(() {
                    _orderedExams.add({
                      'name': name,
                      'note': noteController.text.trim(),
                      'resultFiles': <String>[],
                      'uploadedBy': 'doctor',
                    });
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Ajouter l\'examen'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ).whenComplete(() {
      nameController.dispose();
      noteController.dispose();
    });
  }

  void _removeExam(int index) {
    setState(() => _orderedExams.removeAt(index));
  }

  Future<void> _uploadExamResult(int index) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() => _isUploading = true);
    try {
      final url = await ref.read(remoteDoctorRepoProvider).uploadFile(path)
          .timeout(const Duration(seconds: 30), onTimeout: () => throw Exception('Délai d\'attente dépassé'));
      if (url != null && mounted) {
        setState(() {
          final files = List<String>.from(_orderedExams[index]['resultFiles'] as List<dynamic>? ?? <dynamic>[]);
          files.add(url);
          _orderedExams[index]['resultFiles'] = files;
          _orderedExams[index]['uploadedBy'] = 'doctor';
        });
        _toast('Résultat joint');
      } else {
        _toast('Échec du téléversement');
      }
    } catch (e) {
      _toast('Échec du téléversement');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _fileName(String url) {
    final parts = url.split('/');
    return parts.isNotEmpty ? parts.last : url;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _toast(url);
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'mild': return AppColors.success;
      case 'moderate': return AppColors.accent;
      case 'severe': return AppColors.alert;
      case 'critical': return AppColors.destructive;
      default: return AppColors.mutedForeground;
    }
  }

  String _severityLabel(String severity) {
    switch (severity) {
      case 'mild': return 'Léger';
      case 'moderate': return 'Modéré';
      case 'severe': return 'Grave';
      case 'critical': return 'Critique';
      default: return severity;
    }
  }
}

class _VitalField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final String suffix;
  final TextInputType? keyboardType;

  const _VitalField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.suffix,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType ?? TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            suffixStyle: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
