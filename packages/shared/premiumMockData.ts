import type {
  Patient, BookletEntry, AccessGrant, AuditEvent, Card,
  HealthJourneyEntry, DoctorProfile, HospitalInfo, ChatConversation
} from './types';
import type { TestRequest, LabResult, PrescribedMedication, DoctorSignature } from './types';

const LS_KEY = (key: string) => `medicard_mock_${key}`;

const JAN: Patient = {
  id: 'patient-123',
  name: 'Russel Tsague',
  dateOfBirth: '1992-06-15T00:00:00Z',
  nationalId: 'MID-CM-9988-7766-5544',
  contactInfo: { phone: '+237 691 234 567', email: 'russel.tsague@tosumo.cm' },
  bloodType: 'O+',
  allergies: ['Penicillin', 'Peanuts', 'Ibuprofen'],
  chronicConditions: ['Mild Hypertension', 'Seasonal Asthma'],
  currentMeds: ['Lisinopril 10mg - 1x daily', 'Ventolin Inhaler - as needed'],
  emergencyContact: {
    name: 'Marie Tsague',
    relationship: 'Spouse',
    phone: '+237 699 876 543'
  },
  status: 'ACTIVE',
  gender: 'Male',
  photoUrl: undefined,
};

const now = Date.now();
const d = 86400000;

const journey: HealthJourneyEntry[] = [
  { id: 'hj1', patientId: 'patient-123', date: new Date(now - 240 * d).toISOString(), title: 'Medical Identity Created', subtitle: 'Your Digital Health Identity was established',     description: 'Vous avez rejoint TOSUMO et votre identité médicale a été créée. Vos informations personnelles, votre contact d\'urgence et vos antécédents médicaux ont été stockés et chiffrés de manière sécurisée. Votre carte médicale a été émise et est prête à être utilisée dans tous les établissements de santé partenaires.', category: 'identity', icon: 'CreditCard', status: 'completed', institution: 'Plateforme TOSUMO', doctorName: undefined },
  { id: 'hj2', patientId: 'patient-123', date: new Date(now - 235 * d).toISOString(), title: 'Identity Verified', subtitle: 'Your identity has been successfully verified',     description: 'Votre vérification d\'identité a été complétée avec succès. Votre photo, votre pièce d\'identité nationale et vos données biométriques ont été validées de manière sécurisée. Votre carte médicale est désormais entièrement activée et reconnue par tous les prestataires de soins du réseau TOSUMO.', category: 'identity', icon: 'ShieldCheck', status: 'completed', institution: 'Plateforme TOSUMO', doctorName: undefined },
  { id: 'hj3', patientId: 'patient-123', date: new Date(now - 220 * d).toISOString(), title: 'Annual Physical Examination', subtitle: 'Routine checkup at Clinique Bastos', description: 'Completed your annual physical examination. Height: 178cm, Weight: 82kg, BMI: 25.9. Blood work showed slightly elevated LDL cholesterol (3.4 mmol/L). Your doctor recommended dietary adjustments and increased physical activity. Overall health status: Good.', category: 'checkup', icon: 'Heart', status: 'completed', institution: 'Clinique Bastos', doctorName: 'Dr Jean-Pierre Ndzié' },
  { id: 'hj4', patientId: 'patient-123', date: new Date(now - 190 * d).toISOString(), title: 'First Consultation — Cardiology', subtitle: 'Initial cardiology assessment at Hôpital Central de Yaoundé', description: 'Referred to cardiology following annual physical. Dr Jean-Pierre Ndzié performed a comprehensive cardiac assessment including ECG, stress test, and blood pressure monitoring. Diagnosis: Mild Hypertension (Stage 1). Prescribed Lisinopril 10mg daily. Recommended low-sodium diet and 30 minutes of moderate exercise daily.', category: 'consultation', icon: 'Heart', status: 'completed', institution: 'Hôpital Central de Yaoundé', doctorName: 'Dr Jean-Pierre Ndzié' },
  { id: 'hj5', patientId: 'patient-123', date: new Date(now - 185 * d).toISOString(), title: 'Prescription Added — Lisinopril', subtitle: 'Blood pressure medication prescribed', description: 'Dr Jean-Pierre Ndzié prescribed Lisinopril 10mg — one tablet daily after breakfast for 90 days with 2 refills. Your prescription has been added to your Medical Booklet. You can view it anytime in the Prescriptions section.', category: 'prescription', icon: 'Pill', status: 'completed', institution: 'Hôpital Central de Yaoundé', doctorName: 'Dr Jean-Pierre Ndzié' },
  { id: 'hj6', patientId: 'patient-123', date: new Date(now - 180 * d).toISOString(), title: 'Dental Extraction — Wisdom Tooth', subtitle: 'Surgical procedure at Hôpital Central de Yaoundé', description: 'Underwent surgical extraction of lower right wisdom tooth under local anesthesia. Procedure was successful. Prescribed Amoxicillin 500mg (3x daily for 7 days) and Paracetamol for pain management. Healing was uneventful with follow-up after 2 weeks.', category: 'consultation', icon: 'Activity', status: 'completed', institution: 'Hôpital Central de Yaoundé', doctorName: 'Dr Emmanuel Ndzi' },
  { id: 'hj7', patientId: 'patient-123', date: new Date(now - 120 * d).toISOString(), title: 'Blood Test — Laboratory', subtitle: 'Comprehensive blood panel at Laboratoire MIMI', description: 'Routine blood work including complete blood count, lipid panel, liver function, kidney function, and HbA1c. Results showed slightly elevated LDL (3.4 mmol/L). All other values within normal range. Full results available in your Medical Booklet.', category: 'lab', icon: 'FlaskConical', status: 'completed', institution: 'Laboratoire MIMI', doctorName: undefined },
  { id: 'hj8', patientId: 'patient-123', date: new Date(now - 115 * d).toISOString(), title: 'Laboratory Results Received', subtitle: 'Blood test results uploaded to your Medical Booklet', description: 'Your laboratory results from Laboratoire MIMI are now available. Key findings: LDL Cholesterol: 3.4 mmol/L (elevated), HDL: 1.2 mmol/L (normal), Triglycerides: 1.5 mmol/L (normal), HbA1c: 5.2% (normal). Your doctor has been notified to review the results.', category: 'lab', icon: 'FlaskConical', status: 'completed', institution: 'Laboratoire MIMI', doctorName: 'Dr Jean-Pierre Ndzié' },
  { id: 'hj9', patientId: 'patient-123', date: new Date(now - 100 * d).toISOString(), title: 'Hôpital Central de Yaoundé — Standing Access Granted', subtitle: 'Ongoing access for your primary healthcare provider', description: 'You granted Hôpital Central de Yaoundé standing access to your full medical record. This ensures seamless care coordination with your primary healthcare team. They can view your complete medical history, current medications, allergies, and lab results. You can revoke this access at any time.', category: 'identity', icon: 'Shield', status: 'completed', institution: 'Hôpital Central de Yaoundé', doctorName: undefined },
  { id: 'hj10', patientId: 'patient-123', date: new Date(now - 90 * d).toISOString(), title: 'Vaccination — Influenza', subtitle: 'Seasonal flu vaccination at Hôpital Central de Yaoundé', description: 'Received the seasonal influenza vaccination. Vaccine administered intramuscularly in the left deltoid. No adverse reactions observed. Your vaccination record has been updated in your Medical Booklet.', category: 'vaccination', icon: 'Syringe', status: 'completed', institution: 'Hôpital Central de Yaoundé', doctorName: 'Infirmière Marie-Claire' },
  { id: 'hj11', patientId: 'patient-123', date: new Date(now - 75 * d).toISOString(), title: 'Respiratory Assessment — Pulmonology', subtitle: 'Asthma follow-up at CHU de Yaoundé', description: 'Follow-up assessment for seasonal asthma. Peak flow measured at 85% of personal best. Inhaler technique reviewed and corrected. Prescribed Symbicort 200/6 as maintenance therapy (2 inhalations twice daily). Follow-up scheduled in 3 months. Your asthma action plan has been updated.', category: 'consultation', icon: 'AlertCircle', status: 'completed', institution: 'CHU de Yaoundé', doctorName: 'Dr Fatou Ngassa' },
  { id: 'hj12', patientId: 'patient-123', date: new Date(now - 70 * d).toISOString(), title: 'Prescription Added — Symbicort', subtitle: 'Asthma maintenance medication prescribed', description: 'Dr Fatou Ngassa prescribed Symbicort 200/6 — 2 inhalations twice daily for 90 days with 1 refill. Previous Ventolin Inhaler prescription renewed with 3 refills as needed for acute symptoms.', category: 'prescription', icon: 'Pill', status: 'completed', institution: 'CHU de Yaoundé', doctorName: 'Dr Fatou Ngassa' },
  { id: 'hj13', patientId: 'patient-123', date: new Date(now - 60 * d).toISOString(), title: 'Allergy Consultation', subtitle: 'Comprehensive allergy panel testing', description: 'Referred to allergist following mild reaction to Ibuprofen. Comprehensive allergy panel testing conducted. Confirmed allergies: Penicillin (severe), Peanuts (moderate), Ibuprofen (mild). Prescribed Cetirizine 10mg for seasonal allergies. Emergency epinephrine auto-injector prescribed as precaution.', category: 'consultation', icon: 'Eye', status: 'completed', institution: 'Hôpital Central de Yaoundé', doctorName: 'Dr Christian Mbarga' },
  { id: 'hj14', patientId: 'patient-123', date: new Date(now - 45 * d).toISOString(), title: 'Centre Hospitalier — Consent Approved', subtitle: 'Access granted for respiratory specialist team', description: 'You approved a consent request from CHU de Yaoundé to access your critical information and current medications. This allows Dr Fatou Ngassa and the respiratory team to coordinate your asthma care effectively. Access expires in 30 days.', category: 'identity', icon: 'Shield', status: 'completed', institution: 'CHU de Yaoundé', doctorName: undefined },
  { id: 'hj15', patientId: 'patient-123', date: new Date(now - 30 * d).toISOString(), title: 'Cardiology Follow-up', subtitle: 'Blood pressure check — Annual cardiology review', description: 'Follow-up with Dr Jean-Pierre Ndzié. Blood pressure: 125/82 mmHg. Heart rate: 72 bpm. ECG normal. Lisinopril dosage maintained. You discussed your lab results and the slightly elevated LDL. Recommended continuing low-sodium diet and increasing exercise to 30-45 minutes daily.', category: 'consultation', icon: 'Heart', status: 'completed', institution: 'Hôpital Central de Yaoundé', doctorName: 'Dr Jean-Pierre Ndzié' },
  { id: 'hj16', patientId: 'patient-123', date: new Date(now - 15 * d).toISOString(), title: 'Prescription Refill — Lisinopril', subtitle: 'Blood pressure medication refill processed', description: 'Your Lisinopril 10mg prescription was refilled by Dr Jean-Pierre Ndzié for another 90 days with 2 remaining refills. Your medication history has been updated.', category: 'prescription', icon: 'Pill', status: 'completed', institution: 'Hôpital Central de Yaoundé', doctorName: 'Dr Jean-Pierre Ndzié' },
  { id: 'hj17', patientId: 'patient-123', date: new Date(now - 3 * d).toISOString(), title: 'Upcoming: Cardiology Appointment', subtitle: 'Scheduled follow-up in 3 days', description: 'Your next cardiology follow-up with Dr Jean-Pierre Ndzié is scheduled in 3 days at Hôpital Central de Yaoundé. Please remember to bring your current medication list and any questions about your treatment plan.', category: 'checkup', icon: 'Calendar', status: 'upcoming', institution: 'Hôpital Central de Yaoundé', doctorName: 'Dr Jean-Pierre Ndzié' },
  { id: 'hj18', patientId: 'patient-123', date: new Date(now + 11 * d).toISOString(), title: 'Upcoming: Respiratory Follow-up', subtitle: 'Asthma assessment scheduled', description: 'Your respiratory follow-up with Dr Fatou Ngassa is scheduled in 11 days at CHU de Yaoundé. Peak flow measurement and inhaler technique review will be conducted.', category: 'checkup', icon: 'Calendar', status: 'upcoming', institution: 'CHU de Yaoundé', doctorName: 'Dr Fatou Ngassa' },
  { id: 'hj19', patientId: 'patient-123', date: new Date(now + 60 * d).toISOString(), title: 'Insurance Integration (Coming Soon)', subtitle: 'Health insurance connectivity on the horizon',     description: 'TOSUMO se prépare à intégrer les assureurs santé. Vous pourrez bientôt lier votre police d\'assurance, soumettre des demandes de remboursement et gérer votre couverture directement depuis votre Identité Médicale Numérique.', category: 'insurance', icon: 'Shield', status: 'upcoming', institution: 'Plateforme TOSUMO', doctorName: undefined },
];

const sharedSignature: DoctorSignature = {
  doctorName: 'Dr Jean-Pierre Ndzié',
  licenseId: 'CM-MED-2024-8891',
  hospitalName: 'Hôpital Central de Yaoundé',
  signedAt: new Date(now - 30 * d).toISOString(),
};

const booklet: BookletEntry[] = [
  {
    id: 'b1', patientId: 'patient-123', visitDate: new Date(now - 30 * d).toISOString(),
    facility: 'Hôpital Central de Yaoundé', summary: 'Cardiology Follow-up — Annual Check',
    details: 'Blood pressure: 125/82 mmHg. Heart rate: 72 bpm. ECG normal. Lisinopril dosage maintained. Recommended low-sodium diet and 30min daily exercise. Reviewed recent lab results — LDL slightly elevated at 3.4 mmol/L. Continue current treatment plan.',
    doctorName: 'Dr Jean-Pierre Ndzié', doctorSpecialty: 'Cardiology',
    diagnosis: 'Hypertension Légère — Stable, Stade 1',
    prescription: 'Lisinopril 10mg — 1 tablet daily after breakfast (refilled for 90 days)',
    status: 'completed',
    consultationType: 'Suivi',
    symptoms: 'Patient reports feeling well overall. No chest pain, palpitations, or shortness of breath. Mild occasional headache in the morning, resolving after medication. No dizziness or syncope.',
    doctorNotes: 'Cardiovascular examination: Heart sounds S1+S2 normal, no murmurs or gallops. Peripheral pulses palpable bilaterally. BP measured at 125/82 mmHg seated, 122/80 mmHg standing. HR 72 bpm regular. ECG shows normal sinus rhythm, no ischemic changes. Patient is compliant with Lisinopril regimen. Lifestyle modifications discussed including low-sodium Mediterranean diet and 30-45 minutes moderate exercise 5 days per week. Reviewed lipid panel results — LDL at 3.4 mmol/L remains slightly elevated. Recommended increasing soluble fiber intake and considering plant sterols. No dose adjustment needed at this time. Patient to return in 6 months for routine follow-up or sooner if symptoms change.',
    testsRequested: [
      { name: 'Blood Test (CBC)', status: 'Completed' },
      { name: 'Lipid Panel', status: 'Completed' },
      { name: 'ECG', status: 'Completed' },
    ] as TestRequest[],
    labResults: [
      { testName: 'LDL Cholesterol', resultValue: '3.4 mmol/L', referenceRange: '< 3.0 mmol/L', interpretation: 'Abnormal', dateReceived: new Date(now - 35 * d).toISOString() },
      { testName: 'HDL Cholesterol', resultValue: '1.2 mmol/L', referenceRange: '> 1.0 mmol/L', interpretation: 'Normal', dateReceived: new Date(now - 35 * d).toISOString() },
      { testName: 'Triglycerides', resultValue: '1.5 mmol/L', referenceRange: '< 2.0 mmol/L', interpretation: 'Normal', dateReceived: new Date(now - 35 * d).toISOString() },
      { testName: 'HbA1c', resultValue: '5.2%', referenceRange: '< 5.7%', interpretation: 'Normal', dateReceived: new Date(now - 35 * d).toISOString() },
      { testName: 'Hemoglobin', resultValue: '14.2 g/dL', referenceRange: '13.0 — 17.0 g/dL', interpretation: 'Normal', dateReceived: new Date(now - 35 * d).toISOString() },
    ] as LabResult[],
    prescriptions: [
      { drugName: 'Lisinopril', dosage: '10mg', frequency: '1x daily', duration: '90 days', instructions: 'Take after breakfast with a full glass of water. Do not skip doses.' },
    ] as PrescribedMedication[],
    recommendations: 'Continue low-sodium diet (aim for < 2g sodium/day). Maintain 30-45 minutes of moderate aerobic exercise 5 times per week. Monitor blood pressure at home if possible. Increase dietary fiber intake to help manage LDL. Reduce alcohol consumption to no more than 1-2 units per day. Return for follow-up in 6 months or sooner if experiencing chest pain, severe headache, or visual changes.',
    signature: { ...sharedSignature, signedAt: new Date(now - 30 * d).toISOString() },
  },
  {
    id: 'b2', patientId: 'patient-123', visitDate: new Date(now - 75 * d).toISOString(),
    facility: 'CHU de Yaoundé', summary: 'Respiratory Assessment — Asthma Follow-up',
    details: 'Peak flow: 85% of personal best. Inhaler technique reviewed and corrected. Patient demonstrated proper usage. Prescribed Symbicort 200/6 as maintenance therapy. Advised to continue using Ventolin as needed for acute symptoms. Follow-up in 3 months.',
    doctorName: 'Dr Fatou Ngassa', doctorSpecialty: 'Pulmonology',
    diagnosis: 'Asthme Saisonnier — Bien Contrôlé',
    prescription: 'Symbicort 200/6 — 2 inhalations twice daily (90 days, 1 refill) | Ventolin Inhaler — as needed (3 refills)',
    attachments: 1, status: 'completed',
    consultationType: 'Suivi',
    symptoms: 'Patient reports mild wheezing in the early morning, particularly during cold weather. Occasional cough, non-productive. Nocturnal symptoms approximately once per week. Shortness of breath during moderate exercise (jogging) in cold air. Overall improvement since starting maintenance therapy.',
    doctorNotes: 'Respiratory examination: Chest auscultation reveals mild expiratory wheeze bilaterally, more pronounced in lower lobes. Peak expiratory flow measured at 85% of personal best (up from 72% at previous visit). Inhaler technique was observed: patient was using incorrect technique with Symbicort — instructed on proper coordination and breath-hold. Spacer device provided and technique demonstrated. Patient demonstrated correct usage after training. Symbicort 200/6 prescribed as maintenance therapy. Ventolin continued as rescue medication. Asthma action plan reviewed and updated with green/yellow/red zones. Advised to perform peak flow monitoring daily in the morning. Follow-up scheduled in 3 months with pulmonary function testing.',
    testsRequested: [
      { name: 'Peak Flow Measurement', status: 'Completed' },
      { name: 'Spirometry', status: 'Pending' },
    ] as TestRequest[],
    labResults: [
      { testName: 'Peak Expiratory Flow', resultValue: '85% of personal best (480 L/min)', referenceRange: '> 80% predicted', interpretation: 'Normal', dateReceived: new Date(now - 75 * d).toISOString() },
    ] as LabResult[],
    prescriptions: [
      { drugName: 'Symbicort', dosage: '200/6 mcg', frequency: '2 inhalations twice daily', duration: '90 days', instructions: 'Rinse mouth after each use. Use spacer device. Clean inhaler weekly.' },
      { drugName: 'Ventolin (Salbutamol)', dosage: '100 mcg', frequency: '1-2 puffs as needed', duration: 'As needed', instructions: 'Use for acute symptoms. Do not exceed 8 puffs per day. Seek medical attention if needing more than 3 times per week.' },
    ] as PrescribedMedication[],
    recommendations: 'Use Symbicort maintenance therapy consistently. Perform peak flow measurement every morning and record in diary. Avoid cold air exposure during high-exertion activities — consider wearing a scarf over mouth and nose in cold weather. Continue moderate exercise but warm up properly. If using Ventolin more than 3 times per week, contact the clinic. Return for spirometry in 3 months. Seek emergency care if peak flow drops below 60% of personal best or if symptoms do not improve with Ventolin.',
    signature: {
      doctorName: 'Dr Fatou Ngassa',
      licenseId: 'CM-MED-2023-4456',
      hospitalName: 'CHU de Yaoundé',
      signedAt: new Date(now - 75 * d).toISOString(),
    },
  },
  {
    id: 'b3', patientId: 'patient-123', visitDate: new Date(now - 60 * d).toISOString(),
    facility: 'Hôpital Central de Yaoundé', summary: 'General Consultation — Allergy Assessment',
    details: 'Patient reported mild reaction to Ibuprofen (skin rash). Comprehensive allergy panel testing conducted. Results confirmed: Penicillin (severe), Peanuts (moderate), Ibuprofen (mild). Prescribed antihistamine for seasonal allergies. Referred to allergist for comprehensive management plan. Emergency epinephrine auto-injector prescribed.',
    doctorName: 'Dr Christian Mbarga', doctorSpecialty: 'General Medicine',
    diagnosis: 'Allergies Médicamenteuses — Pénicilline (sévère), Ibuprofène (légère) | Rhinite Allergique Saisonnière',
    prescription: 'Cetirizine 10mg — 1 tablet daily as needed | Epinephrine Auto-injector — for emergency use only',
    status: 'follow-up',
    consultationType: 'Routine',
    symptoms: 'Patient developed a mild erythematous rash on the torso and arms approximately 2 hours after taking Ibuprofen for a headache. No urticaria, angioedema, or respiratory symptoms. Also reports seasonal allergic rhinitis symptoms including sneezing, nasal congestion, and itchy eyes during the pollen season. Previous history of penicillin allergy (severe reaction in childhood with swelling and difficulty breathing).',
    doctorNotes: 'Skin examination revealed a diffuse maculopapular rash on the trunk and proximal extremities, consistent with a mild drug eruption. No mucosal involvement. Vital signs stable. Comprehensive allergy panel (skin prick test) performed: Penicillin — strong positive (15mm wheal), Peanuts — moderate positive (8mm wheal), Ibuprofen — mild positive (4mm wheal), Seasonal pollens — moderate positive. Patient educated on avoidance of confirmed allergens. Emergency action plan developed for accidental exposure to penicillin or peanuts. Epinephrine auto-injector prescribed with detailed training on administration. Referral to allergist for desensitization consideration. Cetirizine prescribed for seasonal rhinitis symptoms. Patient advised to wear medical alert identification.',
    testsRequested: [
      { name: 'Allergy Panel (Skin Prick Test)', status: 'Completed' },
      { name: 'Serum IgE Levels', status: 'Pending' },
    ] as TestRequest[],
    labResults: [
      { testName: 'Skin Prick Test — Penicillin', resultValue: 'Strong positive (15mm wheal)', referenceRange: '> 3mm = positive', interpretation: 'Abnormal', dateReceived: new Date(now - 60 * d).toISOString() },
      { testName: 'Skin Prick Test — Peanuts', resultValue: 'Moderate positive (8mm wheal)', referenceRange: '> 3mm = positive', interpretation: 'Abnormal', dateReceived: new Date(now - 60 * d).toISOString() },
      { testName: 'Skin Prick Test — Ibuprofen', resultValue: 'Mild positive (4mm wheal)', referenceRange: '> 3mm = positive', interpretation: 'Abnormal', dateReceived: new Date(now - 60 * d).toISOString() },
    ] as LabResult[],
    prescriptions: [
      { drugName: 'Cetirizine', dosage: '10mg', frequency: '1x daily as needed', duration: 'As needed', instructions: 'Take in the evening if allergy symptoms present. May cause drowsiness.' },
      { drugName: 'Epinephrine Auto-injector', dosage: '0.3mg', frequency: 'Single dose for emergencies', duration: '1 use', instructions: 'Inject into outer thigh through clothing during severe allergic reaction. Call emergency services immediately after use. Carry at all times.' },
    ] as PrescribedMedication[],
    recommendations: 'Strictly avoid Penicillin and all penicillin-class antibiotics. Avoid Ibuprofen — use Paracetamol for pain relief instead. Avoid peanuts and peanut-containing foods. Read food labels carefully. Carry the epinephrine auto-injector at all times. Wear a medical alert bracelet indicating allergies (Penicillin, Peanuts, Ibuprofen). Inform all healthcare providers of your allergies before any treatment. Schedule allergist consultation for comprehensive management plan and possible desensitization. Follow-up in 2 weeks to review serum IgE results.',
    signature: {
      doctorName: 'Dr Christian Mbarga',
      licenseId: 'CM-MED-2022-3321',
      hospitalName: 'Hôpital Central de Yaoundé',
      signedAt: new Date(now - 60 * d).toISOString(),
    },
  },
  {
    id: 'b4', patientId: 'patient-123', visitDate: new Date(now - 220 * d).toISOString(),
    facility: 'Hôpital Général de Douala', summary: 'Emergency Visit — Acute Asthma Attack',
    details: 'Acute exacerbation triggered by cold air and physical exertion. Patient presented with wheezing, shortness of breath, and oxygen saturation of 94%. Treated with nebulized salbutamol and oral prednisolone. Chest X-ray clear. Observed for 6 hours. Discharged with modified asthma action plan and referral to pulmonology.',
    doctorName: 'Dr Marie Claire', doctorSpecialty: 'Emergency Medicine',
    diagnosis: 'Exacerbation Aiguë d\'Asthme — Sévérité Modérée',
    prescription: 'Prednisolone 40mg — 1 tablet daily for 5 days | Increased Ventolin usage as per action plan',
    status: 'completed',
    consultationType: 'Urgence',
    symptoms: 'Patient arrived at emergency department via private vehicle. Acute onset of shortness of breath, audible wheezing, and chest tightness after jogging in cold weather. Patient reported feeling his "throat was closing up." Difficulty speaking in full sentences. Cough productive of clear sputum. No fever. No cyanosis.',
    doctorNotes: 'Emergency assessment: Patient in moderate respiratory distress. Oxygen saturation 94% on room air. Respiratory rate 28/min. Heart rate 105 bpm. Blood pressure 135/85 mmHg. Temperature 36.8°C. Auscultation: diffuse expiratory wheeze bilaterally, prolonged expiration, accessory muscle use noted. Peak expiratory flow not obtainable due to distress. Immediate treatment: Nebulized salbutamol 5mg with oxygen at 6L/min via face mask — 3 doses 20 minutes apart. Significant improvement after second dose. Oral prednisolone 40mg administered. Chest X-ray performed — clear lung fields, no infiltrates, no pneumothorax. ECG: sinus tachycardia. Observed for 6 hours in emergency observation unit. By discharge: O2 saturation 97% on room air, speaking in full sentences, wheezing significantly reduced. Asthma action plan modified — cold air added as trigger. Referral to pulmonology for maintenance therapy optimization. Patient discharged with 5-day course of oral prednisolone and clear instructions to return if symptoms worsen.',
    testsRequested: [
      { name: 'Chest X-Ray', status: 'Completed' },
      { name: 'Complete Blood Count', status: 'Completed' },
      { name: 'Oxygen Saturation Monitoring', status: 'Completed' },
      { name: 'ECG', status: 'Completed' },
    ] as TestRequest[],
    labResults: [
      { testName: 'Chest X-Ray', resultValue: 'Clear lung fields, no infiltrates or pneumothorax', referenceRange: 'Normal', interpretation: 'Normal', dateReceived: new Date(now - 220 * d).toISOString() },
      { testName: 'White Blood Cell Count', resultValue: '8.2 x10^9/L', referenceRange: '4.0 — 11.0 x10^9/L', interpretation: 'Normal', dateReceived: new Date(now - 220 * d).toISOString() },
      { testName: 'Hemoglobin', resultValue: '14.5 g/dL', referenceRange: '13.0 — 17.0 g/dL', interpretation: 'Normal', dateReceived: new Date(now - 220 * d).toISOString() },
      { testName: 'ECG', resultValue: 'Sinus tachycardia (105 bpm), no ischemic changes', referenceRange: 'Normal sinus rhythm 60-100 bpm', interpretation: 'Abnormal', dateReceived: new Date(now - 220 * d).toISOString() },
    ] as LabResult[],
    prescriptions: [
      { drugName: 'Prednisolone', dosage: '40mg', frequency: '1x daily', duration: '5 days', instructions: 'Take with food in the morning. Do not stop abruptly. Complete the full course.' },
      { drugName: 'Salbutamol (Ventolin)', dosage: '100 mcg', frequency: '2 puffs every 4-6 hours as needed', duration: 'As needed', instructions: 'Use inhaler with spacer. If requiring more than every 4 hours, return to emergency department.' },
    ] as PrescribedMedication[],
    recommendations: 'Complete the full 5-day course of prednisolone even if symptoms improve. Use Ventolin inhaler as directed for symptom relief. Rest for the next 48 hours — avoid physical exertion and cold air exposure. If symptoms worsen or Ventolin is needed more than every 4 hours, return to emergency immediately. Schedule follow-up with pulmonology within 1 week. Update your asthma action plan with the new trigger (cold air + exertion). Consider using a scarf over nose and mouth in cold weather. Continue regular maintenance therapy as previously prescribed.',
    signature: {
      doctorName: 'Dr Marie Claire',
      licenseId: 'CM-MED-2021-7788',
      hospitalName: 'Hôpital Général de Douala',
      signedAt: new Date(now - 220 * d).toISOString(),
    },
  },
  {
    id: 'b5', patientId: 'patient-123', visitDate: new Date(now - 180 * d).toISOString(),
    facility: 'Hôpital Central de Yaoundé', summary: 'Dental Extraction — Lower Right Wisdom Tooth',
    details: 'Surgical extraction of lower right wisdom tooth (tooth #48) under local anesthesia (2% Lidocaine with epinephrine). Procedure duration: 45 minutes. Surgical site closed with absorbable sutures. Post-operative instructions provided. Healing uneventful. Follow-up at 2 weeks showed complete healing.',
    doctorName: 'Dr Emmanuel Ndzi', doctorSpecialty: 'Dentistry',
    diagnosis: 'Dent de Sagesse Incluse — Inférieure Droite',
    prescription: 'Amoxicillin 500mg — 1 capsule 3x daily for 7 days | Paracetamol 500mg — 2 tablets every 6h as needed for pain',
    attachments: 2, status: 'completed',
    consultationType: 'Routine',
    symptoms: 'Patient reported intermittent pain in the lower right jaw for approximately 3 months, worsening over the past 2 weeks. Pain exacerbated by chewing and pressure on the area. Mild swelling of the gum tissue around the partially erupted wisdom tooth. No fever. No trismus.',
    doctorNotes: 'Pre-operative assessment: Oral examination reveals partially erupted lower right wisdom tooth (tooth #48) with pericoronitis. Mild erythema and swelling of the operculum. No purulent discharge. Panoramic radiograph shows mesioangular impaction with adequate bone support. No evidence of cyst or pathology. Procedure: Surgical extraction performed under local anesthesia (2% Lidocaine with 1:100,000 epinephrine — 3.6 mL via inferior alveolar nerve block and buccal infiltration). Incision, flap reflection, bone removal with surgical bur, tooth sectioning and elevation. Tooth removed in two pieces. Surgical site curetted, irrigated with sterile saline. Closure with 3-0 silk sutures. Hemostasis achieved. Duration: 45 minutes. Patient tolerated procedure well. Post-operative instructions provided verbally and in writing. Patient prescribed Amoxicillin for infection prophylaxis and Paracetamol for pain. Follow-up appointment scheduled in 14 days for suture removal and healing assessment.',
    testsRequested: [
      { name: 'Panoramic Dental X-Ray (Orthopantomogram)', status: 'Completed' },
    ] as TestRequest[],
    labResults: [
      { testName: 'Panoramic Radiograph', resultValue: 'Mesioangular impacted tooth #48. No pathology, adequate bone support.', referenceRange: 'Normal', interpretation: 'Normal', dateReceived: new Date(now - 180 * d).toISOString() },
    ] as LabResult[],
    prescriptions: [
      { drugName: 'Amoxicillin', dosage: '500mg', frequency: '3x daily', duration: '7 days', instructions: 'Take with water. Complete the full course even if symptoms improve. Avoid alcohol.' },
      { drugName: 'Paracetamol', dosage: '500mg', frequency: 'Every 6 hours as needed', duration: 'As needed for pain', instructions: 'Do not exceed 8 tablets (4g) in 24 hours. Take with food.' },
    ] as PrescribedMedication[],
    recommendations: 'Apply ice pack to the cheek for the first 24 hours (20 minutes on, 20 minutes off). Do not rinse mouth vigorously or spit for the first 24 hours. Soft food diet for 3-5 days. Avoid hot foods and drinks for 24 hours. Do not use a straw for 1 week. Start gentle salt water rinses after 24 hours (warm salt water, 3 times daily). Take all prescribed medications as directed. Avoid smoking and alcohol for at least 72 hours. Brushing: avoid the surgical site for 3 days, then gently clean surrounding teeth. If bleeding persists, apply gentle pressure with a clean gauze for 20 minutes. Return for suture removal in 14 days. Contact the clinic immediately if experiencing severe pain, fever, excessive bleeding, or signs of infection.',
    signature: {
      doctorName: 'Dr Emmanuel Ndzi',
      licenseId: 'CM-MED-2020-5543',
      hospitalName: 'Hôpital Central de Yaoundé',
      signedAt: new Date(now - 180 * d).toISOString(),
    },
  },
  {
    id: 'b6', patientId: 'patient-123', visitDate: new Date(now - 220 * d).toISOString(),
    facility: 'Clinique Bastos', summary: 'Annual Physical Examination',
    details: 'Comprehensive annual physical examination. Height: 178cm. Weight: 82kg. BMI: 25.9 (Overweight). Blood pressure: 128/84 mmHg. Heart sounds normal. Lungs clear. Blood work results: LDL 3.4 mmol/L (elevated), HDL 1.2 mmol/L (normal), Triglycerides 1.5 mmol/L (normal), HbA1c 5.2% (normal). Recommended: Low-sodium Mediterranean diet, 30-45 minutes moderate exercise 5x/week, reduce alcohol intake.',
    doctorName: 'Dr Jean-Pierre Ndzié', doctorSpecialty: 'Internal Medicine',
    diagnosis: 'Surpoids (IMC 25.9) | Hyperlipidémie Limite',
    prescription: 'Dietary and lifestyle modifications recommended. No medication prescribed.',
    attachments: 1, status: 'completed',
    consultationType: 'Routine',
    symptoms: 'Patient reports no specific complaints. General health is good. Occasional mild fatigue in the afternoon, attributed to work stress. Sleep quality adequate (7 hours/night). Exercise routine inconsistent (walks occasionally, no structured exercise program). Diet includes frequent processed foods and red meat 4-5 times per week.',
    doctorNotes: 'Comprehensive annual physical examination performed. Vital signs: BP 128/84 mmHg (within normal range), HR 76 bpm regular, RR 14/min, Temp 36.6°C. Physical measurements: Height 178cm, Weight 82kg, BMI 25.9 (overweight). Waist circumference 96cm (elevated — > 94cm indicates increased cardiovascular risk). Head and neck: normal. Cardiovascular: heart sounds S1+S2 normal, no murmurs or bruits. Peripheral pulses intact. Respiratory: clear breath sounds bilaterally, no wheezes or crackles. Abdominal: soft, non-tender, no organomegaly. Musculoskeletal: full range of motion all joints. Neurological: cranial nerves intact, normal gait, reflexes normal. Skin: no lesions or abnormalities. Blood work results reviewed. LDL 3.4 mmol/L is elevated (target < 3.0 mmol/L). Other parameters within normal range. Discussed lifestyle modifications at length: Mediterranean diet, reduced sodium intake, structured exercise program, alcohol moderation. Patient motivated and willing to make changes. No medication indicated at this stage. Follow-up in 6 months for repeat lipid panel and weight assessment.',
    testsRequested: [
      { name: 'Complete Blood Count', status: 'Completed' },
      { name: 'Lipid Panel', status: 'Completed' },
      { name: 'Liver Function Test', status: 'Completed' },
      { name: 'Kidney Function Test', status: 'Completed' },
      { name: 'HbA1c', status: 'Completed' },
      { name: 'Urinalysis', status: 'Completed' },
    ] as TestRequest[],
    labResults: [
      { testName: 'LDL Cholesterol', resultValue: '3.4 mmol/L', referenceRange: '< 3.0 mmol/L', interpretation: 'Abnormal', dateReceived: new Date(now - 220 * d).toISOString() },
      { testName: 'HDL Cholesterol', resultValue: '1.2 mmol/L', referenceRange: '> 1.0 mmol/L', interpretation: 'Normal', dateReceived: new Date(now - 220 * d).toISOString() },
      { testName: 'Triglycerides', resultValue: '1.5 mmol/L', referenceRange: '< 2.0 mmol/L', interpretation: 'Normal', dateReceived: new Date(now - 220 * d).toISOString() },
      { testName: 'HbA1c', resultValue: '5.2%', referenceRange: '< 5.7%', interpretation: 'Normal', dateReceived: new Date(now - 220 * d).toISOString() },
      { testName: 'ALT (Liver)', resultValue: '28 U/L', referenceRange: '10 — 40 U/L', interpretation: 'Normal', dateReceived: new Date(now - 220 * d).toISOString() },
      { testName: 'Creatinine (Kidney)', resultValue: '82 umol/L', referenceRange: '60 — 110 umol/L', interpretation: 'Normal', dateReceived: new Date(now - 220 * d).toISOString() },
      { testName: 'Urinalysis', resultValue: 'No abnormalities detected', referenceRange: 'Normal', interpretation: 'Normal', dateReceived: new Date(now - 220 * d).toISOString() },
    ] as LabResult[],
    prescriptions: [] as PrescribedMedication[],
    recommendations: 'Implement Mediterranean diet: increase vegetables, fruits, whole grains, legumes, fish (2-3 times/week), nuts and seeds. Reduce red meat to 1-2 times per week. Limit processed foods, sugary drinks, and foods high in saturated fat. Reduce sodium intake to less than 2g per day. Begin a structured exercise program: 30-45 minutes of moderate aerobic activity (brisk walking, cycling, swimming) 5 days per week, plus strength training 2 days per week. Aim to reduce body weight by 5-7% (approximately 4-6 kg) over the next 6 months. Limit alcohol to no more than 2 standard drinks per day. Maintain adequate hydration (8 glasses of water daily). Sleep hygiene: maintain consistent sleep schedule. Schedule follow-up in 6 months for repeat anthropometric measurements and lipid panel.',
    signature: {
      doctorName: 'Dr Jean-Pierre Ndzié',
      licenseId: 'CM-MED-2019-2210',
      hospitalName: 'Clinique Bastos',
      signedAt: new Date(now - 220 * d).toISOString(),
    },
  },
  {
    id: 'b7', patientId: 'patient-123', visitDate: new Date(now - 60 * d).toISOString(),
    facility: 'Hôpital Central de Yaoundé', summary: 'Consultation Allergologie — Bilan complet',
    details: 'Patient adressé suite à une réaction au Cours de l\'Ibuprofène. Bilan allergologique complet réalisé : tests cutanés et dosage des IgE spécifiques. Allergies confirmées : Pénicilline (sévère), Arachides (modérée), Ibuprofène (légère). Prescrit : Cétirizine 10mg pour les allergies saisonnières. Stylo auto-injecteur d\'adrénaline prescrit en précaution.',
    doctorName: 'Dr Christian Mbarga', doctorSpecialty: 'Allergologie',
    diagnosis: 'Allergie à la Pénicilline (sévère) | Allergie aux Arachides (modérée) | Intolérance à l\'Ibuprofène (légère)',
    prescription: 'Cétirizine 10mg — 1 comprimé par jour si besoin | Stylo auto-injecteur d\'adrénaline — usage d\'urgence',
    status: 'completed',
    consultationType: 'Routine',
    symptoms: 'Patient rapporte une réaction cutanée (urticaire généralisée) après prise d\'Ibuprofène il y a 3 mois. Antécédent d\'œdème de Quincke sous Pénicilline dans l\'enfance. Sensation de picotement buccal après consommation d\'arachides.',
    doctorNotes: 'Examen dermatologique : quelques lésions urticariennes résiduelles aux avant-bras. Muqueuses saines. Tests cutanés : positif à la Pénicilline (papule de 12mm), positif aux extraits d\'arachide (papule de 8mm). IgE spécifiques : Pénicilline >100 kU/L, Arachides 25 kU/L. Diagnostic d\'allergie confirmé. Prescription d\'un auto-injecteur d\'adrénaline (Epipen) pour l\'allergie à la Pénicilline. Conseil d\'éviction stricte des arachides et des dérivés. Éducation du patient sur la reconnaissance des signes précoces d\'anaphylaxie.',
    testsRequested: [
      { name: 'Tests cutanés (Prick tests) — Standard', status: 'Completed' },
      { name: 'IgE spécifiques — Pénicilline', status: 'Completed' },
      { name: 'IgE spécifiques — Arachides', status: 'Completed' },
      { name: 'IgE spécifiques — Ibuprofène', status: 'Completed' },
    ] as TestRequest[],
    labResults: [
      { testName: 'IgE Pénicilline', resultValue: '>100 kU/L', referenceRange: '< 0.35 kU/L', interpretation: 'Abnormal', dateReceived: new Date(now - 60 * d).toISOString() },
      { testName: 'IgE Arachides', resultValue: '25 kU/L', referenceRange: '< 0.35 kU/L', interpretation: 'Abnormal', dateReceived: new Date(now - 60 * d).toISOString() },
      { testName: 'IgE Ibuprofène', resultValue: '3.2 kU/L', referenceRange: '< 0.35 kU/L', interpretation: 'Abnormal', dateReceived: new Date(now - 60 * d).toISOString() },
      { testName: 'IgE Totales', resultValue: '180 kU/L', referenceRange: '< 100 kU/L', interpretation: 'Abnormal', dateReceived: new Date(now - 60 * d).toISOString() },
    ] as LabResult[],
    prescriptions: [
      { drugName: 'Cétirizine', dosage: '10mg', frequency: '1x par jour si besoin', duration: 'Si besoin', instructions: 'Prendre le soir en cas de symptômes allergiques. Peut causer une somnolence.' },
      { drugName: 'Adrénaline Auto-Injecteur', dosage: '0.3mg', frequency: 'Usage d\'urgence uniquement', duration: '1 dose', instructions: 'Injecter dans la face externe de la cuisse en cas de réaction allergique sévère. Appeler les urgences immédiatement après utilisation.' },
    ] as PrescribedMedication[],
    recommendations: 'Éviction stricte de la Pénicilline et des pénicillines semi-synthétiques. Éviction des arachides et produits en contenant (lire attentivement les étiquettes alimentaires). Éviter l\'Ibuprofène et les AINS. Toujours porter l\'auto-injecteur d\'adrénaline sur soi. Informer tout professionnel de santé de vos allergies avant tout traitement. Porter un bracelet d\'alerte médicale. Consulter en urgence en cas de : gonflement du visage/gorge, difficulté à respirer, urticaire généralisée, chute de tension. Remplacement conseillé de l\'Ibuprofène par le Paracétamol pour la gestion de la douleur et de la fièvre.',
    signature: {
      doctorName: 'Dr Christian Mbarga',
      licenseId: 'CM-MED-2022-3321',
      hospitalName: 'Hôpital Central de Yaoundé',
      signedAt: new Date(now - 60 * d).toISOString(),
    },
  },
  {
    id: 'b8', patientId: 'patient-123', visitDate: new Date(now - 90 * d).toISOString(),
    facility: 'Hôpital Central de Yaoundé', summary: 'Vaccination — Grippe Saisonnière',
    details: 'Administration du vaccin antigrippal saisonnier. Vaccin administré par voie intramusculaire dans le deltoïde gauche. Aucune réaction adverse observée pendant la période de surveillance de 15 minutes. Le carnet de vaccination a été mis à jour.',
    doctorName: 'Infirmière Marie-Claire', doctorSpecialty: 'Soins Infirmiers',
    diagnosis: 'Vaccination de routine — Grippe saisonnière',
    prescription: '',
    attachments: 0, status: 'completed',
    consultationType: 'Routine',
    symptoms: 'Aucun symptôme. Vaccination de routine pour la saison grippale.',
    doctorNotes: 'Vaccination antigrippale administrée sans complication. Patient asymptomatique. Prochaine dose recommandée : saison grippale suivante (avril-mai 2027).',
    testsRequested: [] as TestRequest[],
    labResults: [] as LabResult[],
    prescriptions: [] as PrescribedMedication[],
    recommendations: 'Surveiller l\'apparition de tout symptôme inhabituel dans les 48 heures (fièvre, douleur au point d\'injection, fatigue). Un léger induration au point d\'injection est normal. Repos si nécessaire. Boire beaucoup d\'eau.',
    signature: {
      doctorName: 'Infirmière Marie-Claire',
      licenseId: 'CM-NUR-2023-4412',
      hospitalName: 'Hôpital Central de Yaoundé',
      signedAt: new Date(now - 90 * d).toISOString(),
    },
  },
];

const grants: AccessGrant[] = [
  { id: 'g1', patientId: 'patient-123', institutionId: 'inst-1', institutionName: 'Hôpital Central de Yaoundé', mode: 'STANDING', scope: 'Full Medical Record', status: 'ACTIVE', grantedAt: new Date(now - 100 * d).toISOString(), expiresAt: null },
  { id: 'g2', patientId: 'patient-123', institutionId: 'inst-2', institutionName: 'CHU de Yaoundé', mode: 'CONSENTED', scope: 'Critical Information & Current Medications', status: 'ACTIVE', grantedAt: new Date(now - 45 * d).toISOString(), expiresAt: new Date(now + 30 * d).toISOString() },
  { id: 'g3', patientId: 'patient-123', institutionId: 'inst-3', institutionName: 'Pharmacie de la Cité Verte', mode: 'CONSENTED', scope: 'Prescription History', status: 'PENDING', grantedAt: '', expiresAt: new Date(now + 7 * d).toISOString() },
  { id: 'g4', patientId: 'patient-123', institutionId: 'inst-4', institutionName: 'Laboratoire MIMI', mode: 'CONSENTED', scope: 'Lab Results Only', status: 'EXPIRED', grantedAt: new Date(now - 120 * d).toISOString(), expiresAt: new Date(now - 30 * d).toISOString() },
  { id: 'g5', patientId: 'patient-123', institutionId: 'inst-5', institutionName: 'Hôpital Général de Douala', mode: 'EMERGENCY', scope: 'Emergency Critical Subset', status: 'EXPIRED', grantedAt: new Date(now - 220 * d).toISOString(), expiresAt: new Date(now - 217 * d).toISOString() },
];

const audit: AuditEvent[] = [
  { id: 'a1', patientId: 'patient-123', accessorId: 'dr-zeukang', accessorName: 'Dr Jean-Pierre Ndzié', timestamp: new Date(now - 2 * 3600000).toISOString(), mode: 'CONSENTED', action: 'VIEW', details: 'Viewed your full medical record during cardiology consultation', category: 'Medical Record', location: 'Hôpital Central de Yaoundé', doctorName: 'Dr Jean-Pierre Ndzié' },
  { id: 'a2', patientId: 'patient-123', accessorId: 'inst-1', accessorName: 'Hôpital Central de Yaoundé', timestamp: new Date(now - 86400000).toISOString(), mode: 'STANDING', action: 'VIEW', details: 'Routine access via standing consent — pharmacy refill check', category: 'Medication', location: 'Hôpital Central de Yaoundé', patientPresent: false },
  { id: 'a3', patientId: 'patient-123', accessorId: 'patient-123', accessorName: 'Vous (Patient)', timestamp: new Date(now - 172800000).toISOString(), mode: 'CONSENTED', action: 'GRANT', details: 'Vous avez approuvé l\'accès pour le CHU de Yaoundé à vos informations critiques et médicaments actuels.', category: 'Consent', location: 'Application TOSUMO' },
  { id: 'a4', patientId: 'patient-123', accessorId: 'inst-3', accessorName: 'Pharmacie de la Cité Verte', timestamp: new Date(now - 259200000).toISOString(), mode: 'CONSENTED', action: 'REQUEST', details: 'Pharmacie de la Cité Verte has requested access to your prescription history for medication dispensing.', category: 'Consent', location: 'Pharmacie de la Cité Verte, Yaoundé' },
  { id: 'a5', patientId: 'patient-123', accessorId: 'patient-123', accessorName: 'Vous (Patient)', timestamp: new Date(now - 345600000).toISOString(), mode: 'CONSENTED', action: 'REVOKE', details: 'Vous avez révoqué l\'accès du Laboratoire MIMI après l\'expiration de leur autorisation.', category: 'Consent', location: 'Application TOSUMO' },
  { id: 'a6', patientId: 'patient-123', accessorId: 'dr-emergency', accessorName: 'Dr Marie Claire (Emergency)', timestamp: new Date(now - 220 * d).toISOString(), mode: 'EMERGENCY', action: 'VIEW', details: 'EMERGENCY ACCESS — Acute asthma attack. Accessed critical medical data: allergies, blood type, emergency contact, current medications.', category: 'Emergency', location: 'Hôpital Général de Douala', reason: 'Road Accident — Asthma Attack', doctorName: 'Dr Marie Claire', patientPresent: true },
  { id: 'a7', patientId: 'patient-123', accessorId: 'inst-4', accessorName: 'Laboratoire MIMI', timestamp: new Date(now - 120 * d).toISOString(), mode: 'CONSENTED', action: 'VIEW', details: 'Viewed lab results and uploaded comprehensive blood panel results to your Medical Booklet.', category: 'Laboratory', location: 'Laboratoire MIMI', patientPresent: true },
  { id: 'a8', patientId: 'patient-123', accessorId: 'patient-123', accessorName: 'Vous (Patient)', timestamp: new Date(now - 86400000).toISOString(), mode: 'CONSENTED', action: 'VIEW', details: 'Vous avez consulté votre Carte Médicale (QR code scanné pour vérification d\'identité à la Pharmacie de la Cité Verte).', category: 'Identity', location: 'Application TOSUMO' },
  { id: 'a9', patientId: 'patient-123', accessorId: 'inst-3', accessorName: 'Pharmacie de la Cité Verte', timestamp: new Date(now - 3600000).toISOString(), mode: 'CONSENTED', action: 'VIEW', details: 'Verified patient identity via QR code and dispensed Lisinopril 15mg (90 tablets).', category: 'Medication', location: 'Pharmacie de la Cité Verte, Yaoundé', patientPresent: true },
  { id: 'a10', patientId: 'patient-123', accessorId: 'dr-zeukang', accessorName: 'Dr Jean-Pierre Ndzié', timestamp: new Date(now - 10 * d).toISOString(), mode: 'CONSENTED', action: 'VIEW', details: 'Reviewed lab results and prescribed updated Lisinopril dosage (15mg).', category: 'Medical Record', location: 'Hôpital Central de Yaoundé', doctorName: 'Dr Jean-Pierre Ndzié' },
];

const card: Card = {
  patientId: 'patient-123',
  token: 'MC-CM-9988-7766-5544',
  status: 'ACTIVE',
  issuedAt: '2025-11-10T08:00:00Z',
};

const appointments = [
  { id: 'appt-1', doctorName: 'Dr Jean-Pierre Ndzié', specialty: 'Cardiologie', date: new Date(now + 3 * d).toISOString(), location: 'Hôpital Central de Yaoundé', status: 'confirmed' },
  { id: 'appt-2', doctorName: 'Dr Fatou Ngassa', specialty: 'Pneumologie', date: new Date(now + 14 * d).toISOString(), location: 'CHU de Yaoundé', status: 'pending' },
  { id: 'appt-3', doctorName: 'Dr Christian Mbarga', specialty: 'Médecine Générale', date: new Date(now + 21 * d).toISOString(), location: 'Hôpital Central de Yaoundé', status: 'confirmed' },
  { id: 'appt-4', doctorName: 'Dr Emmanuel Ndzi', specialty: 'Dentisterie', date: new Date(now + 45 * d).toISOString(), location: 'Hôpital Central de Yaoundé', status: 'pending' },
  { id: 'appt-5', doctorName: 'Dr Marie Claire', specialty: 'Médecine d\'Urgence', date: new Date(now - 220 * d).toISOString(), location: 'Hôpital Général de Douala', status: 'completed' },
];

const prescriptions = [
  { id: 'rx-1', doctorName: 'Dr Jean-Pierre Ndzié', specialty: 'Cardiologie', medications: [{ name: 'Lisinopril 10mg', dosage: '1 comprimé par jour après le petit-déjeuner', duration: '90 jours', refills: 2 }], date: new Date(now - 15 * d).toISOString(), status: 'active' },
  { id: 'rx-2', doctorName: 'Dr Fatou Ngassa', specialty: 'Pneumologie', medications: [{ name: 'Symbicort 200/6', dosage: '2 inhalations deux fois par jour', duration: '90 jours', refills: 1 }, { name: 'Ventolin Inhaler', dosage: '1-2 bouffées au besoin en cas d\'essoufflement', duration: 'au besoin', refills: 3 }], date: new Date(now - 70 * d).toISOString(), status: 'active' },
  { id: 'rx-3', doctorName: 'Dr Emmanuel Ndzi', specialty: 'Dentisterie', medications: [{ name: 'Amoxicilline 500mg', dosage: '1 gélule 3x par jour pendant 7 jours', duration: '7 jours', refills: 0 }], date: new Date(now - 180 * d).toISOString(), status: 'completed' },
  { id: 'rx-4', doctorName: 'Dr Christian Mbarga', specialty: 'Allergologie', medications: [{ name: 'Cétirizine 10mg', dosage: '1 comprimé par jour au besoin pour les symptômes allergiques', duration: 'au besoin', refills: 2 }, { name: 'Auto-injecteur d\'Adrénaline', dosage: 'Injecter dans la cuisse en cas de réaction allergique sévère — usage d\'urgence uniquement', duration: '1 dose', refills: 1 }], date: new Date(now - 60 * d).toISOString(), status: 'active' },
];

const notifications = [
  { id: 'n1', type: 'access_request', title: 'Demande d\'accès en attente', message: 'Pharmacie de la Cité Verte demande l\'accès à votre historique d\'ordonnances pour préparer vos médicaments.', time: new Date(now - 3600000).toISOString(), read: false },
  { id: 'n2', type: 'card_update', title: 'Carte médicale vérifiée', message: 'Votre identité médicale numérique a été vérifiée. Votre carte TOSUMO est désormais active sur tout le réseau.', time: new Date(now - 86400000).toISOString(), read: false },
  { id: 'n3', type: 'appointment', title: 'Rappel de rendez-vous', message: 'Votre consultation de cardiologie avec Dr Jean-Pierre Ndzié est dans 3 jours. Pensez à apporter votre liste de médicaments.', time: new Date(now - 172800000).toISOString(), read: true },
  { id: 'n4', type: 'prescription', title: 'Renouvellement d\'ordonnance', message: 'Votre prescription de Lisinopril 10mg a été renouvelée par Dr Jean-Pierre Ndzié. 2 renouvellements restants.', time: new Date(now - 15 * d).toISOString(), read: true },
  { id: 'n5', type: 'access_granted', title: 'Accès approuvé', message: 'Vous avez accordé l\'accès à vos informations médicales critiques au CHU de Yaoundé. Vous pouvez révoquer cet accès à tout moment.', time: new Date(now - 45 * d).toISOString(), read: true },
  { id: 'n6', type: 'lab_result', title: 'Résultats d\'analyses disponibles', message: 'Vos résultats d\'analyses sanguines du Laboratoire MIMI sont disponibles dans votre carnet médical.', time: new Date(now - 115 * d).toISOString(), read: true },
  { id: 'n7', type: 'emergency', title: 'Accès d\'urgence enregistré', message: 'Dr Marie Claire à l\'Hôpital Général de Douala a accédé à vos informations médicales d\'urgence lors de votre crise d\'asthme.', time: new Date(now - 220 * d).toISOString(), read: true },
  { id: 'n8', type: 'access_request', title: 'Nouvelle demande d\'accès', message: 'Clinique Bastos demande l\'accès à votre dossier médical complet pour votre suivi annuel.', time: new Date(now - 7200000).toISOString(), read: false },
  { id: 'n9', type: 'appointment', title: 'Rendez-vous dentaire confirmé', message: 'Votre rendez-vous chez Dr Emmanuel Ndzi pour extraction dentaire est confirmé pour le 15 août à 11h.', time: new Date(now - 2 * d).toISOString(), read: false },
  { id: 'n10', type: 'prescription', title: 'Nouvelle ordonnance disponible', message: 'Dr Fatou Ngassa a prescrit Symbicort 200/6. Voir les détails dans votre carnet médical.', time: new Date(now - 70 * d).toISOString(), read: true },
  { id: 'n11', type: 'lab_result', title: 'Nouveau résultat d\'imagerie', message: 'Les résultats de votre échographie cardiaque sont disponibles. Aucune anomalie détectée.', time: new Date(now - 10 * d).toISOString(), read: false },
  { id: 'n12', type: 'system', title: 'Mise à jour de sécurité', message: 'Votre application a été mise à jour avec les derniers protocoles de sécurité. Vos données sont protégées.', time: new Date(now - 5 * d).toISOString(), read: true },
];

const doctors: DoctorProfile[] = [
  {
    id: 'doc-1', name: 'Dr Jean-Pierre Ndzié', specialty: 'Cardiologie',
    rating: 4.9, reviewCount: 127, yearsExperience: 12, patientCount: 1850,
    bio: 'Le Dr Jean-Pierre Ndzié est un cardiologue certifié avec plus de 12 ans d\'expérience en cardiologie préventive, gestion de l\'hypertension et réadaptation cardiaque. Il a obtenu son diplôme de médecine à l\'Université de Yaoundé I et a effectué son fellowship en cardiologie à l\'Université de Cape Town. Le Dr Ndzié est reconnu pour son approche centrée sur le patient et sa communication claire.',
    languages: ['English', 'French', 'Ewondo'], hospital: 'Hôpital Central de Yaoundé', hospitalLocation: 'Yaoundé, Cameroon',
    consultationTypes: ['In-person', 'Video Call', 'Phone Consultation'],
    nextAvailableSlot: 'Tomorrow at 9:00 AM', availableToday: true,
    reviews: [
      { name: 'Marie T.', rating: 5, text: 'Excellent cardiologue. Le Dr Ndzié a pris le temps d\'expliquer ma condition et les options de traitement clairement. Je recommande vivement.', date: 'Il y a 2 semaines' },
      { name: 'Pierre N.', rating: 5, text: 'Examen très approfondi. Il a écouté toutes mes préoccupations et ajusté mon traitement approprié. Ma tension est maintenant bien contrôlée.', date: 'Il y a 1 mois' },
      { name: 'Sophie K.', rating: 4, text: 'Professionnel et attentionné. La consultation était complète. Temps d\'attente minime.', date: 'Il y a 2 mois' },
    ],
    credentials: ['Doctorat en Médecine, Université de Yaoundé I', 'Fellowship en Cardiologie, Université de Cape Town', 'Certifié — Conseil Médical du Cameroun', 'Membre — Fondation Africaine du Cœur'],
    expertise: ['Gestion de l\'Hypertension', 'Prévention des Maladies Cardiaques', 'Réadaptation Cardiaque', 'Interprétation ECG', 'Échocardiographie'],
  },
  {
    id: 'doc-2', name: 'Dr Fatou Ngassa', specialty: 'Pneumologie',
    rating: 4.8, reviewCount: 93, yearsExperience: 8, patientCount: 1200,
    bio: 'Le Dr Fatou Ngassa est une pneumologue dévouée spécialisée dans la gestion de l\'asthme, les soins BPCO et la réadaptation respiratoire. Elle a été formée à l\'Université de Douala et a complété son fellowship en médecine respiratoire à l\'Hospital de la Santa Creu i Sant Pau à Barcelone. Elle est passionnée par l\'éducation et la prévention de l\'asthme.',
    languages: ['English', 'French', 'Spanish'], hospital: 'CHU de Yaoundé', hospitalLocation: 'Yaoundé, Cameroon',
    consultationTypes: ['In-person', 'Video Call'],
    nextAvailableSlot: 'Next week Monday', availableToday: false,
    reviews: [
      { name: 'Jean-Paul M.', rating: 5, text: 'Le Dr Ngassa a transformé ma gestion de l\'asthme. Sa formation sur la technique d\'inhalation a été incroyablement utile. Je me sens maintenant en contrôle de ma condition.', date: 'Il y a 3 semaines' },
      { name: 'Claire B.', rating: 4, text: 'Très compétente sur les conditions respiratoires. Le suivi a été excellent.', date: 'Il y a 1 mois' },
    ],
    credentials: ['Doctorat en Médecine, Université de Douala', 'Fellowship en Médecine Respiratoire, Hospital de la Santa Creu i Sant Pau', 'Certifiée — Conseil Médical du Cameroun', 'Membre — Société Thoracique Panafricaine'],
    expertise: ['Gestion de l\'Asthme', 'Soins BPCO', 'Réadaptation Respiratoire', 'Tests de Fonction Pulmonaire', 'Apnée du Sommeil'],
  },
  {
    id: 'doc-3', name: 'Dr Christian Mbarga', specialty: 'Médecine Générale',
    rating: 4.7, reviewCount: 210, yearsExperience: 15, patientCount: 3200,
    bio: 'Le Dr Christian Mbarga est un médecin généraliste expérimenté avec 15 ans de service dans des établissements de santé urbains et ruraux. Il fournit des soins primaires complets incluant la gestion des allergies, la médecine préventive et la prise en charge des maladies chroniques. Il parle plusieurs langues locales, ce qui lui permet de communiquer avec diverses populations de patients.',
    languages: ['English', 'French', 'Bulu', 'Ewondo'], hospital: 'Hôpital Central de Yaoundé', hospitalLocation: 'Yaoundé, Cameroon',
    consultationTypes: ['In-person', 'Phone Consultation'],
    nextAvailableSlot: 'Today at 2:00 PM', availableToday: true,
    reviews: [
      { name: 'Alice Z.', rating: 5, text: 'Le Dr Mbarga est le meilleur médecin généraliste que j\'ai eu. Il est minutieux, compatissant et prend toujours le temps d\'écouter.', date: 'Il y a 1 semaine' },
      { name: 'Robert L.', rating: 5, text: 'Très professionnel et compétent. Ses tests allergologiques et son plan de gestion ont considérablement amélioré ma qualité de vie.', date: 'Il y a 3 mois' },
    ],
    credentials: ['Doctorat en Médecine, Université de Yaoundé I', 'Diplôme en Médecine Tropicale, Liverpool School of Tropical Medicine', 'Certifié — Conseil Médical du Cameroun'],
    expertise: ['Soins Primaires', 'Gestion des Allergies', 'Médecine Préventive', 'Gestion des Maladies Chroniques', 'Médecine des Voyages'],
  },
  {
    id: 'doc-4', name: 'Dr Emmanuel Ndzi', specialty: 'Dentisterie',
    rating: 4.9, reviewCount: 156, yearsExperience: 10, patientCount: 2100,
    bio: 'Le Dr Emmanuel Ndzi est un chirurgien-dentiste compétent spécialisé en chirurgie buccale, extractions de dents de sagesse et dentisterie restauratrice. Il a obtenu son diplôme dentaire à l\'Université de Lagos et une formation avancée en chirurgie buccale à l\'Université de Nairobi. Il croit en une dentisterie sans douleur et au confort du patient.',
    languages: ['English', 'French'], hospital: 'Hôpital Central de Yaoundé', hospitalLocation: 'Yaoundé, Cameroon',
    consultationTypes: ['In-person'],
    nextAvailableSlot: 'Tomorrow at 11:00 AM', availableToday: false,
    reviews: [
      { name: 'Thomas W.', rating: 5, text: 'Extraction de dent de sagesse sans douleur ! Le Dr Ndzi est incroyablement compétent et a rendu toute l\'expérience confortable. Hautement recommandé.', date: 'Il y a 2 mois' },
      { name: 'Rebecca K.', rating: 5, text: 'Soins dentaires excellents. Professionnel, doux et minutieux. Ma guérison a été parfaite.', date: 'Il y a 3 mois' },
    ],
    credentials: ['BDS, Université de Lagos', 'Formation Avancée en Chirurgie Buccale, Université de Nairobi', 'Membre — Association Dentaire du Cameroun'],
    expertise: ['Chirurgie Buccale', 'Extraction de Dents de Sagesse', 'Dentisterie Restauratrice', 'Implants Dentaires', 'Dentisterie Préventive'],
  },
];

const hospitals: HospitalInfo[] = [
  { id: 'hosp-1', name: 'Hôpital Central de Yaoundé', distance: '2,3 km', address: '123 Boulevard de la Vallée, Yaoundé', emergencyAvailable: true, digitalIdentityEnabled: true, laboratory: true, pharmacy: true, openNow: true, openHours: 'Ouvert 24h/24', averageWaitTime: '15 min', specialists: ['Cardiologie', 'Médecine Générale', 'Dentisterie'], acceptedInsurance: ['TOSUMO Santé', 'Assurance Nationale', 'AfricaCare'], phone: '+237 222 123 456' },
  { id: 'hosp-2', name: 'CHU de Yaoundé', distance: '5,7 km', address: '456 Avenue de l\'Université, Yaoundé', emergencyAvailable: true, digitalIdentityEnabled: true, laboratory: true, pharmacy: true, openNow: true, openHours: 'Ouvert 24h/24', averageWaitTime: '25 min', specialists: ['Pneumologie', 'Cardiologie', 'Neurologie'], acceptedInsurance: ['TOSUMO Santé', 'Assurance Nationale', 'AfricaCare'], phone: '+237 222 789 012' },
  { id: 'hosp-3', name: 'Hôpital Général de Douala', distance: '12,1 km', address: '789 Rue Principale, Douala', emergencyAvailable: true, digitalIdentityEnabled: true, laboratory: true, pharmacy: false, openNow: true, openHours: 'Ouvert 24h/24', averageWaitTime: '35 min', specialists: ['Médecine d\'Urgence', 'Chirurgie', 'Médecine Interne'], acceptedInsurance: ['TOSUMO Santé', 'Assurance Nationale'], phone: '+237 333 456 789' },
  { id: 'hosp-4', name: 'Pharmacie de la Cité Verte', distance: '1,1 km', address: '321 Rue du Commerce, Yaoundé', emergencyAvailable: false, digitalIdentityEnabled: true, laboratory: false, pharmacy: true, openNow: true, openHours: '8h00 — 22h00', averageWaitTime: '5 min', specialists: [], acceptedInsurance: ['TOSUMO Santé', 'Assurance Nationale'], phone: '+237 222 345 678' },
  { id: 'hosp-5', name: 'Laboratoire MIMI', distance: '3,5 km', address: '654 Avenue de l\'Espoir, Yaoundé', emergencyAvailable: false, digitalIdentityEnabled: true, laboratory: true, pharmacy: false, openNow: true, openHours: '7h00 — 18h00', averageWaitTime: '10 min', specialists: ['Biologie Médicale'], acceptedInsurance: ['TOSUMO Santé', 'Assurance Nationale'], phone: '+237 222 567 890' },
];

const chats: ChatConversation[] = [
  {
    id: 'chat-1', participantName: 'Dr Jean-Pierre Ndzié', participantRole: 'Cardiologue', participantInitials: 'JN',
    lastMessage: 'Votre prochain rendez-vous est confirmé pour le 7 juillet à 9h.', lastMessageDate: '2h', unread: 1, online: true,
    messages: [
      { id: 'cm1', senderId: 'dr-ndzie', senderName: 'Dr Jean-Pierre Ndzié', text: 'Bonjour M. Tsague, comment vous sentez-vous depuis notre dernière consultation ?', timestamp: '2026-06-25T09:30:00Z', type: 'text' },
      { id: 'cm2', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Bonjour Docteur, je vais relativement bien. La tension semble mieux contrôlée.', timestamp: '2026-06-25T09:35:00Z', type: 'text' },
      { id: 'cm3', senderId: 'dr-ndzie', senderName: 'Dr Jean-Pierre Ndzié', text: 'C\'est bon à entendre. Avez-vous des maux de tête occasionnels ou d\'autres symptômes ?', timestamp: '2026-06-25T09:38:00Z', type: 'text' },
      { id: 'cm4', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Oui, j\'ai parfois des maux de tête légers le matin, mais ils disparaissent rapidement après la prise du médicament.', timestamp: '2026-06-25T09:42:00Z', type: 'text' },
      { id: 'cm5', senderId: 'dr-ndzie', senderName: 'Dr Jean-Pierre Ndzié', text: 'Je vais vous envoyer les résultats de votre dernier contrôle tensionnel.', timestamp: '2026-06-25T09:45:00Z', type: 'document', metadata: { fileName: 'Controle_Tensionnel_25062026.pdf', fileSize: '245 Ko' } },
      { id: 'cm6', senderId: 'dr-ndzie', senderName: 'Dr Jean-Pierre Ndzié', text: 'Vos dernières mesures montrent 128/80 mmHg. C\'est dans la bonne direction, mais je souhaite ajuster légèrement le dosage.', timestamp: '2026-06-25T09:48:00Z', type: 'text' },
      { id: 'cm7', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'D\'accord, que recommandez-vous ?', timestamp: '2026-06-25T09:50:00Z', type: 'text' },
      { id: 'cm8', senderId: 'dr-ndzie', senderName: 'Dr Jean-Pierre Ndzié', text: 'Je vais augmenter votre Lisinopril à 15mg par jour. Continuez le régime pauvre en sel et l\'exercice modéré.', timestamp: '2026-06-25T09:55:00Z', type: 'text' },
      { id: 'cm9', senderId: 'dr-ndzie', senderName: 'Dr Jean-Pierre Ndzié', text: 'J\'ai préparé votre nouvelle ordonnance. Vous pouvez la récupérer à la pharmacie.', timestamp: '2026-06-25T10:00:00Z', type: 'voice', metadata: { duration: '0:42' } },
      { id: 'cm10', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Merci Docteur. Quand doit-être mon prochain rendez-vous ?', timestamp: '2026-06-25T10:05:00Z', type: 'text' },
      { id: 'cm11', senderId: 'dr-ndzie', senderName: 'Dr Jean-Pierre Ndzié', text: 'Dans 3 semaines, soit le 7 juillet. Cela nous permettra de vérifier l\'effet du nouveau dosage.', timestamp: '2026-06-25T10:08:00Z', type: 'appointment' },
      { id: 'cm12', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Parfait, je prends note. Merci pour votre suivi, Docteur.', timestamp: '2026-06-25T10:12:00Z', type: 'text' },
      { id: 'cm13', senderId: 'dr-ndzie', senderName: 'Dr Jean-Pierre Ndzié', text: 'N\'hésitez pas à me contacter si les maux de tête persistent ou s\'aggravent.', timestamp: '2026-06-25T10:15:00Z', type: 'text' },
      { id: 'cm14', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Bien noté. Bonne journée Docteur.', timestamp: '2026-06-25T10:18:00Z', type: 'text' },
      { id: 'cm15', senderId: 'dr-ndzie', senderName: 'Dr Jean-Pierre Ndzié', text: 'Bonne journée à vous, M. Tsague. À bientôt.', timestamp: '2026-06-25T10:20:00Z', type: 'text' },
    ],
  },
  {
    id: 'chat-2', participantName: 'Dr Mireille Ndzi', participantRole: 'Médecin généraliste', participantInitials: 'MN',
    lastMessage: 'Vos résultats sont globalement bons. Je vous envoie le rapport complet.', lastMessageDate: '1j', unread: 2, online: false,
    messages: [
      { id: 'cm16', senderId: 'dr-ndzi', senderName: 'Dr Mireille Ndzi', text: 'Bonjour M. Tsague, vos résultats d\'analyses sanguines sont prêts.', timestamp: '2026-06-24T14:00:00Z', type: 'text' },
      { id: 'cm17', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Bonjour Docteur, qu\'est-ce que cela donne ?', timestamp: '2026-06-24T14:10:00Z', type: 'text' },
      { id: 'cm18', senderId: 'dr-ndzi', senderName: 'Dr Mireille Ndzi', text: 'Votre cholestérol total est à 5.2 mmol/L, le LDL à 3.4 mmol/L — légèrement élevé. Le HDL est correct à 1.2 mmol/L.', timestamp: '2026-06-24T14:15:00Z', type: 'text' },
      { id: 'cm19', senderId: 'dr-ndzi', senderName: 'Dr Mireille Ndzi', text: 'Vos triglycérides sont à 1.5 mmol/L, dans la norme. La glycémie à jeun est de 5.4 mmol/L — normal.', timestamp: '2026-06-24T14:18:00Z', type: 'text' },
      { id: 'cm20', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Le LDL élevé est inquiétant ?', timestamp: '2026-06-24T14:22:00Z', type: 'text' },
      { id: 'cm21', senderId: 'dr-ndzi', senderName: 'Dr Mireille Ndzi', text: 'Ce n\'est pas alarmant, mais il faut le surveiller. Augmentez votre consommation de fibres solubles : avoine, légumineuses, fruits.', timestamp: '2026-06-24T14:25:00Z', type: 'text' },
      { id: 'cm22', senderId: 'dr-ndzi', senderName: 'Dr Mireille Ndzi', text: 'Voici le rapport complet de vos analyses.', timestamp: '2026-06-24T14:30:00Z', type: 'document', metadata: { fileName: 'Rapport_Analyses_24062026.pdf', fileSize: '320 Ko' } },
      { id: 'cm23', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Merci beaucoup Docteur. Je vais suivre vos recommandations.', timestamp: '2026-06-24T14:35:00Z', type: 'text' },
      { id: 'cm24', senderId: 'dr-ndzi', senderName: 'Dr Mireille Ndzi', text: 'Je vous envoie un récapitulatif vocal de tous les paramètres à surveiller.', timestamp: '2026-06-24T14:40:00Z', type: 'voice', metadata: { duration: '1:15' } },
      { id: 'cm25', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Parfait, je réécoute cela ce soir. Merci encore.', timestamp: '2026-06-24T14:45:00Z', type: 'text' },
      { id: 'cm26', senderId: 'dr-ndzi', senderName: 'Dr Mireille Ndzi', text: 'Reprenez les analyses dans 3 mois pour suivre l\'évolution. Bonne continuation !', timestamp: '2026-06-24T14:50:00Z', type: 'text' },
    ],
  },
  {
    id: 'chat-3', participantName: 'Dr Fatou Ngassa', participantRole: 'Pneumologue', participantInitials: 'FN',
    lastMessage: 'Votre suivi respiratoire est programmé pour le 10 juillet.', lastMessageDate: '3j', unread: 0, online: true,
    messages: [
      { id: 'cm27', senderId: 'dr-ngassa', senderName: 'Dr Fatou Ngassa', text: 'Bonjour M. Tsague, comment va votre respiration ces derniers jours ?', timestamp: '2026-06-22T10:00:00Z', type: 'text' },
      { id: 'cm28', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Bonjour Docteur, je vais mieux. Moins d\'essoufflement depuis que j\'utilise le Symbicort régulièrement.', timestamp: '2026-06-22T10:05:00Z', type: 'text' },
      { id: 'cm29', senderId: 'dr-ngassa', senderName: 'Dr Fatou Ngassa', text: 'Excellent. Avez-vous noté une amélioration de votre débit de pointe ?', timestamp: '2026-06-22T10:08:00Z', type: 'text' },
      { id: 'cm30', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Oui, il est passé à 92% de ma valeur personnelle. Je me sens beaucoup mieux.', timestamp: '2026-06-22T10:12:00Z', type: 'text' },
      { id: 'cm31', senderId: 'dr-ngassa', senderName: 'Dr Fatou Ngassa', text: 'Très bien. Voici les informations pour votre prochaine consultation de suivi.', timestamp: '2026-06-22T10:15:00Z', type: 'document', metadata: { fileName: 'Suivi_Respiratoire_10072026.pdf', fileSize: '180 Ko' } },
      { id: 'cm32', senderId: 'dr-ngassa', senderName: 'Dr Fatou Ngassa', text: 'Votre consultation de suivi respiratoire est programmée pour le 10 juillet à 14h. Apportez votre carnet de débit de pointe.', timestamp: '2026-06-22T10:18:00Z', type: 'appointment' },
      { id: 'cm33', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Noté. Est-ce qu\'il y a quelque chose de particulier à surveiller d\'ici là ?', timestamp: '2026-06-22T10:22:00Z', type: 'text' },
      { id: 'cm34', senderId: 'dr-ngassa', senderName: 'Dr Fatou Ngassa', text: 'Continuez à mesurer votre débit de pointe chaque matin et notez les valeurs. Évitez l\'exposition au froid et portez un fouloir si nécessaire.', timestamp: '2026-06-22T10:25:00Z', type: 'text' },
      { id: 'cm35', senderId: 'dr-ngassa', senderName: 'Dr Fatou Ngassa', text: 'Je vous envoie un résumé de votre plan d\'action pour l\'asthme mis à jour.', timestamp: '2026-06-22T10:30:00Z', type: 'voice', metadata: { duration: '0:58' } },
      { id: 'cm36', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Merci Docteur, à bientôt.', timestamp: '2026-06-22T10:35:00Z', type: 'text' },
      { id: 'cm37', senderId: 'dr-ngassa', senderName: 'Dr Fatou Ngassa', text: 'N\'hésitez pas si vous avez des questions d\'ici là. Prenez soin de vous.', timestamp: '2026-06-22T10:38:00Z', type: 'text' },
      { id: 'cm38', senderId: 'dr-ngassa', senderName: 'Dr Fatou Ngassa', text: 'Pensez à bien vous hydrater et à éviter les allergènes connus.', timestamp: '2026-06-22T10:40:00Z', type: 'text' },
      { id: 'cm39', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Bien noté, merci pour les conseils.', timestamp: '2026-06-22T10:42:00Z', type: 'text' },
      { id: 'cm40', senderId: 'dr-ngassa', senderName: 'Dr Fatou Ngassa', text: 'Au plaisir de vous revoir le 10 juillet. Bonne journée !', timestamp: '2026-06-22T10:45:00Z', type: 'text' },
      { id: 'cm41', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Bonne journée Docteur.', timestamp: '2026-06-22T10:47:00Z', type: 'text' },
    ],
  },
  {
    id: 'chat-4', participantName: 'Pharmacie de la Cité Verte', participantRole: 'Pharmacie', participantInitials: 'PV',
    lastMessage: 'Votre prescription est disponible. Prix total : 12 500 FCFA.', lastMessageDate: '5h', unread: 1, online: true,
    messages: [
      { id: 'cm42', senderId: 'pharmacie-cite-verte', senderName: 'Pharmacie de la Cité Verte', text: 'Bonjour M. Tsague, nous avons bien reçu votre ordonnance pour le Lisinopril 15mg.', timestamp: '2026-06-28T08:00:00Z', type: 'text' },
      { id: 'cm43', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Bonjour, est-ce que le médicament est disponible ?', timestamp: '2026-06-28T08:15:00Z', type: 'text' },
      { id: 'cm44', senderId: 'pharmacie-cite-verte', senderName: 'Pharmacie de la Cité Verte', text: 'Oui, nous avons le Lisinopril 15mg en stock. Boîte de 90 comprimés.', timestamp: '2026-06-28T08:20:00Z', type: 'text' },
      { id: 'cm45', senderId: 'pharmacie-cite-verte', senderName: 'Pharmacie de la Cité Verte', text: 'Prix : 12 500 FCFA. Vous pouvez passer récupérer dès aujourd\'hui.', timestamp: '2026-06-28T08:25:00Z', type: 'text' },
      { id: 'cm46', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Parfait, je passe demain matin. Est-ce que vous acceptez Orange Money ?', timestamp: '2026-06-28T08:30:00Z', type: 'text' },
      { id: 'cm47', senderId: 'pharmacie-cite-verte', senderName: 'Pharmacie de la Cité Verte', text: 'Oui, nous acceptons Orange Money et MOMO. Voici les détails de votre commande.', timestamp: '2026-06-28T08:35:00Z', type: 'document', metadata: { fileName: 'Commande_Lisinopril_28062026.pdf', fileSize: '95 Ko' } },
      { id: 'cm48', senderId: 'pharmacie-cite-verte', senderName: 'Pharmacie de la Cité Verte', text: 'Nous avons aussi vérifié les interactions avec vos autres médicaments. Aucune interaction détectée avec le Symbicort.', timestamp: '2026-06-28T08:40:00Z', type: 'text' },
      { id: 'cm49', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Parfait, merci pour la vérification.', timestamp: '2026-06-28T08:45:00Z', type: 'text' },
      { id: 'cm50', senderId: 'pharmacie-cite-verte', senderName: 'Pharmacie de la Cité Verte', text: 'N\'oubliez pas de présenter votre QR code TOSUMO lors du retrait pour accélérer le processus.', timestamp: '2026-06-28T08:50:00Z', type: 'text' },
      { id: 'cm51', senderId: 'pharmacie-cite-verte', senderName: 'Pharmacie de la Cité Verte', text: 'À demain ! Nous sommes ouverts de 7h30 à 21h.', timestamp: '2026-06-28T08:55:00Z', type: 'voice', metadata: { duration: '0:22' } },
    ],
  },
  {
    id: 'chat-5', participantName: 'Hôpital Central de Yaoundé', participantRole: 'Service des rendez-vous', participantInitials: 'HC',
    lastMessage: 'Rappel : votre rendez-vous cardiologie est dans 2 jours.', lastMessageDate: '1j', unread: 1, online: false,
    messages: [
      { id: 'cm52', senderId: 'hopital-central', senderName: 'Hôpital Central de Yaoundé', text: 'Bonjour M. Tsague, ceci est un rappel concernant votre rendez-vous.', timestamp: '2026-06-27T09:00:00Z', type: 'text' },
      { id: 'cm53', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Bonjour, quel est le rendez-vous ?', timestamp: '2026-06-27T09:10:00Z', type: 'text' },
      { id: 'cm54', senderId: 'hopital-central', senderName: 'Hôpital Central de Yaoundé', text: 'Consultation cardiologie le 29 juin à 10h00, avec le Dr Ndzié, bâtiment B, salle 204.', timestamp: '2026-06-27T09:15:00Z', type: 'appointment' },
      { id: 'cm55', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'C\'est bien noté, je serai présent.', timestamp: '2026-06-27T09:20:00Z', type: 'text' },
      { id: 'cm56', senderId: 'hopital-central', senderName: 'Hôpital Central de Yaoundé', text: 'Merci de confirmer. Pensez à apporter votre carte médicale TOSUMO et la liste de vos médicaments actuels.', timestamp: '2026-06-27T09:25:00Z', type: 'text' },
      { id: 'cm57', senderId: 'hopital-central', senderName: 'Hôpital Central de Yaoundé', text: 'Voici la liste complète des documents à apporter.', timestamp: '2026-06-27T09:30:00Z', type: 'document', metadata: { fileName: 'Documents_Requis_RendezVous.pdf', fileSize: '150 Ko' } },
      { id: 'cm58', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'J\'amènerai tout. Merci pour le rappel.', timestamp: '2026-06-27T09:35:00Z', type: 'text' },
      { id: 'cm59', senderId: 'hopital-central', senderName: 'Hôpital Central de Yaoundé', text: 'En cas d\'empêchement, merci de nous prévenir au moins 24h à l\'avance.', timestamp: '2026-06-27T09:40:00Z', type: 'text' },
      { id: 'cm60', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Bien sûr, pas de problème.', timestamp: '2026-06-27T09:45:00Z', type: 'text' },
      { id: 'cm61', senderId: 'hopital-central', senderName: 'Hôpital Central de Yaoundé', text: 'Merci et à bientôt. Voici nos horaires pour le jour du rendez-vous.', timestamp: '2026-06-27T09:50:00Z', type: 'voice', metadata: { duration: '0:35' } },
    ],
  },
  {
    id: 'chat-6', participantName: 'Laboratoire MIMI', participantRole: 'Laboratoire d\'analyses', participantInitials: 'LM',
    lastMessage: 'Vos résultats sont disponibles. Tous les paramètres sont dans les normes.', lastMessageDate: '2j', unread: 0, online: false,
    messages: [
      { id: 'cm62', senderId: 'labo-mimi', senderName: 'Laboratoire MIMI', text: 'Bonjour M. Tsague, vos analyses sanguines du 25 juin sont terminées.', timestamp: '2026-06-27T11:00:00Z', type: 'text' },
      { id: 'cm63', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Bonjour, super. Quels sont les résultats ?', timestamp: '2026-06-27T11:10:00Z', type: 'text' },
      { id: 'cm64', senderId: 'labo-mimi', senderName: 'Laboratoire MIMI', text: 'Globalement très bons. Hémoglobine : 14.2 g/dL (normal), Glycémie : 5.2 mmol/L (normal), Créatinine : 82 µmol/L (normal).', timestamp: '2026-06-27T11:15:00Z', type: 'text' },
      { id: 'cm65', senderId: 'labo-mimi', senderName: 'Laboratoire MIMI', text: 'Bilan hépatique : ALT 28 U/L (normal), ASAT 24 U/L (normal). Bilirubine : 12 µmol/L (normal).', timestamp: '2026-06-27T11:18:00Z', type: 'text' },
      { id: 'cm66', senderId: 'labo-mimi', senderName: 'Laboratoire MIMI', text: 'Voici le rapport complet de vos résultats.', timestamp: '2026-06-27T11:22:00Z', type: 'document', metadata: { fileName: 'Resultats_Analyses_25062026.pdf', fileSize: '280 Ko' } },
      { id: 'cm67', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Merci. Le LDL est toujours un peu haut ?', timestamp: '2026-06-27T11:25:00Z', type: 'text' },
      { id: 'cm68', senderId: 'labo-mimi', senderName: 'Laboratoire MIMI', text: 'Le LDL est à 3.3 mmol/L — en légère amélioration par rapport à votre dernier contrôle (3.4).', timestamp: '2026-06-27T11:28:00Z', type: 'text' },
      { id: 'cm69', senderId: 'labo-mimi', senderName: 'Laboratoire MIMI', text: 'Nous recommandons de continuer le régime et de refaire le bilan lipidique dans 3 mois.', timestamp: '2026-06-27T11:30:00Z', type: 'text' },
      { id: 'cm70', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'D\'accord, je transmettrai ces résultats à mon cardiologue.', timestamp: '2026-06-27T11:35:00Z', type: 'text' },
      { id: 'cm71', senderId: 'labo-mimi', senderName: 'Laboratoire MIMI', text: 'Parfait. Bonne continuation et à bientôt chez Laboratoire MIMI.', timestamp: '2026-06-27T11:40:00Z', type: 'voice', metadata: { duration: '0:28' } },
    ],
  },
  {
    id: 'chat-7', participantName: 'Clinique Bastos', participantRole: 'Service de médecine générale', participantInitials: 'CB',
    lastMessage: 'Votre dossier médical a été mis à jour. Nouveau résultat d\'analyse disponible.', lastMessageDate: '3h', unread: 2, online: true,
    messages: [
      { id: 'cm72', senderId: 'clinique-bastos', senderName: 'Clinique Bastos', text: 'Bonjour M. Tsague, votre bilan sanguin annuel est prêt.', timestamp: '2026-06-28T15:00:00Z', type: 'text' },
      { id: 'cm73', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Bonjour, je peux le consulter en ligne ?', timestamp: '2026-06-28T15:10:00Z', type: 'text' },
      { id: 'cm74', senderId: 'clinique-bastos', senderName: 'Clinique Bastos', text: 'Oui, les résultats sont disponibles dans votre carnet médical. Le Dr Ndzié les a déjà examinés.', timestamp: '2026-06-28T15:15:00Z', type: 'text' },
      { id: 'cm75', senderId: 'clinique-bastos', senderName: 'Clinique Bastos', text: 'Votre cholestérol a baissé : LDL à 3.2 mmol/L (était à 3.4). Bonne progression !', timestamp: '2026-06-28T15:20:00Z', type: 'text' },
      { id: 'cm76', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'C\'est une bonne nouvelle ! Le régime commence à payer.', timestamp: '2026-06-28T15:25:00Z', type: 'text' },
      { id: 'cm77', senderId: 'clinique-bastos', senderName: 'Clinique Bastos', text: 'Absolument. Continuez comme ça. Nous vous recommandons de maintenir le cap et de refaire le bilan dans 6 mois.', timestamp: '2026-06-28T15:30:00Z', type: 'text' },
      { id: 'cm78', senderId: 'clinique-bastos', senderName: 'Clinique Bastos', text: 'Voici un guide alimentaire personnalisé pour vous aider à maintenir vos bons résultats.', timestamp: '2026-06-28T15:35:00Z', type: 'document', metadata: { fileName: 'Guide_Alimentaire_Personnalise.pdf', fileSize: '420 Ko' } },
    ],
  },
  {
    id: 'chat-8', participantName: 'Dr Emmanuel Ndzi', participantRole: 'Chirurgien-dentiste', participantInitials: 'EN',
    lastMessage: 'La cicatrisation est excellente. Plus de précautions nécessaires.', lastMessageDate: '2mois', unread: 0, online: false,
    messages: [
      { id: 'cm79', senderId: 'dr-ndzi-dent', senderName: 'Dr Emmanuel Ndzi', text: 'Bonjour M. Tsague. Je fais le suivi de votre extraction de dent de sagesse.', timestamp: '2026-04-15T09:00:00Z', type: 'text' },
      { id: 'cm80', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Bonjour Docteur, tout va bien. Plus de douleur.', timestamp: '2026-04-15T09:05:00Z', type: 'text' },
      { id: 'cm81', senderId: 'dr-ndzi-dent', senderName: 'Dr Emmanuel Ndzi', text: 'La cicatrisation est excellente d\'après les photos que vous m\'avez envoyées.', timestamp: '2026-04-15T09:10:00Z', type: 'text' },
      { id: 'cm82', senderId: 'dr-ndzi-dent', senderName: 'Dr Emmanuel Ndzi', text: 'Plus de précautions alimentaires nécessaires. Vous pouvez reprendre une alimentation normale.', timestamp: '2026-04-15T09:12:00Z', type: 'text' },
      { id: 'cm83', senderId: 'patient-dynamic', senderName: 'Russel Tsague', text: 'Super ! Merci beaucoup Docteur.', timestamp: '2026-04-15T09:15:00Z', type: 'text' },
      { id: 'cm84', senderId: 'dr-ndzi-dent', senderName: 'Dr Emmanuel Ndzi', text: 'N\'oubliez pas de maintenir une bonne hygiène dentaire. Rendez-vous dans 6 mois pour le contrôle de routine.', timestamp: '2026-04-15T09:18:00Z', type: 'text' },
      { id: 'cm85', senderId: 'dr-ndzi-dent', senderName: 'Dr Emmanuel Ndzi', text: 'Je vous envoie un récapitulatif des soins post-opératoires à suivre.', timestamp: '2026-04-15T09:20:00Z', type: 'voice', metadata: { duration: '1:05' } },
    ],
  },
];

export function seedPremiumMockData() {
  setLS('patients', [JAN]);
  setLS('cards', [card]);
  setLS('booklet', booklet);
  setLS('grants', grants);
  setLS('audit', audit);
  setLS('emergency', []);
  setLS('appointments', appointments);
  setLS('prescriptions', prescriptions);
  setLS('notifications', notifications);
  setLS('journey', journey);
  setLS('doctors', doctors);
  setLS('hospitals', hospitals);
  setLS('chats', chats);
}

function setLS(key: string, value: any) {
  localStorage.setItem(LS_KEY(key), JSON.stringify(value));
  window.dispatchEvent(new Event('mockApiUpdate'));
}
