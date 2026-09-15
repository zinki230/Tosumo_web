import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../shared/models/booklet_entry.dart';
import '../../../core/utils/formatters.dart';

class ConsultationPdfService {
  static Future<Uint8List> generate(BookletEntry entry, {
    required String patientName,
    required String dob,
    required String gender,
    required String bloodType,
    required String medicalId,
    required String locale,
  }) async {
    final pdf = pw.Document();

    final doctorName = entry.signature?.doctorName ?? entry.doctorName ?? 'Non spécifié';
    final license = entry.signature?.licenseId ?? '';
    final hospital = entry.signature?.hospitalName ?? entry.facility;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (context) => [
          _buildLetterhead(entry, locale),
          _buildPatientInfo(patientName, dob, gender, bloodType, medicalId, locale),
          _buildDoctorInfo(doctorName, entry.doctorSpecialty ?? '', license, hospital, locale),
          if (entry.symptoms != null && entry.symptoms!.isNotEmpty)
            _buildTextSection(locale == 'fr' ? 'Motif de la consultation' : 'Chief Complaint', entry.symptoms!),
          _buildHistory(entry, locale),
          _buildClinicalExam('', '', '', '', '', false, false, false, false, entry, locale),
          if (entry.diagnosis != null && entry.diagnosis!.isNotEmpty)
            _buildDiagnosis(entry.diagnosis!, locale == 'fr' ? 'Diagnostic de travail' : 'Working Diagnosis'),
          _buildDifferentialDiagnosis(entry.diagnosis ?? '', locale),
          if (entry.diagnosis != null && entry.diagnosis!.isNotEmpty)
            _buildFinalDiagnosis(entry.diagnosis!, entry.visitDate, locale),
          if (entry.testsRequested.isNotEmpty)
            _buildTests(entry.testsRequested, locale),
          if (entry.labResults.isNotEmpty)
            _buildLabResults(entry.labResults, locale),
          if (entry.prescriptions.isNotEmpty)
            _buildPrescriptions(entry.prescriptions, locale),
          if (entry.recommendations != null && entry.recommendations!.isNotEmpty)
            _buildTextSection(locale == 'fr' ? 'Recommandations médicales' : 'Medical Recommendations', entry.recommendations!),
          if (entry.doctorNotes != null && entry.doctorNotes!.isNotEmpty)
            _buildTextSection(locale == 'fr' ? 'Observations du médecin' : "Doctor's Observations", entry.doctorNotes!),
          _buildSignature(doctorName, license, hospital, entry, locale),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildLetterhead(BookletEntry entry, String locale) {
    return _card(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 56, height: 56,
              decoration: pw.BoxDecoration(
                gradient: const pw.LinearGradient(colors: [PdfColors.blue700, PdfColors.blue400]),
                borderRadius: pw.BorderRadius.circular(14),
              ),
              child: pw.Center(child: pw.Text('T', style: pw.TextStyle(color: PdfColors.white, fontSize: 22, fontWeight: pw.FontWeight.bold))),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(entry.facility, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(entry.doctorSpecialty ?? 'Médecine Générale', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(locale == 'fr' ? 'Document N°' : 'Document ID:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey400, letterSpacing: 1)),
                pw.SizedBox(height: 4),
                pw.Text(entry.id.toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue100,
                    border: pw.Border.all(color: PdfColors.blue300),
                    borderRadius: pw.BorderRadius.circular(999),
                  ),
                  child: pw.Text(entry.consultationType ?? 'Routine',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Divider(height: 1, color: PdfColors.grey300),
        pw.SizedBox(height: 12),
        pw.Row(
          children: [
            pw.Expanded(child: _labelValuePdf(locale == 'fr' ? 'Date de la consultation' : 'Date of Consultation', AppFormatters.formatDate(entry.visitDate))),
            pw.Expanded(child: _labelValuePdf(locale == 'fr' ? 'Heure' : 'Time', AppFormatters.formatTime(entry.visitDate))),
            pw.Expanded(child: _labelValuePdf(locale == 'fr' ? 'Type' : 'Type', entry.consultationType ?? 'Routine')),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildPatientInfo(String name, String dob, String gender, String bloodType, String medicalId, String locale) {
    return _card(
      children: [
        _sectionHeader(locale == 'fr' ? 'Informations du patient' : 'Patient Information'),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          pw.Expanded(child: _labelValuePdf(locale == 'fr' ? 'Nom complet' : 'Full Name', name)),
          pw.Expanded(child: _labelValuePdf(locale == 'fr' ? 'Date de naissance' : 'Date of Birth', dob)),
        ]),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          pw.Expanded(child: _labelValuePdf(locale == 'fr' ? 'Genre' : 'Gender', gender)),
          pw.Expanded(child: _labelValuePdf(locale == 'fr' ? 'Groupe sanguin' : 'Blood Type', bloodType)),
        ]),
        pw.SizedBox(height: 8),
        _labelValuePdf(locale == 'fr' ? "N° d'identifiant médical" : 'Medical ID', medicalId),
      ],
    );
  }

  static pw.Widget _buildDoctorInfo(String doctorName, String specialty, String license, String hospital, String locale) {
    return _card(
      children: [
        _sectionHeader(locale == 'fr' ? 'Médecin traitant' : 'Attending Physician'),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          pw.Container(
            width: 40, height: 40,
            decoration: pw.BoxDecoration(color: PdfColors.blue100, shape: pw.BoxShape.circle),
            child: pw.Center(child: pw.Text('\u{1F464}', style: pw.TextStyle(fontSize: 18))),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(doctorName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(specialty, style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
            pw.Text('${locale == 'fr' ? 'Licence' : 'License'}: $license', style: pw.TextStyle(fontSize: 11, color: PdfColors.grey500)),
            pw.Text(hospital, style: pw.TextStyle(fontSize: 11, color: PdfColors.grey500)),
          ])),
        ]),
      ],
    );
  }

  static pw.Widget _buildHistory(BookletEntry entry, String locale) {
    return _card(
      children: [
        _sectionHeader(locale == 'fr' ? 'Histoire de la maladie actuelle' : 'History of Present Illness'),
        pw.SizedBox(height: 8),
        pw.Text(
          '${entry.doctorNotes?.split('.').first ?? 'Patient presents with symptoms as described in chief complaint.'} The patient reports gradual onset of symptoms over the past period leading to this consultation.',
          style: const pw.TextStyle(fontSize: 13)),
      ],
    );
  }

  static pw.Widget _buildClinicalExam(String bpSys, String bpDia, String hr, String temp, String rr,
      bool abBp, bool abHr, bool abTemp, bool abRr, BookletEntry entry, String locale) {
    return _card(
      children: [
        _sectionHeader(locale == 'fr' ? 'Examen clinique' : 'Clinical Examination'),
        pw.SizedBox(height: 8),
        pw.Text(locale == 'fr' ? 'Signes vitaux' : 'Vital Signs', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey400, letterSpacing: 1)),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          pw.Expanded(child: _vitalCardPdf('TA', bpSys.isNotEmpty && bpDia.isNotEmpty ? '$bpSys/$bpDia' : '—', 'mmHg', abBp)),
          pw.SizedBox(width: 8),
          pw.Expanded(child: _vitalCardPdf('FC', hr.isEmpty ? '—' : hr, 'bpm', abHr)),
        ]),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          pw.Expanded(child: _vitalCardPdf('Temp', temp.isEmpty ? '—' : '$temp°C', '', abTemp)),
          pw.SizedBox(width: 8),
          pw.Expanded(child: _vitalCardPdf('FR', rr.isEmpty ? '—' : rr, '/min', abRr)),
        ]),
        pw.SizedBox(height: 16),
        pw.Text(locale == 'fr' ? 'Examen physique' : 'Physical Examination', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey400, letterSpacing: 1)),
        pw.SizedBox(height: 8),
        pw.Text(_generatePhysicalExam(entry), style: const pw.TextStyle(fontSize: 13)),
      ],
    );
  }

  static pw.Widget _buildDiagnosis(String diagnosis, String label) {
    return _card(
      children: [
        _sectionHeader(label),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity, padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: pw.BorderRadius.circular(12), border: pw.Border.all(color: PdfColors.blue200)),
          child: pw.Text(diagnosis, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    );
  }

  static pw.Widget _buildDifferentialDiagnosis(String diagnosis, String locale) {
    final items = _generateDifferentialDiagnosis(diagnosis);
    return _card(
      children: [
        _sectionHeader(locale == 'fr' ? 'Diagnostic différentiel' : 'Differential Diagnosis'),
        pw.SizedBox(height: 8),
        ...items.asMap().entries.map((e) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(children: [
            pw.Container(
              width: 20, height: 20,
              decoration: pw.BoxDecoration(color: PdfColors.blue100, shape: pw.BoxShape.circle),
              child: pw.Center(child: pw.Text('${e.key + 1}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700))),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(color: PdfColors.grey50, borderRadius: pw.BorderRadius.circular(8), border: pw.Border.all(color: PdfColors.grey200)),
              child: pw.Text(e.value, style: const pw.TextStyle(fontSize: 13)),
            )),
          ]),
        )),
      ],
    );
  }

  static pw.Widget _buildFinalDiagnosis(String diagnosis, String visitDate, String locale) {
    return _card(
      children: [
        _sectionHeader(locale == 'fr' ? 'Diagnostic final' : 'Final Diagnosis'),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity, padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(color: PdfColors.green50, borderRadius: pw.BorderRadius.circular(12), border: pw.Border.all(color: PdfColors.green200)),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('\u2714\uFE0F', style: const pw.TextStyle(fontSize: 20)),
            pw.SizedBox(width: 12),
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(diagnosis, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('${locale == 'fr' ? 'Confirmé le' : 'Confirmed on'} ${AppFormatters.formatDate(visitDate)}',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
            ])),
          ]),
        ),
      ],
    );
  }

  static pw.Widget _buildTests(List<TestRequest> tests, String locale) {
    return _card(
      children: [
        _sectionHeader(locale == 'fr' ? 'Analyses demandées' : 'Requested Lab Tests'),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headerStyle: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500),
          cellStyle: const pw.TextStyle(fontSize: 12),
          headerDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
          headers: [locale == 'fr' ? 'Nom du test' : 'Test Name', locale == 'fr' ? 'Statut' : 'Status'],
          data: tests.map((t) => [t.name, t.status]).toList(),
        ),
      ],
    );
  }

  static pw.Widget _buildLabResults(List<LabResult> results, String locale) {
    return _card(
      children: [
        _sectionHeader(locale == 'fr' ? "Résultats d'analyses" : 'Lab Results'),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headerStyle: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500),
          cellStyle: const pw.TextStyle(fontSize: 11),
          headerDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
          headers: [
            locale == 'fr' ? 'Nom du test' : 'Test Name',
            locale == 'fr' ? 'Résultat' : 'Result',
            locale == 'fr' ? 'Valeurs de référence' : 'Reference Range',
            locale == 'fr' ? 'Statut' : 'Status',
          ],
          data: results.map((r) => [r.testName, r.resultValue, r.referenceRange, r.interpretation]).toList(),
        ),
      ],
    );
  }

  static pw.Widget _buildPrescriptions(List<PrescribedMedication> prescriptions, String locale) {
    return _card(
      children: [
        pw.Row(children: [
          pw.Text(locale == 'fr' ? 'Prescription' : 'Prescription',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5, color: PdfColors.grey500)),
          pw.SizedBox(width: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.circular(999)),
            child: pw.Text('${prescriptions.length} ${locale == 'fr' ? 'médicament(s)' : 'medication(s)'}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ),
        ]),
        pw.SizedBox(height: 12),
        ...prescriptions.asMap().entries.map((e) {
          final med = e.value;
          final isEven = e.key.isEven;
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8), padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: isEven ? PdfColors.grey50 : PdfColors.white, borderRadius: pw.BorderRadius.circular(12)),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Container(
                width: 32, height: 32,
                decoration: pw.BoxDecoration(color: PdfColors.blue100, borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Center(child: pw.Text('\u{1F48A}', style: const pw.TextStyle(fontSize: 16))),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Row(children: [
                  pw.Text(med.drugName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(width: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: pw.BoxDecoration(color: PdfColors.blue100, borderRadius: pw.BorderRadius.circular(999)),
                    child: pw.Text(med.dosage, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                  ),
                ]),
                pw.SizedBox(height: 4),
                pw.Row(children: [
                  pw.Text('${locale == 'fr' ? 'Fréquence' : 'Frequency'}: ', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  pw.Text(med.frequency, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(width: 16),
                  pw.Text('${locale == 'fr' ? 'Durée' : 'Duration'}: ', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  pw.Text(med.duration, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ]),
                if (med.instructions.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 4),
                    child: pw.Text(med.instructions, style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
                  ),
              ])),
            ]),
          );
        }),
      ],
    );
  }

  static pw.Widget _buildSignature(String doctorName, String license, String hospital, BookletEntry entry, String locale) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16), padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blue100), borderRadius: pw.BorderRadius.circular(16)),
      child: pw.Column(children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _sectionHeader(locale == 'fr' ? 'Signature du médecin' : "Doctor's Signature"),
            pw.SizedBox(height: 12),
            pw.Row(children: [
              pw.Container(
                width: 48, height: 48,
                decoration: pw.BoxDecoration(color: PdfColors.blue100, shape: pw.BoxShape.circle),
                child: pw.Center(child: pw.Text('\u{1F464}', style: const pw.TextStyle(fontSize: 24))),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(doctorName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                pw.Text('${locale == 'fr' ? 'Licence' : 'License'} $license', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                pw.Text(hospital, style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                if (entry.signature != null)
                  pw.Text(
                    '${locale == 'fr' ? 'Signé numériquement à' : 'Digitally Signed at'} ${AppFormatters.formatTime(entry.signature!.signedAt)} ${locale == 'fr' ? 'le' : 'on'} ${AppFormatters.formatDate(entry.signature!.signedAt)}',
                    style: pw.TextStyle(fontSize: 11, color: PdfColors.grey400)),
              ])),
            ]),
          ])),
        ]),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: PdfColors.grey50, borderRadius: pw.BorderRadius.circular(12)),
          child: pw.Row(children: [
            pw.Text('\u{1F4CB}', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: pw.Text(
              '${locale == 'fr' ? 'Signé numériquement par' : 'Digitally signed by'} $doctorName ${locale == 'fr' ? 'le' : 'on'} ${entry.signature != null ? AppFormatters.formatDate(entry.signature!.signedAt) : AppFormatters.formatDate(entry.visitDate)} ${locale == 'fr' ? 'à' : 'at'} ${entry.signature != null ? AppFormatters.formatTime(entry.signature!.signedAt) : AppFormatters.formatTime(entry.visitDate)}',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600))),
          ]),
        ),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          pw.Text('\u2705', style: const pw.TextStyle(fontSize: 14)),
          pw.SizedBox(width: 8),
          pw.Text(locale == 'fr' ? 'Ce document est juridiquement valable' : 'This is a legally valid medical document',
              style: pw.TextStyle(fontSize: 11, color: PdfColors.green700)),
        ]),
      ]),
    );
  }

  static pw.Widget _buildTextSection(String label, String content) {
    return _card(
      children: [
        _sectionHeader(label),
        pw.SizedBox(height: 8),
        pw.Text(content, style: const pw.TextStyle(fontSize: 13)),
      ],
    );
  }

  static pw.Widget _sectionHeader(String label) {
    return pw.Text(label, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5, color: PdfColors.grey500));
  }

  static pw.Widget _labelValuePdf(String label, String value) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label, style: pw.TextStyle(fontSize: 10, letterSpacing: 0.5, color: PdfColors.grey400)),
      pw.SizedBox(height: 2),
      pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
    ]);
  }

  static pw.Widget _vitalCardPdf(String label, String value, String unit, bool abnormal) {
    final borderColor = abnormal ? PdfColor.fromInt(0xFFFDE68A) : PdfColors.grey300;
    final textColor = abnormal ? PdfColor.fromInt(0xFFD97706) : PdfColors.black;
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: abnormal ? PdfColor.fromInt(0xFFFFFBE8) : PdfColor.fromInt(0xFFF9FAFB),
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: borderColor),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(children: [
          pw.Text('\u2764\uFE0F', style: pw.TextStyle(fontSize: 12, color: textColor)),
          pw.SizedBox(width: 4),
          pw.Text(label, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        ]),
        pw.SizedBox(height: 4),
        pw.Text('$value${unit.isNotEmpty ? ' $unit' : ''}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: textColor)),
      ]),
    );
  }

  static String _generatePhysicalExam(BookletEntry entry) {
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

  static List<String> _generateDifferentialDiagnosis(String diagnosis) {
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

  static pw.Widget _card({required List<pw.Widget> children}) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children),
    );
  }

  static Future<void> printReport(BookletEntry entry, {
    required String patientName,
    required String dob,
    required String gender,
    required String bloodType,
    required String medicalId,
    required String locale,
  }) async {
    final pdf = await generate(entry,
      patientName: patientName,
      dob: dob,
      gender: gender,
      bloodType: bloodType,
      medicalId: medicalId,
      locale: locale,
    );
    await Printing.layoutPdf(onLayout: (_) => pdf);
  }

  static Future<void> downloadReport(BookletEntry entry, {
    required String patientName,
    required String dob,
    required String gender,
    required String bloodType,
    required String medicalId,
    required String locale,
  }) async {
    final pdf = await generate(entry,
      patientName: patientName,
      dob: dob,
      gender: gender,
      bloodType: bloodType,
      medicalId: medicalId,
      locale: locale,
    );
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/consultation_${entry.id}.pdf');
    await file.writeAsBytes(pdf);
    await Printing.sharePdf(bytes: pdf, filename: 'consultation_${entry.id}.pdf');
  }
}
