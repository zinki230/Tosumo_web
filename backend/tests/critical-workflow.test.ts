/**
 * CRITICAL WORKFLOW END-TO-END TEST
 *
 * Covers the entire investor-demo pipeline:
 *   1. Check phone (not registered)
 *   2. Send OTP
 *   3. Verify OTP
 *   4. Register patient
 *   5. Login patient
 *   6. Onboard patient (creates Patient + MedicalCard)
 *   7. Retrieve patient profile
 *   8. Retrieve medical card + QR token
 *   9. Register + login a test doctor
 *  10. Doctor scans QR token → backend verifies → access grant created
 *  11. Doctor retrieves patient details
 *  12. Doctor adds complementary information
 *  13. Doctor creates first consultation
 *  14. Doctor retrieves patient records (consultations present)
 *  15. Patient retrieves own profile (updated info visible)
 *  16. Patient retrieves medical records (consultation visible)
 *
 * Each step asserts the HTTP response and, where meaningful, the database state.
 */

import request from 'supertest';
import app from '../src/app';
import prisma from '../src/shared/database/prisma';

// Generate a unique 9-digit national number starting with 6 (Cameroon mobile)
const uniqueSuffix = Date.now().toString().slice(-6);
const TEST_PHONE = `237690${uniqueSuffix}`;
const TEST_EMAIL = `e2e-${Date.now()}@tosumo.cm`;
const TEST_PASSWORD = 'E2e@Test1234';
const TEST_LICENSE = `LIC-${Date.now()}`;

let patientToken: string;
let patientRefreshToken: string;
let patientUserId: string;
let patientId: string;
let doctorToken: string;
let doctorUserId: string;
let doctorId: string;
let medicalCardId: string;
let qrToken: string;

afterAll(async () => {
  // Best-effort cleanup of test data (order matters due to FK constraints)
  try {
    if (patientId) {
      await prisma.consultation.deleteMany({ where: { patientId } }).catch(() => {});
      await prisma.accessManagement.deleteMany({ where: { patientId } }).catch(() => {});
      await prisma.medicalCard.deleteMany({ where: { patientId } }).catch(() => {});
      await prisma.patient.delete({ where: { id: patientId } }).catch(() => {});
    }
    if (patientUserId) {
      await prisma.notification.deleteMany({ where: { userId: patientUserId } }).catch(() => {});
      await prisma.user.delete({ where: { id: patientUserId } }).catch(() => {});
    }
    if (doctorId) {
      await prisma.doctor.delete({ where: { id: doctorId } }).catch(() => {});
    }
    if (doctorUserId) {
      await prisma.notification.deleteMany({ where: { userId: doctorUserId } }).catch(() => {});
      await prisma.user.delete({ where: { id: doctorUserId } }).catch(() => {});
    }
  } catch { /* ignore */ }
  await prisma.$disconnect();
});

// ─────────────────────────────────────────────
// STEP 1–3: Phone check → OTP → Verify
// ─────────────────────────────────────────────

describe('Critical Workflow: Registration → QR → Doctor → Consultation', () => {

  it('Step 1: check-phone reports unknown number', async () => {
    const res = await request(app)
      .post('/api/v1/auth/check-phone')
      .send({ phone: TEST_PHONE });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.exists).toBe(false);
  });

  it('Step 2: send-otp succeeds', async () => {
    const res = await request(app)
      .post('/api/v1/auth/send-otp')
      .send({ phone: TEST_PHONE });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  it('Step 3: verify-otp succeeds with 6-digit code', async () => {
    const res = await request(app)
      .post('/api/v1/auth/verify-otp')
      .send({ phone: TEST_PHONE, code: '123456' });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  // ─────────────────────────────────────────────
  // STEP 4: Register patient
  // ─────────────────────────────────────────────

  it('Step 4: register creates user + returns tokens', async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: TEST_EMAIL,
        phone: TEST_PHONE,
        password: TEST_PASSWORD,
        role: 'patient',
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.user.email).toBe(TEST_EMAIL);
    expect(res.body.data.user.phone).toBeDefined();
    expect(res.body.data.tokens.accessToken).toBeDefined();
    expect(res.body.data.tokens.refreshToken).toBeDefined();

    patientToken = res.body.data.tokens.accessToken;
    patientRefreshToken = res.body.data.tokens.refreshToken;
    patientUserId = res.body.data.user.id;

    // Verify user exists in database
    const user = await prisma.user.findUnique({ where: { id: patientUserId } });
    expect(user).not.toBeNull();
    expect(user!.email).toBe(TEST_EMAIL);
    expect(user!.role).toBe('patient');
    expect(user!.isActive).toBe(true);
  });

  // ─────────────────────────────────────────────
  // STEP 5: Login (confirm credentials work)
  // ─────────────────────────────────────────────

  it('Step 5: login returns valid tokens', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: TEST_EMAIL, password: TEST_PASSWORD });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.tokens.accessToken).toBeDefined();

    // Use the fresh token for subsequent requests
    patientToken = res.body.data.tokens.accessToken;
    patientRefreshToken = res.body.data.tokens.refreshToken;
  });

  // ─────────────────────────────────────────────
  // STEP 6: Onboard patient (creates Patient + Card)
  // ─────────────────────────────────────────────

  it('Step 6: onboard creates Patient record + MedicalCard', async () => {
    const res = await request(app)
      .post('/api/v1/patients/onboard')
      .set('Authorization', `Bearer ${patientToken}`)
      .send({
        firstName: 'E2E',
        lastName: 'TestPatient',
        dateOfBirth: '1990-05-15',
        gender: 'male',
        bloodType: 'O+',
        allergies: ['Penicillin'],
        chronicDiseases: [],
        city: 'Douala',
        address: '123 Rue de Test',
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const patient = res.body.data;
    expect(patient).toBeDefined();
    expect(patient.firstName).toBe('E2E');
    expect(patient.lastName).toBe('TestPatient');
    expect(patient.gender).toBe('male');
    expect(patient.bloodType).toBe('O+');
    expect(patient.city).toBe('Douala');
    expect(patient.isOnboarded).toBe(true);

    patientId = patient.id;

    // Verify in database
    const dbPatient = await prisma.patient.findUnique({ where: { id: patientId } });
    expect(dbPatient).not.toBeNull();
    expect(dbPatient!.firstName).toBe('E2E');
    expect(dbPatient!.isOnboarded).toBe(true);

    // Verify MedicalCard was created
    const card = await prisma.medicalCard.findUnique({ where: { patientId } });
    expect(card).not.toBeNull();
    expect(card!.cardNumber).toBeDefined();
    medicalCardId = card!.id;
  });

  // ─────────────────────────────────────────────
  // STEP 7: Patient profile loads from DB
  // ─────────────────────────────────────────────

  it('Step 7: patient profile returns real DB data', async () => {
    const res = await request(app)
      .get('/api/v1/patients/profile')
      .set('Authorization', `Bearer ${patientToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const profile = res.body.data;
    expect(profile.firstName).toBe('E2E');
    expect(profile.lastName).toBe('TestPatient');
    expect(profile.gender).toBe('male');
    expect(profile.bloodType).toBe('O+');
    expect(profile.city).toBe('Douala');
    expect(profile.user).toBeDefined();
    expect(profile.user.email).toBe(TEST_EMAIL);
    expect(profile.medicalCard).toBeDefined();
  });

  // ─────────────────────────────────────────────
  // STEP 8: Medical card + QR token
  // ─────────────────────────────────────────────

  it('Step 8: medical card returns signed QR token', async () => {
    const res = await request(app)
      .get('/api/v1/patients/medical-card')
      .set('Authorization', `Bearer ${patientToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const card = res.body.data;
    expect(card.cardNumber).toBeDefined();
    expect(card.qrToken).toBeDefined();
    expect(card.qrExpiresAt).toBeDefined();
    expect(card.isActive).toBe(true);

    qrToken = card.qrToken;

    // Verify QR token is a valid JWT-like string
    expect(typeof qrToken).toBe('string');
    expect(qrToken.split('.').length).toBe(3); // header.payload.signature
  });

  // ─────────────────────────────────────────────
  // STEP 9: Register + login a test doctor
  // ─────────────────────────────────────────────

  it('Step 9: register doctor + login', async () => {
    const doctorEmail = `doctor-${Date.now()}@tosumo.cm`;
    const doctorPhone = `237691${uniqueSuffix}`;

    // Register doctor user
    const regRes = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: doctorEmail,
        phone: doctorPhone,
        password: TEST_PASSWORD,
        role: 'doctor',
      });

    expect(regRes.status).toBe(201);
    doctorUserId = regRes.body.data.user.id;

    // Register doctor profile
    const profileRes = await request(app)
      .post('/api/v1/doctors/register')
      .set('Authorization', `Bearer ${regRes.body.data.tokens.accessToken}`)
      .send({
        firstName: 'DrE2E',
        lastName: 'TestDoctor',
        specialty: 'Medecine Generale',
        licenseNumber: TEST_LICENSE,
        yearsOfExperience: 5,
        consultationFee: 10000,
      });

    expect(profileRes.status).toBe(201);
    doctorId = profileRes.body.data.id;

    // Login as doctor
    const loginRes = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: doctorEmail, password: TEST_PASSWORD });

    expect(loginRes.status).toBe(200);
    doctorToken = loginRes.body.data.tokens.accessToken;

    // Verify doctor in database
    const dbDoctor = await prisma.doctor.findUnique({ where: { id: doctorId } });
    expect(dbDoctor).not.toBeNull();
    expect(dbDoctor!.firstName).toBe('DrE2E');
    expect(dbDoctor!.licenseNumber).toBe(TEST_LICENSE);
  });

  // ─────────────────────────────────────────────
  // STEP 10: Doctor scans QR → access grant
  // ─────────────────────────────────────────────

  it('Step 10: doctor scans QR token → access grant created', async () => {
    const res = await request(app)
      .get(`/api/v1/doctors/patients/qr?token=${encodeURIComponent(qrToken)}`)
      .set('Authorization', `Bearer ${doctorToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const result = res.body.data;
    expect(result.patient).toBeDefined();
    expect(result.patient.firstName).toBe('E2E');
    expect(result.patient.lastName).toBe('TestPatient');
    expect(result.access).toBeDefined();
    expect(result.access.isActive).toBe(true);
    expect(result.access.isApproved).toBe(true);
    expect(result.scannedVia).toBe('token');

    // Verify access grant in database
    const grant = await prisma.accessManagement.findFirst({
      where: {
        patientId,
        grantedToId: doctorUserId,
        isActive: true,
      },
    });
    expect(grant).not.toBeNull();
    expect(grant!.accessLevel).toBe('full');
    expect(grant!.accessType).toBe('temporary');
  });

  // ─────────────────────────────────────────────
  // STEP 11: Doctor retrieves patient details
  // ─────────────────────────────────────────────

  it('Step 11: doctor can access patient details', async () => {
    const res = await request(app)
      .get(`/api/v1/patients/${patientId}`)
      .set('Authorization', `Bearer ${doctorToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const patient = res.body.data;
    expect(patient.firstName).toBe('E2E');
    expect(patient.lastName).toBe('TestPatient');
    expect(patient.bloodType).toBe('O+');
    expect(patient.allergies).toContain('Penicillin');
    expect(patient.user).toBeDefined();
  });

  // ─────────────────────────────────────────────
  // STEP 12: Doctor adds complementary information
  // ─────────────────────────────────────────────

  it('Step 12: doctor updates complementary information', async () => {
    const res = await request(app)
      .put(`/api/v1/patients/${patientId}`)
      .set('Authorization', `Bearer ${doctorToken}`)
      .send({
        bloodType: 'A+',
        allergies: ['Penicillin', 'Aspirine'],
        chronicDiseases: ['Hypertension'],
        currentMeds: ['Lisinopril 10mg'],
        emergencyContactName: 'Marie TestPatient',
        emergencyContactPhone: '+237699000001',
        heightCm: 175,
        weightKg: 72,
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const updated = res.body.data;
    expect(updated.bloodType).toBe('A+');
    expect(updated.allergies).toContain('Aspirine');
    expect(updated.chronicDiseases).toContain('Hypertension');
    expect(updated.currentMeds).toContain('Lisinopril 10mg');
    expect(updated.emergencyContactName).toBe('Marie TestPatient');

    // Verify persistence in database
    const dbPatient = await prisma.patient.findUnique({ where: { id: patientId } });
    expect(dbPatient!.bloodType).toBe('A+');
    expect(dbPatient!.allergies).toContain('Aspirine');
    expect(dbPatient!.chronicDiseases).toContain('Hypertension');
    expect(dbPatient!.currentMeds).toContain('Lisinopril 10mg');
    expect(dbPatient!.emergencyContactName).toBe('Marie TestPatient');
    expect(dbPatient!.heightCm).toBe(175);
    expect(dbPatient!.weightKg).toBe(72);
  });

  // ─────────────────────────────────────────────
  // STEP 13: Doctor creates first consultation
  // ─────────────────────────────────────────────

  it('Step 13: doctor creates consultation', async () => {
    const res = await request(app)
      .post('/api/v1/medical-records/consultations')
      .set('Authorization', `Bearer ${doctorToken}`)
      .send({
        patientId,
        chiefComplaint: 'Maux de tetes recurrents depuis 2 semaines',
        historyOfPresentIllness: 'Patient souffre de maux de tetes depuis 2 semaines, localises front et tempes.',
        diagnosis: 'Cephalee de tension',
        symptoms: ['cephalee', 'tension-frontale', 'sensibilite-lumiere'],
        vitalSigns: {
          bloodPressure: '130/85',
          heartRate: 78,
          temperature: 36.6,
          weight: 72,
          height: 175,
        },
        assessment: 'Cephalee de tension legere. Pas de signes d\'alarme.',
        plan: 'Paracetamol 1g x3/jour pendant 5 jours. Repos. Retour si aggravation.',
        notes: 'Patient stress par le travail. Conseil de repos.',
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);

    const consultation = res.body.data;
    expect(consultation.id).toBeDefined();
    expect(consultation.chiefComplaint).toBe('Maux de tetes recurrents depuis 2 semaines');
    expect(consultation.diagnosis).toBe('Cephalee de tension');
    expect(consultation.symptoms).toContain('cephalee');
    expect(consultation.patientId).toBe(patientId);
    expect(consultation.doctorId).toBe(doctorId);

    // Verify in database
    const dbConsultation = await prisma.consultation.findUnique({
      where: { id: consultation.id },
    });
    expect(dbConsultation).not.toBeNull();
    expect(dbConsultation!.patientId).toBe(patientId);
    expect(dbConsultation!.doctorId).toBe(doctorId);
    expect(dbConsultation!.chiefComplaint).toBe('Maux de tetes recurrents depuis 2 semaines');
  });

  // ─────────────────────────────────────────────
  // STEP 14: Doctor retrieves patient records
  // ─────────────────────────────────────────────

  it('Step 14: doctor can retrieve patient records with consultation', async () => {
    const res = await request(app)
      .get(`/api/v1/medical-records/patient/${patientId}`)
      .set('Authorization', `Bearer ${doctorToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const records = res.body.data;
    expect(records.consultations).toBeDefined();
    expect(records.consultations.length).toBeGreaterThanOrEqual(1);

    const consultation = records.consultations[0];
    expect(consultation.chiefComplaint).toBe('Maux de tetes recurrents depuis 2 semaines');
    expect(consultation.diagnosis).toBe('Cephalee de tension');
  });

  // ─────────────────────────────────────────────
  // STEP 15: Patient retrieves own profile (updated info)
  // ─────────────────────────────────────────────

  it('Step 15: patient sees complementary info saved by doctor', async () => {
    const res = await request(app)
      .get('/api/v1/patients/profile')
      .set('Authorization', `Bearer ${patientToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const profile = res.body.data;
    expect(profile.bloodType).toBe('A+');
    expect(profile.allergies).toContain('Aspirine');
    expect(profile.chronicDiseases).toContain('Hypertension');
    expect(profile.currentMeds).toContain('Lisinopril 10mg');
    expect(profile.emergencyContactName).toBe('Marie TestPatient');
    expect(profile.heightCm).toBe(175);
    expect(profile.weightKg).toBe(72);
  });

  // ─────────────────────────────────────────────
  // STEP 16: Patient retrieves medical records
  // ─────────────────────────────────────────────

  it('Step 16: patient sees consultation created by doctor', async () => {
    const res = await request(app)
      .get('/api/v1/patients/medical-records')
      .set('Authorization', `Bearer ${patientToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const records = res.body.data;
    expect(records.consultations).toBeDefined();
    expect(records.consultations.length).toBeGreaterThanOrEqual(1);

    const consultation = records.consultations[0];
    expect(consultation.chiefComplaint).toBe('Maux de tetes recurrents depuis 2 semaines');
    expect(consultation.diagnosis).toBe('Cephalee de tension');
    expect(consultation.doctor).toBeDefined();
  });

  // ─────────────────────────────────────────────
  // SECURITY CHECKS
  // ─────────────────────────────────────────────

  it('Security: patient cannot update another patient via updateByDoctor', async () => {
    const res = await request(app)
      .put(`/api/v1/patients/${patientId}`)
      .set('Authorization', `Bearer ${patientToken}`)
      .send({ bloodType: 'B-' });

    expect(res.status).toBe(403);
    expect(res.body.success).toBe(false);
  });

  it('Security: unauthenticated request is rejected', async () => {
    const res = await request(app)
      .get('/api/v1/patients/profile');

    expect(res.status).toBe(401);
  });

  it('Security: doctor cannot create consultation without access grant', async () => {
    // Register a second doctor with no access to our patient
    const doc2Email = `doctor2-${Date.now()}@tosumo.cm`;
    const doc2Phone = `237693${uniqueSuffix}`;

    const regRes = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: doc2Email,
        phone: doc2Phone,
        password: TEST_PASSWORD,
        role: 'doctor',
      });

    const doc2Token = regRes.body.data.tokens.accessToken;

    await request(app)
      .post('/api/v1/doctors/register')
      .set('Authorization', `Bearer ${doc2Token}`)
      .send({
        firstName: 'DrUnauthorized',
        lastName: 'TestDoctor2',
        specialty: 'Cardiologie',
        licenseNumber: `LIC-UNAUTH-${Date.now()}`,
      });

    const res = await request(app)
      .post('/api/v1/medical-records/consultations')
      .set('Authorization', `Bearer ${doc2Token}`)
      .send({
        patientId,
        chiefComplaint: 'Unauthorized consultation',
      });

    expect(res.status).toBe(403);
    expect(res.body.success).toBe(false);

    // Cleanup
    const doc2User = await prisma.user.findUnique({ where: { email: doc2Email } });
    if (doc2User) {
      await prisma.user.delete({ where: { id: doc2User.id } }).catch(() => {});
    }
  });

  it('Security: expired/invalid QR token is rejected', async () => {
    const res = await request(app)
      .get('/api/v1/doctors/patients/qr?token=invalid.token.here')
      .set('Authorization', `Bearer ${doctorToken}`);

    // 400 = invalid token format/signature, 401 = expired/revoked session
    expect([400, 401]).toContain(res.status);
    expect(res.body.success).toBe(false);
  });

  it('Security: QR scan requires doctor role', async () => {
    const res = await request(app)
      .get(`/api/v1/doctors/patients/qr?token=${encodeURIComponent(qrToken)}`)
      .set('Authorization', `Bearer ${patientToken}`);

    expect(res.status).toBe(403);
    expect(res.body.success).toBe(false);
  });
});
