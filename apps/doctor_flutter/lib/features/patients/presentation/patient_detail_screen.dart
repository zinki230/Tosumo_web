import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/patient_detail.dart';
import '../../../domain/models/emergency_contact_info.dart';
import '../../../domain/models/consultation.dart';
import '../../../domain/models/patient_summary.dart';
import '../../../domain/models/appointment.dart';
import '../../../domain/models/lab_request.dart';
import '../../../domain/models/imaging_request.dart';
import '../../../domain/models/prescription.dart';
import '../../../features/patients/presentation/record_card.dart';
import '../../../core/data/repositories/repository_providers.dart';
import '../../../core/services/error_mapper.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/app_card.dart';

class PatientDetailScreen extends ConsumerStatefulWidget {
  final String patientId;

  const PatientDetailScreen({super.key, required this.patientId});

  @override
  ConsumerState<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PatientDetail? _patient;
  List<Consultation> _consultations = [];
  List<LabRequest> _labs = [];
  List<ImagingRequest> _imaging = [];
  List<Prescription> _prescriptions = [];
  List<Appointment> _appointments = [];
  bool _loadingPatient = true;
  bool _loadingRecords = true;
  bool _loadingAppointments = true;
  String? _patientError;
  String? _recordsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPatient();
    _loadRecords();
    _loadAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPatient() async {
    setState(() { _loadingPatient = true; _patientError = null; });
    try {
      final patient = await ref.read(patientRepositoryProvider).getPatientById(widget.patientId)
          .timeout(const Duration(seconds: 15), onTimeout: () => throw Exception('Délai d\'attente dépassé. Vérifiez votre connexion.'));
      if (mounted) setState(() { _patient = patient; _loadingPatient = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingPatient = false; _patientError = ErrorMapper.fromException(e).message; });
    }
  }

  Future<void> _loadRecords() async {
    setState(() { _loadingRecords = true; });
    try {
      final results = await Future.wait([
        ref.read(consultationRepositoryProvider).getPatientConsultations(widget.patientId),
        ref.read(laboratoryRepositoryProvider).getPatientLabRequests(widget.patientId),
        ref.read(imagingRepositoryProvider).getPatientImagingRequests(widget.patientId),
        ref.read(prescriptionRepositoryProvider).getPatientPrescriptions(widget.patientId),
      ]).timeout(const Duration(seconds: 15), onTimeout: () => throw Exception('Délai d\'attente dépassé'));
      if (!mounted) return;
      setState(() {
        _consultations = results[0] as List<Consultation>;
        _labs = results[1] as List<LabRequest>;
        _imaging = results[2] as List<ImagingRequest>;
        _prescriptions = results[3] as List<Prescription>;
        _loadingRecords = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loadingRecords = false; _recordsError = ErrorMapper.fromException(e).message; });
    }
  }

  Future<void> _loadAppointments() async {
    setState(() { _loadingAppointments = true; });
    try {
      final all = await ref.read(appointmentRepositoryProvider).getAppointments('', status: null)
          .timeout(const Duration(seconds: 15), onTimeout: () => throw Exception('Délai d\'attente dépassé'));
      final patientAppts = all.where((a) => a.patientId == widget.patientId).toList();
      if (mounted) setState(() { _appointments = patientAppts; _loadingAppointments = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingAppointments = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPatient) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: FullPageLoader(message: 'Chargement du profil...')),
      );
    }
    if (_patientError != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: AppColors.destructive),
                const SizedBox(height: 16),
                const Text('Erreur de chargement', style: TextStyle(fontSize: 16, color: AppColors.mutedForeground)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadPatient,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return _buildContent(_patient!);
  }

  Widget _buildContent(PatientDetail patient) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          backgroundColor: AppColors.background,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: _buildHeader(patient),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.mutedForeground,
            tabs: const [
              Tab(text: 'Infos'),
              Tab(text: 'Dossier'),
              Tab(text: 'Visites'),
            ],
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(patient),
          _buildDossierTab(),
          _buildVisitsTab(patient),
        ],
      ),
    );
  }

  Widget _buildHeader(PatientDetail patient) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.pageHorizontal,
        right: AppSpacing.pageHorizontal,
        top: MediaQuery.of(context).padding.top + 60,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cardBlueStart, AppColors.cardBlueEnd],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Center(
                  child: Text(
                    _getInitials(patient.name),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        patient.nationalId,
                        style: const TextStyle(fontSize: 11, color: AppColors.white),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: patient.verified
                            ? const Color(0xFF10B981).withValues(alpha: 0.25)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            patient.verified ? LucideIcons.badgeCheck : LucideIcons.alertTriangle,
                            size: 11,
                            color: patient.verified
                                ? const Color(0xFF6EE7B7)
                                : const Color(0xFFFCD34D),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            patient.verified ? 'Vérifié' : 'Non-vérifié',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showQrCode(patient),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(LucideIcons.qrCode, color: AppColors.white, size: 22),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _openVitalsEdit(patient),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(LucideIcons.penLine, color: AppColors.white, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab(PatientDetail patient) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPersonalInfo(patient),
          const SizedBox(height: AppSpacing.lg),
          _buildMedicalInfo(patient),
          const SizedBox(height: AppSpacing.lg),
          if (patient.emergencyContact != null) ...[
            _buildEmergencyContact(patient.emergencyContact!),
            const SizedBox(height: AppSpacing.lg),
          ],
          _buildHealthScore(patient),
          const SizedBox(height: AppSpacing.lg),
          _buildInsuranceInfo(patient),
          const SizedBox(height: AppSpacing.lg),
          _buildActionButtons(patient),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo(PatientDetail patient) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Informations personnelles'),
          _InfoRow(icon: LucideIcons.cake, label: 'Date de naissance', value: DateFormat('dd/MM/yyyy').format(patient.dateOfBirth)),
          const Divider(height: 20),
          _InfoRow(icon: LucideIcons.venus, label: 'Genre', value: patient.gender),
          const Divider(height: 20),
          _InfoRow(icon: LucideIcons.droplet, label: 'Groupe sanguin', value: patient.bloodType),
          const Divider(height: 20),
          _InfoRow(icon: LucideIcons.phone, label: 'Téléphone', value: patient.phone.isEmpty ? 'Non renseigné' : patient.phone),
          const Divider(height: 20),
          _InfoRow(icon: LucideIcons.mail, label: 'Email', value: patient.email.isEmpty ? 'Non renseigné' : patient.email),
        ],
      ),
    );
  }

  Widget _buildMedicalInfo(PatientDetail patient) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Informations médicales'),
          const Text(
            'Allergies',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 8),
          patient.allergies.isEmpty
              ? const Text('Aucune allergie connue', style: TextStyle(fontSize: 13, color: AppColors.mutedForeground))
              : Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: patient.allergies.map((a) => Chip(
                    label: Text(a, style: const TextStyle(fontSize: 12, color: AppColors.destructive)),
                    backgroundColor: AppColors.destructive.withValues(alpha: 0.1),
                    side: BorderSide.none,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
          const SizedBox(height: 16),
          const Text(
            'Conditions chroniques',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 8),
          patient.chronicConditions.isEmpty
              ? const Text('Aucune condition chronique', style: TextStyle(fontSize: 13, color: AppColors.mutedForeground))
              : Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: patient.chronicConditions.map((c) => Chip(
                    label: Text(c, style: const TextStyle(fontSize: 12, color: AppColors.darkText)),
                    backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                    side: BorderSide.none,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
          const SizedBox(height: 16),
          const Text(
            'Médicaments actuels',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 8),
          patient.currentMeds.isEmpty
              ? const Text('Aucun médicament actuel', style: TextStyle(fontSize: 13, color: AppColors.mutedForeground))
              : Column(
                  children: patient.currentMeds.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.pill, size: 14, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(m, style: const TextStyle(fontSize: 13, color: AppColors.foreground)),
                      ],
                    ),
                  )).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContact(EmergencyContactInfo contact) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.alert.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(LucideIcons.phoneCall, size: 18, color: AppColors.alert),
              ),
              const SizedBox(width: 12),
              const Text(
                'Contact d\'urgence',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(icon: LucideIcons.user, label: 'Nom', value: contact.name),
          const Divider(height: 16),
          _InfoRow(icon: LucideIcons.heart, label: 'Relation', value: contact.relationship),
          const Divider(height: 16),
          _InfoRow(icon: LucideIcons.phone, label: 'Téléphone', value: contact.phone),
        ],
      ),
    );
  }

  Widget _buildHealthScore(PatientDetail patient) {
    final score = patient.healthScore;
    final color = score >= 80
        ? AppColors.success
        : score >= 60
            ? AppColors.accent
            : AppColors.destructive;

    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: score / 100.0,
                    strokeWidth: 6,
                    color: color,
                    backgroundColor: AppColors.muted,
                  ),
                ),
                Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Score de santé',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  score >= 80
                      ? 'Excellent'
                      : score >= 60
                          ? 'Bon'
                          : 'Nécessite une attention',
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsuranceInfo(PatientDetail patient) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(LucideIcons.shield, size: 22, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assurance',
                  style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 2),
                Text(
                  patient.insuranceProvider.isEmpty ? 'Non renseigné' : patient.insuranceProvider,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                if (patient.insuranceNumber.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'No: ${patient.insuranceNumber}',
                    style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(PatientDetail patient) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: LucideIcons.fileText,
            label: 'Consultation',
            color: AppColors.primary,
            onTap: () => context.push(
              '/consultations',
              extra: PatientSummary(
                id: patient.id,
                name: patient.name,
                nationalId: patient.nationalId,
                dateOfBirth: patient.dateOfBirth,
                bloodType: patient.bloodType,
                gender: patient.gender,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: LucideIcons.pill,
            label: 'Prescription',
            color: AppColors.success,
            onTap: () => context.push(
              '/prescriptions',
              extra: PatientSummary(
                id: patient.id,
                name: patient.name,
                nationalId: patient.nationalId,
                dateOfBirth: patient.dateOfBirth,
                bloodType: patient.bloodType,
                gender: patient.gender,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: LucideIcons.beaker,
            label: 'Analyse',
            color: AppColors.accent,
            onTap: () => context.go('/lab-requests'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: LucideIcons.scan,
            label: 'Imagerie',
            color: AppColors.alert,
            onTap: () => context.go('/imaging-requests'),
          ),
        ),
      ],
    );
  }

  Widget _buildDossierTab() {
    if (_loadingRecords) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_recordsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.destructive),
              const SizedBox(height: 12),
              Text(_recordsError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.mutedForeground)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadRecords,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    final entries = <_RecordEntry>[];
    for (final c in _consultations) {
      entries.add(_RecordEntry(
        type: RecordType.consultation,
        date: c.date,
        record: c,
        onTap: () => _openRecord(c, RecordType.consultation),
      ));
    }
    for (final l in _labs) {
      entries.add(_RecordEntry(
        type: RecordType.lab,
        date: l.orderedAt,
        record: l,
        onTap: () => _openRecord(l, RecordType.lab),
      ));
    }
    for (final i in _imaging) {
      entries.add(_RecordEntry(
        type: RecordType.imaging,
        date: i.orderedAt,
        record: i,
        onTap: () => _openRecord(i, RecordType.imaging),
      ));
    }
    for (final p in _prescriptions) {
      entries.add(_RecordEntry(
        type: RecordType.prescription,
        date: p.issueDate,
        record: p,
        onTap: () => _openRecord(p, RecordType.prescription),
      ));
    }
    entries.sort((a, b) => b.date.compareTo(a.date));
    if (entries.isEmpty) {
      return const EmptyState(
        icon: LucideIcons.fileStack,
        message: 'Aucune donnée médicale',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RecordCard(
            record: entry.record,
            type: entry.type,
            onTap: entry.onTap,
          ),
        );
      },
    );
  }

  void _openRecord(dynamic record, RecordType type) {
    context.push(
      '/patients/${widget.patientId}/record',
      extra: <String, dynamic>{'record': record, 'type': type},
    );
  }

  Widget _buildVisitsTab(PatientDetail patient) {
    if (_loadingAppointments) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_appointments.isEmpty) {
      return const EmptyState(
        icon: LucideIcons.calendarX,
        message: 'Aucune visite',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      itemCount: _appointments.length,
      itemBuilder: (context, index) {
        final a = _appointments[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.clock, size: 14, color: AppColors.mutedForeground),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('dd/MM/yyyy').format(a.date),
                      style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      a.timeSlot,
                      style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                const SizedBox(height: 6),
                Text(
                  a.type,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.foreground,
                  ),
                ),
                if (a.reason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    a.reason,
                    style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openVitalsEdit(PatientDetail patient) async {
    final updated = await context.push<PatientDetail>(
      '/patients/${patient.id}/vitals',
      extra: patient,
    );
    if (updated != null && mounted) {
      setState(() => _patient = updated);
    }
  }

  void _showQrCode(PatientDetail patient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Code QR du patient',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              patient.nationalId,
              style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: QrImageView(
                data: patient.id,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: AppColors.white,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return AppColors.accent;
      case 'confirmed': return AppColors.primary;
      case 'completed': return AppColors.success;
      case 'cancelled': return AppColors.mutedForeground;
      default: return AppColors.mutedForeground;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending': return 'En attente';
      case 'confirmed': return 'Confirmé';
      case 'completed': return 'Terminé';
      case 'cancelled': return 'Annulé';
      default: return status;
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.mutedForeground),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.foreground,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordEntry {
  final RecordType type;
  final DateTime date;
  final dynamic record;
  final VoidCallback onTap;

  _RecordEntry({
    required this.type,
    required this.date,
    required this.record,
    required this.onTap,
  });
}
