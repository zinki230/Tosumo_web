import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/patient_provider.dart';
import '../../../core/utils/localization.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_animated_mount.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/models/booklet_entry.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/data/repositories/repository_providers.dart';
import 'consultation_pdf_service.dart';

class MedicalConsultationScreen extends ConsumerWidget {
  final String entryId;

  const MedicalConsultationScreen({super.key, required this.entryId});

  Color _consultationTypeColor(String? type) {
    switch (type) {
      case 'Urgence': return const Color(0xFFEF4444);
      case 'Suivi': return const Color(0xFFA855F7);
      default: return const Color(0xFF1677D2);
    }
  }

  Map<String, dynamic> _entryVitals(BookletEntry entry) {
    return const {'bp': '', 'hr': '', 'temp': '', 'rr': ''};
  }

  bool _isAbnormal(String key, dynamic val) {
    if (val == null || (val is String && val.isEmpty)) return false;
    if (val is String && val.contains('/')) {
      final parts = val.split('/');
      return int.tryParse(parts[0]) != null && int.parse(parts[0]) > 130;
    }
    if (val is String && val.contains('°C')) {
      final n = double.tryParse(val.replaceAll('°C', ''));
      return n != null && (n > 37.2 || n < 36.0);
    }
    if (val is int) return val > 100 || val < 60;
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final locAsync = ref.watch(localizationProvider(locale));
    final t = locAsync.asData?.value;
    final state = ref.watch(patientProvider);
    final patient = state.patient;
    final entry = state.bookletEntries.where((e) => e.id == entryId).firstOrNull;

    if (entry == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.alertCircle, size: 48, color: AppColors.mutedForeground.withAlpha(102)),
              const SizedBox(height: 16),
              Text(t?.t('consultation.notFound') ?? '', style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.card,
                  foregroundColor: AppColors.foreground,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: Text(t?.t('consultation.back') ?? ''),
              ),
            ],
          ),
        ),
      );
    }

    final vitals = _entryVitals(entry);
    final doctorName = entry.signature?.doctorName ?? entry.doctorName ?? t?.t('consultation.notSpecified') ?? '';
    final license = entry.signature?.licenseId ?? '';
    final hospital = entry.signature?.hospitalName ?? entry.facility;

    void handlePrint() {
      ConsultationPdfService.printReport(entry,
        patientName: patient?.name ?? '',
        dob: patient != null ? AppFormatters.formatDate(patient.dateOfBirth) : '',
        gender: patient?.gender ?? '',
        bloodType: patient?.bloodType ?? '',
        medicalId: patient?.nationalId ?? '',
        locale: locale,
      );
    }

    void handleDownload() {
      ConsultationPdfService.downloadReport(entry,
        patientName: patient?.name ?? '',
        dob: patient != null ? AppFormatters.formatDate(patient.dateOfBirth) : '',
        gender: patient?.gender ?? '',
        bloodType: patient?.bloodType ?? '',
        medicalId: patient?.nationalId ?? '',
        locale: locale,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white.withAlpha(230),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: const AppBackButton(),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(LucideIcons.printer, size: 18),
              onPressed: handlePrint,
              tooltip: t?.t('consultation.print') ?? '',
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(LucideIcons.download, size: 18),
              onPressed: handleDownload,
              tooltip: t?.t('consultation.downloadPdf') ?? '',
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Hospital Letterhead
            _ConsultationSection(
              delay: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(child: Text('T', style: TextStyle(color: AppColors.white, fontSize: 22, fontWeight: FontWeight.w700))),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.facility,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.doctorSpecialty ?? 'Médecine Générale',
                              style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(t?.t('consultation.documentId') ?? '', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground.withAlpha(153), letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(
                              entry.id.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: _consultationTypeColor(entry.consultationType).withAlpha(25),
                                border: Border.all(color: _consultationTypeColor(entry.consultationType).withAlpha(128)),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                entry.consultationType ?? 'Routine',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _consultationTypeColor(entry.consultationType)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _labelValue(
                          t?.t('consultation.date') ?? '',
                          AppFormatters.formatDate(entry.visitDate),
                        ),
                      ),
                      Expanded(
                        child: _labelValue(
                          t?.t('consultation.time') ?? '',
                          AppFormatters.formatTime(entry.visitDate),
                        ),
                      ),
                      Expanded(
                        child: _labelValue(
                          t?.t('consultation.type') ?? '',
                          entry.consultationType ?? 'Routine',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Patient Information
            _ConsultationSection(
              delay: 40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(t?.t('consultation.patientInformation') ?? ''),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _labelValue(t?.t('consultation.fullName') ?? '', patient?.name ?? '')),
                      Expanded(child: _labelValue(t?.t('consultation.dob') ?? '', patient != null ? AppFormatters.formatDate(patient.dateOfBirth) : '')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _labelValue(t?.t('consultation.gender') ?? '', patient?.gender ?? '')),
                      Expanded(child: _labelValue(t?.t('consultation.bloodType') ?? '', patient?.bloodType ?? '')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _labelValue(t?.t('consultation.medicalId') ?? '', patient?.nationalId ?? ''),
                ],
              ),
            ),

            // Doctor Information
            _ConsultationSection(
              delay: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(t?.t('consultation.attendingPhysician') ?? ''),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: AppColors.primary.withAlpha(25), shape: BoxShape.circle),
                        child: const Icon(LucideIcons.user, size: 20, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(doctorName, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(entry.doctorSpecialty ?? '', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                            _infoRow(LucideIcons.fileSignature, '${t?.t('consultation.license') ?? ''}: $license'),
                            _infoRow(LucideIcons.mapPin, hospital),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chief Complaint
            if (entry.symptoms != null && entry.symptoms!.isNotEmpty)
              _ConsultationSection(
                delay: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(t?.t('consultation.chiefComplaint') ?? ''),
                    const SizedBox(height: 8),
                    Text(entry.symptoms!, style: const TextStyle(fontSize: 13, height: 1.5)),
                  ],
                ),
              ),

            // History
            _ConsultationSection(
              delay: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(t?.t('consultation.historyOfPresentIllness') ?? ''),
                  const SizedBox(height: 8),
                  Text(
                    '${entry.doctorNotes?.split('.').first ?? 'Patient presents with symptoms as described in chief complaint.'} The patient reports gradual onset of symptoms over the past period leading to this consultation.',
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),

            // Clinical Examination
            _ConsultationSection(
              delay: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(t?.t('consultation.clinicalExamination') ?? ''),
                  const SizedBox(height: 12),
                  Text(t?.t('consultation.vitalSigns') ?? '', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground.withAlpha(153), letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _vitalCard(LucideIcons.activity, t?.t('consultation.bloodPressure') ?? '', vitals['bp'] as String, 'mmHg', _isAbnormal('bp', vitals['bp']))),
                      const SizedBox(width: 8),
                      Expanded(child: _vitalCard(LucideIcons.heart, t?.t('consultation.heartRate') ?? '', '${vitals['hr']}', 'bpm', _isAbnormal('hr', vitals['hr']))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _vitalCard(LucideIcons.thermometer, t?.t('consultation.temperature') ?? '', vitals['temp'] as String, '', _isAbnormal('temp', vitals['temp']))),
                      const SizedBox(width: 8),
                      Expanded(child: _vitalCard(LucideIcons.wind, t?.t('consultation.respiratoryRate') ?? '', '${vitals['rr']}', 'rpm', _isAbnormal('rr', vitals['rr']))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(t?.t('consultation.physicalExamination') ?? '', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground.withAlpha(153), letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text(
                    _generatePhysicalExam(entry),
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),

            // Working Diagnosis
            if (entry.diagnosis != null && entry.diagnosis!.isNotEmpty)
              _ConsultationSection(
                delay: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(t?.t('consultation.workingDiagnosis') ?? ''),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDBEAFE))),
                      child: Text(entry.diagnosis!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),

            // Differential Diagnosis
            _ConsultationSection(
              delay: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(t?.t('consultation.differentialDiagnosis') ?? ''),
                  const SizedBox(height: 8),
                  ..._generateDifferentialDiagnosis(entry.diagnosis ?? '').asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(color: AppColors.primary.withAlpha(25), shape: BoxShape.circle),
                          child: Center(child: Text('${e.key + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary))),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFF3F4F6))),
                            child: Text(e.value, style: const TextStyle(fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),

            // Final Diagnosis
            if (entry.diagnosis != null && entry.diagnosis!.isNotEmpty)
              _ConsultationSection(
                delay: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(t?.t('consultation.finalDiagnosis') ?? ''),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBBF7D0))),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(LucideIcons.checkCircle2, size: 20, color: Color(0xFF16A34A)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry.diagnosis!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text('${t?.t('consultation.confirmedOn') ?? ''} ${AppFormatters.formatDate(entry.visitDate)}', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Requested Tests
            if (entry.testsRequested.isNotEmpty)
              _ConsultationSection(
                delay: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(t?.t('consultation.requestedTests') ?? ''),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(flex: 3, child: Text(t?.t('consultation.testName') ?? '', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground.withAlpha(153), letterSpacing: 1))),
                        const Spacer(),
                        Text(t?.t('consultation.status') ?? '', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground.withAlpha(153), letterSpacing: 1)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...entry.testsRequested.map((test) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text(test.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: test.status == 'Completed' ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              test.status,
                              style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w500,
                                color: test.status == 'Completed' ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),

            // Imaging
            if (_generateImaging(entry).isNotEmpty)
              _ConsultationSection(
                delay: 240,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(t?.t('consultation.imagingRequests') ?? ''),
                    const SizedBox(height: 8),
                    ...(_generateImaging(entry)).map((img) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF3F4F6))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.activity, size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(img['modality'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: img['status'] == 'Completed' ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(img['status'] ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: const Color(0xFF16A34A))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(img['findings'] ?? '', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.mutedForeground)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),

            // Lab Results
            if (entry.labResults.isNotEmpty)
              _ConsultationSection(
                delay: 260,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(t?.t('consultation.labResults') ?? ''),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(flex: 3, child: Text(t?.t('consultation.testName') ?? '', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground.withAlpha(153), letterSpacing: 1))),
                        Expanded(flex: 2, child: Text(t?.t('consultation.result') ?? '', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground.withAlpha(153), letterSpacing: 1))),
                        Expanded(flex: 2, child: Text(t?.t('consultation.referenceRange') ?? '', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground.withAlpha(153), letterSpacing: 1))),
                        Text(t?.t('consultation.status') ?? '', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground.withAlpha(153), letterSpacing: 1)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...entry.labResults.map((result) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: result.interpretation == 'Abnormal' ? const Color(0xFFFEF2F2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: result.interpretation == 'Abnormal' ? const Color(0xFFFECACA) : AppColors.border.withAlpha(77)),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text(result.testName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                          Expanded(flex: 2, child: Text(result.resultValue, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: result.interpretation == 'Abnormal' ? const Color(0xFFDC2626) : AppColors.foreground))),
                          Expanded(flex: 2, child: Text(result.referenceRange, style: TextStyle(fontSize: 11, color: AppColors.mutedForeground))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: result.interpretation == 'Abnormal' ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              result.interpretation,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: result.interpretation == 'Abnormal' ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),

            // Examens demandés (doctor-ordered tests with uploadable results)
            ConsultationExamsSection(consultationId: entry.id),

            // Prescriptions
            if (entry.prescriptions.isNotEmpty)
              _ConsultationSection(
                delay: 280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(t?.t('consultation.prescription') ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.mutedForeground)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(999)),
                          child: Text(t?.t('consultation.medications', params: {'count': '${entry.prescriptions.length}'}) ?? '', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...entry.prescriptions.asMap().entries.map((e) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: e.key.isEven ? const Color(0xFFF9FAFB) : AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: AppColors.primary.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(LucideIcons.pill, size: 16, color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(e.value.drugName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(e.value.dosage, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primary)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text('${t?.t('consultation.frequency') ?? ''}: ${e.value.frequency}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text('${t?.t('consultation.duration') ?? ''}: ${e.value.duration}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                                    ),
                                  ],
                                ),
                                if (e.value.instructions.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(e.value.instructions, style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.mutedForeground)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),

            // Recommendations
            if (entry.recommendations != null && entry.recommendations!.isNotEmpty)
              _ConsultationSection(
                delay: 300,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(t?.t('consultation.recommendations') ?? ''),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF).withAlpha(128), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDBEAFE))),
                      child: Text(entry.recommendations!, style: const TextStyle(fontSize: 13, height: 1.5)),
                    ),
                  ],
                ),
              ),

            // Follow-up Plan
            _ConsultationSection(
              delay: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(t?.t('consultation.followUpPlan') ?? ''),
                  const SizedBox(height: 8),
                  _buildFollowUpPlan(entry, t),
                ],
              ),
            ),

            // Doctor Observations
            if (entry.doctorNotes != null && entry.doctorNotes!.isNotEmpty)
              _ConsultationSection(
                delay: 340,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(t?.t('consultation.doctorObservations') ?? ''),
                    const SizedBox(height: 8),
                    Text(entry.doctorNotes!, style: const TextStyle(fontSize: 13, height: 1.5)),
                  ],
                ),
              ),

            // Signature
            _ConsultationSection(
              delay: 380,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary.withAlpha(25)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionHeader(t?.t('consultation.doctorSignature') ?? ''),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(color: AppColors.primary.withAlpha(25), shape: BoxShape.circle),
                                    child: const Icon(LucideIcons.user, size: 24, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(doctorName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                        Text('${t?.t('consultation.license') ?? ''} $license', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                                        Text(hospital, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                                        if (entry.signature != null)
                                          Text(
                                            (t?.t('consultation.signedAt') ?? '').replaceAll('{{time}}', AppFormatters.formatTime(entry.signature!.signedAt)).replaceAll('{{date}}', AppFormatters.formatDate(entry.signature!.signedAt)),
                                            style: TextStyle(fontSize: 11, color: AppColors.mutedForeground.withAlpha(153)),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.fileSignature, size: 14, color: AppColors.mutedForeground),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (t?.t('consultation.digitallySignedBy') ?? '').replaceAll('{{doctor}}', doctorName).replaceAll('{{date}}', entry.signature != null ? AppFormatters.formatDate(entry.signature!.signedAt) : AppFormatters.formatDate(entry.visitDate)).replaceAll('{{time}}', entry.signature != null ? AppFormatters.formatTime(entry.signature!.signedAt) : AppFormatters.formatTime(entry.visitDate)),
                              style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(LucideIcons.checkCircle2, size: 14, color: Color(0xFF16A34A)),
                        const SizedBox(width: 8),
                        Text(t?.t('consultation.legallyValidDocument') ?? '', style: TextStyle(fontSize: 11, color: const Color(0xFF16A34A))),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: handlePrint,
                icon: const Icon(LucideIcons.printer, size: 16),
                label: Text(t?.t('consultation.printReport') ?? ''),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.foreground,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: handleDownload,
                icon: const Icon(LucideIcons.download, size: 16),
                label: Text(t?.t('consultation.downloadOfficial') ?? ''),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  elevation: 0,
                ),
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

  String _generatePhysicalExam(BookletEntry entry) {
    final spec = entry.doctorSpecialty ?? '';
    if (spec.contains('Cardio')) {
      return 'Cardiovasculaire : Bruits cardiaques S1+S2 normaux, pas de souffle, galop ou frottement. Pouls périphériques palpables et symétriques. Pas d\'œdème périphérique, cyanose ou hippocratisme digital.';
    }
    if (spec.contains('Pneumo') || spec.contains('Respirat')) {
      return 'Respiratoire : Expansion thoracique symétrique. Auscultation révèle des bruits respiratoires clairs bilatéralement, pas de sibilances, crépitants ou ronchus.';
    }
    if (spec.contains('Dent')) {
      return 'Examen Buccal : Muqueuse buccale rose et humide. Gencives sans inflammation. Site de l\'extraction montre un tissu de cicatrisation sain.';
    }
    if (spec.contains('Allerg')) {
      return 'Examen Cutané : Pas d\'urticaire active. Muqueuses claires. Cornets nasaux légèrement gonflés bilatéralement.';
    }
    return 'Apparence générale : Patient paraît en bon état général. Alerte et orienté. Peau : chaude et sèche, pas d\'éruptions.';
  }

  List<String> _generateDifferentialDiagnosis(String diagnosis) {
    if (diagnosis.contains('hyperten')) {
      return ['Hypertension blouse blanche', 'Hypertension secondaire (Rénale)', 'Trouble anxieux avec symptômes somatiques'];
    }
    if (diagnosis.contains('asthme') || diagnosis.contains('asthma')) {
      return ['BPCO (si fumeur)', 'Dysfonction des cordes vocales', 'Aspiration de corps étranger'];
    }
    if (diagnosis.contains('allerg')) {
      return ['Dermatite de contact', 'Urticaire médicamenteuse', 'Mastocytose'];
    }
    return ['Autre affection spécifiée', 'Diagnostic différentiel connexe', 'Exclure une pathologie alternative'];
  }

  List<Map<String, String>> _generateImaging(BookletEntry entry) {
    final spec = entry.doctorSpecialty ?? '';
    if (spec.contains('Cardio')) {
      return [{
        'modality': 'Échocardiogramme (2D + Doppler)',
        'findings': 'FEVG 60 %. Mouvement pariétal normal. Pas d\'anomalies valvulaires.',
        'status': 'Terminé',
      }];
    }
    if (spec.contains('Respirat') || spec.contains('Pneumo')) {
      return [{
        'modality': 'Radiographie Thoracique',
        'findings': 'Champs pulmonaires clairs. Silhouette cardiaque normale.',
        'status': 'Terminé',
      }];
    }
    if (spec.contains('Dent')) {
      return [{
        'modality': 'Radiographie Panoramique',
        'findings': 'Support osseux adéquat. Pas de kyste ou tumeur.',
        'status': 'Terminé',
      }];
    }
    return [];
  }

  Widget _buildFollowUpPlan(BookletEntry entry, dynamic t) {
    final isUrgence = entry.consultationType == 'Urgence';
    final isFollowUp = entry.consultationType == 'Suivi';
    final weeks = isUrgence ? 1 : isFollowUp ? 4 : 2;
    final returnDate = DateTime.now().add(Duration(days: weeks * 7));
    final when = 'Revenir dans $weeks semaine${weeks > 1 ? 's' : ''} (${AppFormatters.formatDate(returnDate.toIso8601String())})';

    final monitorItems = [
      'Surveiller les symptômes et signaler toute aggravation',
      'Suivre l\'observance thérapeutique et les effets secondaires',
      'Tenir un journal des symptômes si nécessaire',
    ];
    if (entry.consultationType == 'Urgence') {
      monitorItems.add('Consulter en urgence si les symptômes réapparaissent ou s\'aggravent');
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF3E8FF).withAlpha(128), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE9D5FF))),
          child: Row(
            children: [
              const Icon(LucideIcons.calendar, size: 16, color: Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t?.t('consultation.returnDate') ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF7C3AED))),
                  Text(when, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(t?.t('consultation.monitorInstructions') ?? '', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground.withAlpha(153), letterSpacing: 1)),
        const SizedBox(height: 8),
        ...monitorItems.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: AppColors.primary.withAlpha(102), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(item, style: const TextStyle(fontSize: 13))),
            ],
          ),
        )),
      ],
    );
  }

  Widget _sectionHeader(String label) {
    return Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.mutedForeground.withAlpha(153)));
  }

  Widget _labelValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, letterSpacing: 0.5, color: AppColors.mutedForeground.withAlpha(153))),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.mutedForeground.withAlpha(153)),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: AppColors.mutedForeground.withAlpha(179))),
        ],
      ),
    );
  }

  Widget _vitalCard(IconData icon, String label, String value, String unit, bool abnormal) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: abnormal ? const Color(0xFFFFFBEB).withAlpha(128) : const Color(0xFFF9FAFB).withAlpha(128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: abnormal ? const Color(0xFFFDE68A) : AppColors.border.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: abnormal ? const Color(0xFFD97706) : AppColors.mutedForeground),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '—' : '$value${unit.isNotEmpty ? ' ' : ''}$unit',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: abnormal ? const Color(0xFFD97706) : AppColors.foreground),
          ),
        ],
      ),
    );
  }
}

class _ConsultationSection extends StatelessWidget {
  final int delay;
  final Widget child;

  const _ConsultationSection({required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedMount(
      delay: delay,
      animation: 'fadeInUp',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withAlpha(77)),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: child,
      ),
    );
  }
}

/// Shows the exams a doctor ordered for this consultation and lets the patient
/// upload the resulting lab/test files (the doctor can also upload them).
class ConsultationExamsSection extends ConsumerStatefulWidget {
  final String consultationId;

  const ConsultationExamsSection({super.key, required this.consultationId});

  @override
  ConsumerState<ConsultationExamsSection> createState() => _ConsultationExamsSectionState();
}

class _ConsultationExamsSectionState extends ConsumerState<ConsultationExamsSection> {
  List<Map<String, dynamic>> _exams = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final consultation = await ref
          .read(remotePatientRepositoryProvider)
          .getConsultation(widget.consultationId);
      final exams = consultation['orderedExams'] as List<dynamic>?;
      if (mounted) {
        setState(() {
          _exams = exams
                  ?.map((e) => (e is Map ? e.cast<String, dynamic>() : <String, dynamic>{}))
                  .toList() ??
              <Map<String, dynamic>>[];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload(int index) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() => _uploading = true);
    try {
      final url = await ref.read(remotePatientRepositoryProvider).uploadFile(path);
      if (url != null && mounted) {
        final files = List<String>.from(_exams[index]['resultFiles'] as List<dynamic>? ?? <dynamic>[]);
        files.add(url);
        _exams[index] = {..._exams[index], 'resultFiles': files, 'uploadedBy': 'patient'};
        setState(() {});
        await ref.read(remotePatientRepositoryProvider).updateConsultation(
          widget.consultationId,
          {'orderedExams': _exams},
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Échec du téléversement')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _fileName(String url) {
    final parts = url.split('/');
    return parts.isNotEmpty ? parts.last : url;
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_exams.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Examens demandés',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 8),
        ..._exams.asMap().entries.map((entry) {
          final index = entry.key;
          final exam = entry.value;
          final files = (exam['resultFiles'] as List<dynamic>?) ?? <dynamic>[];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withAlpha(77)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam['name'] as String? ?? '',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if ((exam['note'] as String? ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      exam['note'] as String,
                      style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                    ),
                  ),
                const SizedBox(height: 10),
                if (files.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: files.map((f) {
                      final url = f as String;
                      return InkWell(
                        onTap: () => _open(url),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1677D2).withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.fileText, size: 14, color: Color(0xFF1677D2)),
                              const SizedBox(width: 6),
                              Text(_fileName(url), style: const TextStyle(fontSize: 12, color: Color(0xFF1677D2))),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _uploading ? null : () => _upload(index),
                    icon: _uploading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(LucideIcons.upload, size: 16),
                    label: Text(files.isEmpty ? 'Joindre un résultat' : 'Ajouter un résultat'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1677D2),
                      side: const BorderSide(color: Color(0xFF1677D2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
